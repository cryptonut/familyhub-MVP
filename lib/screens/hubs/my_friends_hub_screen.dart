import 'package:flutter/material.dart';
import '../../models/hub.dart';
import '../../models/user_model.dart';
import '../../models/calendar_event.dart';
import '../../services/hub_service.dart';
import '../../services/auth_service.dart';
import '../../services/calendar_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../calendar/add_edit_event_screen.dart';
import '../video/video_call_screen.dart';
import '../../services/video_call_service.dart';
import 'create_hub_event_dialog.dart';
import 'invite_members_dialog.dart';
import 'hub_settings_screen.dart';

class MyFriendsHubScreen extends StatefulWidget {
  final Hub hub;

  const MyFriendsHubScreen({super.key, required this.hub});

  @override
  State<MyFriendsHubScreen> createState() => _MyFriendsHubScreenState();
}

class _MyFriendsHubScreenState extends State<MyFriendsHubScreen> {
  final HubService _hubService = HubService();
  final AuthService _authService = AuthService();
  final CalendarService _calendarService = CalendarService();
  final VideoCallService _videoCallService = VideoCallService();
  
  List<UserModel> _members = [];
  List<CalendarEvent> _upcomingEvents = [];
  List<Map<String, dynamic>> _upcomingBirthdays = [];
  bool _isLoading = true;
  String? _currentUserId;
  
  bool get _isHubCreator => _currentUserId != null && widget.hub.creatorId == _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadHubData();
  }

  Future<void> _loadHubData() async {
    setState(() => _isLoading = true);
    try {
      // Get current user ID
      _currentUserId = _authService.currentUser?.uid;
      
      // Load hub members
      final memberIds = widget.hub.memberIds;
      final members = <UserModel>[];
      for (var memberId in memberIds) {
        try {
          final userModel = await _authService.getUserModel(memberId);
          if (userModel != null) {
            members.add(userModel);
          }
        } catch (e) {
          debugPrint('Error loading member $memberId: $e');
        }
      }
      
      // Load upcoming events (next 30 days)
      final allEvents = await _calendarService.getEvents();
      final now = DateTime.now();
      final monthFromNow = now.add(const Duration(days: 30));
      final upcomingEvents = allEvents
          .where((event) => 
              event.startTime.isAfter(now) && 
              event.startTime.isBefore(monthFromNow))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      // Load upcoming birthdays (next month)
      // Note: We'll need to add birthday field to UserModel or handle differently
      final upcomingBirthdays = <Map<String, dynamic>>[];
      // For now, this is a placeholder - birthdays would need to be stored in UserModel

      setState(() {
        _members = members;
        _upcomingEvents = upcomingEvents;
        _upcomingBirthdays = upcomingBirthdays;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading hub data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createEvent() async {
    final result = await showDialog<CalendarEvent>(
      context: context,
      builder: (context) => CreateHubEventDialog(
        hub: widget.hub,
        members: _members,
      ),
    );

    if (result != null) {
      _loadHubData();
    }
  }

  Future<void> _inviteMembers() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => InviteMembersDialog(
        hub: widget.hub,
        currentMembers: _members,
      ),
    );

    if (result == true) {
      _loadHubData();
    }
  }

  Future<void> _startVideoCall() async {
    try {
      final channelName = await _videoCallService.createCall(widget.hub.id);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              hubId: widget.hub.id,
              channelName: channelName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting video call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hub.name),
        actions: [
          if (widget.hub.videoCallsEnabled)
            IconButton(
              icon: const Icon(Icons.videocam),
              onPressed: _startVideoCall,
              tooltip: 'Start Video Call',
            ),
          if (_isHubCreator)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HubSettingsScreen(hub: widget.hub),
                  ),
                ).then((_) => _loadHubData());
              },
              tooltip: 'Hub Settings',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHubData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Members Section
                    _buildMembersSection(),
                    const SizedBox(height: 24),
                    
                    // Upcoming Events Section
                    _buildUpcomingEventsSection(),
                    const SizedBox(height: 24),
                    
                    // Upcoming Birthdays Section
                    _buildUpcomingBirthdaysSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Members',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Text(
                  '${_members.length}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                if (_isHubCreator) ...[
                  const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _inviteMembers,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Invite New Members'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_members.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No members yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _members.map((member) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          member.displayName.isNotEmpty
                              ? member.displayName[0].toUpperCase()
                              : member.email[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        member.displayName.isNotEmpty
                            ? member.displayName
                            : member.email.split('@')[0],
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildUpcomingEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Events',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _createEvent,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Event'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_upcomingEvents.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No upcoming events',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          ..._upcomingEvents.take(10).map((event) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _parseColor(event.color),
                    child: const Icon(Icons.event, color: Colors.white),
                  ),
                  title: Text(event.title),
                  subtitle: Text(
                    '${app_date_utils.AppDateUtils.formatDate(event.startTime)} '
                    '${app_date_utils.AppDateUtils.formatTime(event.startTime)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              )),
      ],
    );
  }

  Widget _buildUpcomingBirthdaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Birthdays',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_upcomingBirthdays.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No upcoming birthdays in the next month',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          ..._upcomingBirthdays.map((birthday) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.pink,
                    child: Icon(Icons.cake, color: Colors.white),
                  ),
                  title: Text(birthday['name'] as String),
                  subtitle: Text(
                    app_date_utils.AppDateUtils.formatDate(
                      birthday['date'] as DateTime,
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}

