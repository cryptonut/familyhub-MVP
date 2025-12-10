import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_event.dart';
import '../../models/user_model.dart';
import '../../services/calendar_service.dart';
import '../../services/auth_service.dart';
import 'calendar_screen.dart';
import 'event_details_screen.dart';

class SchedulingConflictsScreen extends StatefulWidget {
  const SchedulingConflictsScreen({super.key});

  @override
  State<SchedulingConflictsScreen> createState() => _SchedulingConflictsScreenState();
}

class _SchedulingConflictsScreenState extends State<SchedulingConflictsScreen> {
  final CalendarService _calendarService = CalendarService();
  final AuthService _authService = AuthService();
  
  List<CalendarEvent> _allEvents = [];
  Map<String, List<CalendarEvent>> _conflicts = {};
  Map<String, String> _memberNames = {};
  bool _isLoading = true;
  
  // Filter state
  String _timeFilter = 'Week'; // 'Day', 'Week', 'Month', 'All'
  bool _showFamilyConflicts = false; // Default: only show current user's conflicts
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      // 1. Load members for names
      final members = await _authService.getFamilyMembers();
      for (var member in members) {
        _memberNames[member.uid] = member.displayName.isNotEmpty 
            ? member.displayName 
            : member.email.split('@').first;
      }
      
      // 2. Load events based on filter
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day); // Start of today
      DateTime end;
      
      switch (_timeFilter) {
        case 'Day':
          end = start.add(const Duration(days: 1));
          break;
        case 'Week':
          end = start.add(const Duration(days: 7));
          break;
        case 'Month':
          end = start.add(const Duration(days: 30));
          break;
        case 'All':
        default:
          end = start.add(const Duration(days: 365)); // Next year
          break;
      }
      
      // Get events for range - simplified: get all and filter
      // In a real app with recurring events, this needs RecurrenceService.
      // For now, we'll use getEvents and filter manually, assuming recurring events are expanded elsewhere or we just check base events.
      // Actually, getEventsForDate uses recurrence expansion. We should probably use that if we want accuracy.
      // But iterating every day for a year is slow.
      // Let's stick to `getEvents` (base events) for now, but conflicts with recurring instances might be missed unless we expand.
      // To be robust, let's fetch all and rely on the CalendarService logic if possible.
      // Since `findConflicts` works on a LIST of events, we need the expanded list.
      
      final rawEvents = await _calendarService.getEvents();
      
      // Filter to relevant time range
      _allEvents = rawEvents.where((e) => 
        e.endTime.isAfter(start) && e.startTime.isBefore(end)
      ).toList();
      
      // 3. Find conflicts and filter ignored ones
      final allConflicts = _calendarService.findConflicts(_allEvents);
      _conflicts = await _calendarService.filterIgnoredConflicts(allConflicts, forceRefresh: forceRefresh);
      
    } catch (e) {
      debugPrint('Error loading conflicts: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduling Conflicts'),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _conflicts.isEmpty
                    ? _buildEmptyState()
                    : _buildConflictsList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Timeframe:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Day', label: Text('Day')),
                    ButtonSegment(value: 'Week', label: Text('Week')),
                    ButtonSegment(value: 'Month', label: Text('Month')),
                  ],
                  selected: {_timeFilter},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _timeFilter = newSelection.first;
                    });
                    _loadData();
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Show Family Conflicts', style: TextStyle(fontWeight: FontWeight.bold)),
              Switch(
                value: _showFamilyConflicts,
                onChanged: (value) {
                  setState(() {
                    _showFamilyConflicts = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 16),
          const Text(
            'No conflicts detected!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your schedule for this $_timeFilter looks clear.',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConflictsList() {
    final currentUserId = _authService.currentUser?.uid;
    final filteredUserIds = _conflicts.keys.where((uid) {
      if (_showFamilyConflicts) return true;
      return uid == currentUserId;
    }).toList();

    if (filteredUserIds.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredUserIds.length,
      itemBuilder: (context, index) {
        final userId = filteredUserIds[index];
        final events = _conflicts[userId]!;
        final userName = _memberNames[userId] ?? 'Unknown';
        
        // Group these events by "Conflict Group" (overlapping sets)
        // Simple approach: Sort by time and show them.
        events.sort((a, b) => a.startTime.compareTo(b.startTime));
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      '$userName has overlaps',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(),
                ...events.map((event) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${DateFormat('MMM d').format(event.startTime)} • ${DateFormat('h:mm a').format(event.startTime)} - ${DateFormat('h:mm a').format(event.endTime)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_calendar),
                    onPressed: () {
                      // Manage Conflict: Go to Calendar
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CalendarScreen(initialDate: event.startTime),
                        ),
                      );
                    },
                  ),
                )),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        try {
                          await _calendarService.ignoreConflict(userId, events);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Conflict ignored')),
                            );
                            // Refresh to get latest ignored conflicts from server
                            // ignoreConflict() already verifies the write completed
                            if (mounted) {
                              await _loadData(forceRefresh: true);
                              // Signal to dashboard that a change occurred
                              if (mounted) {
                                Navigator.pop(context, true);
                              }
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to ignore conflict: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Ignore'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Manage: Go to Calendar Day View for the first event's date
                        if (events.isNotEmpty) {
                           Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CalendarScreen(initialDate: events.first.startTime),
                            ),
                          );
                        }
                      },
                      child: const Text('Manage in Calendar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
