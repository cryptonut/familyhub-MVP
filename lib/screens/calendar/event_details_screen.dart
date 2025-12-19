import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/calendar_event.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/calendar_service.dart';
import '../../widgets/ui_components.dart';
import '../chat/event_chat_widget.dart';
import 'add_edit_event_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final CalendarEvent event;

  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final CalendarService _calendarService = CalendarService();
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  CalendarEvent? _currentEvent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    try {
      final events = await _calendarService.getEvents();
      final updatedEvent = events.firstWhere(
        (e) => e.id == widget.event.id,
        orElse: () => widget.event,
      );
      if (mounted) {
        setState(() {
          _currentEvent = updatedEvent;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool get _canEdit {
    if (_currentEvent == null) return false;
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;
    // User can edit if they're the event owner or if eventOwnerId is not set (legacy events)
    final ownerId = _currentEvent!.eventOwnerId ?? _currentEvent!.createdBy;
    return ownerId == null || ownerId == userId;
  }

  Future<bool> _isAdmin() async {
    final userModel = await _authService.getCurrentUserModel();
    return userModel?.isAdmin() ?? false;
  }

  bool _canChangeOwner() {
    if (_currentEvent == null) return false;
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;
    final ownerId = _currentEvent!.eventOwnerId ?? _currentEvent!.createdBy;
    // Can change owner if user is the current owner (will be checked async for admin)
    return ownerId == userId;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentEvent == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final event = _currentEvent!;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(event.title),
        actions: [
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditEventScreen(event: event),
                  ),
                );
                if (result == true) {
                  _loadEvent();
                }
              },
              tooltip: 'Edit event',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Header Card
            ModernCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _parseColor(event.color),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  '${dateFormat.format(event.startTime)} • ${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (event.location != null && event.location!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.isRecurring) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.repeat, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          _formatRecurrence(event.recurrenceRule ?? ''),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ],
                  // Event Source and Creator Information
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (event.sourceCalendar != null && event.sourceCalendar!.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.sync,
                                size: 16,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  event.sourceCalendar!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (event.createdBy != null) const SizedBox(height: 8),
                        ],
                        // Event Owner
                        FutureBuilder<String?>(
                          future: _getOwnerName(event),
                          builder: (context, snapshot) {
                            final ownerName = snapshot.data ?? 'Unknown';
                            final ownerId = event.eventOwnerId ?? event.createdBy;
                            return FutureBuilder<bool>(
                              future: _isAdmin(),
                              builder: (context, adminSnapshot) {
                                final isAdmin = adminSnapshot.data ?? false;
                                final canChange = _canChangeOwner() || isAdmin;
                                
                                return Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Event Owner: $ownerName',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (canChange && ownerId != null)
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _changeEventOwner(event),
                                        tooltip: 'Change Event Owner',
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        // Show creator separately if different from owner
                        if (event.createdBy != null && 
                            (event.eventOwnerId == null || event.createdBy != event.eventOwnerId)) ...[
                          const SizedBox(height: 4),
                          FutureBuilder<String?>(
                            future: _getCreatorName(event.createdBy!),
                            builder: (context, snapshot) {
                              final creatorName = snapshot.data ?? 'Unknown';
                              return Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Created by $creatorName',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                        if (event.sourceCalendar == null && event.createdBy == null)
                          Text(
                            'Created in FamilyHub',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Description
            if (event.description.isNotEmpty) ...[
              ModernCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Photo Attachments
            if (event.photoUrls.isNotEmpty) ...[
              ModernCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Photos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: event.photoUrls.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                event.photoUrls[index],
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 200,
                                    height: 200,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.broken_image),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Participants/RSVP
            ModernCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Participants',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<dynamic>>(
                    future: _loadParticipants(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      final participants = snapshot.data ?? [];
                      if (participants.isEmpty) {
                        return const Text('No participants');
                      }
                      return Column(
                        children: participants.map((participant) {
                          final userId = participant['id'] as String;
                          final displayName = participant['displayName'] as String? ?? 'Unknown';
                          final rsvpStatus = event.rsvpStatus[userId] ?? 'pending';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                              ),
                            ),
                            title: Text(displayName),
                            trailing: Chip(
                              label: Text(rsvpStatus),
                              backgroundColor: _getRsvpColor(rsvpStatus),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Event Chat
            ModernCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Event Chat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  EventChatWidget(eventId: event.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadParticipants() async {
    if (_currentEvent == null) return [];
    
    final participants = <Map<String, dynamic>>[];
    final invitedIds = _currentEvent!.invitedMemberIds;
    
    if (invitedIds.isEmpty) return participants;
    
    try {
      for (var userId in invitedIds) {
        final userDoc = await _authService.getUserById(userId);
        if (userDoc != null) {
          participants.add({
            'id': userId,
            'displayName': userDoc.displayName,
            'email': userDoc.email,
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
    
    return participants;
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  String _formatRecurrence(String rule) {
    switch (rule.toLowerCase()) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return rule;
    }
  }

  Color? _getRsvpColor(String status) {
    switch (status.toLowerCase()) {
      case 'going':
        return Colors.green[100];
      case 'maybe':
        return Colors.orange[100];
      case 'declined':
        return Colors.red[100];
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  Future<String?> _getCreatorName(String userId) async {
    try {
      final user = await _authService.getUserById(userId);
      return user?.displayName ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<String?> _getOwnerName(CalendarEvent event) async {
    final ownerId = event.eventOwnerId ?? event.createdBy;
    if (ownerId == null) return null;
    try {
      final user = await _authService.getUserById(ownerId);
      return user?.displayName ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _changeEventOwner(CalendarEvent event) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Check if user is admin or current owner
    final userModel = await _authService.getCurrentUserModel();
    final isAdmin = userModel?.isAdmin() ?? false;
    final ownerId = event.eventOwnerId ?? event.createdBy;
    final isOwner = ownerId == userId;

    if (!isAdmin && !isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the Event Owner or an Admin can change the owner'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get family members for selection
    final familyMembers = await _authService.getFamilyMembers();
    if (familyMembers.isEmpty) return;

    // Show dialog to select new owner
    final selectedMember = await showDialog<UserModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Event Owner'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: familyMembers.length,
            itemBuilder: (context, index) {
              final member = familyMembers[index];
              final isCurrentOwner = (event.eventOwnerId ?? event.createdBy) == member.uid;
              return ListTile(
                title: Text(member.displayName),
                subtitle: Text(member.email),
                trailing: isCurrentOwner
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () => Navigator.pop(context, member),
              );
            },
          ),
        ),
      ),
    );

    if (selectedMember != null && selectedMember.uid != ownerId) {
      try {
        await _calendarService.updateEventOwner(event.id, selectedMember.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Event Owner changed to ${selectedMember.displayName}'),
              backgroundColor: Colors.green,
            ),
          );
          _loadEvent(); // Reload to show updated owner
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error changing event owner: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

