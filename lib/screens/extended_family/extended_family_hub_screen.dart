import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hub.dart';
import '../../models/extended_family_relationship.dart';
import '../../models/calendar_event.dart';
import '../../models/user_model.dart';
import '../../models/photo_album.dart';
import '../../services/extended_family_service.dart';
import '../../services/extended_family_privacy_service.dart';
import '../../services/hub_service.dart';
import '../../services/calendar_service.dart';
import '../../services/chat_service.dart';
import '../../services/photo_service.dart';
import '../../services/auth_service.dart';
import '../../services/birthday_service.dart';
import '../../providers/user_data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/premium_feature_gate.dart';
import '../../widgets/chat_widget.dart';
import '../calendar/add_edit_event_screen.dart';
import '../calendar/event_details_screen.dart';
import '../hubs/hub_chat_screen.dart';
import '../photos/photos_home_screen.dart';
import 'manage_relationships_screen.dart';
import 'privacy_settings_screen.dart';
import 'family_tree_screen.dart';

/// Screen for managing extended family hub
class ExtendedFamilyHubScreen extends StatefulWidget {
  final String hubId;

  const ExtendedFamilyHubScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<ExtendedFamilyHubScreen> createState() => _ExtendedFamilyHubScreenState();
}

class _ExtendedFamilyHubScreenState extends State<ExtendedFamilyHubScreen> {
  final HubService _hubService = HubService();
  final ExtendedFamilyService _extendedFamilyService = ExtendedFamilyService();
  final CalendarService _calendarService = CalendarService();
  final ChatService _chatService = ChatService();
  final PhotoService _photoService = PhotoService();
  final AuthService _authService = AuthService();
  final BirthdayService _birthdayService = BirthdayService();
  Hub? _hub;
  List<ExtendedFamilyMember> _relationships = [];
  List<CalendarEvent> _upcomingEvents = [];
  List<PhotoAlbum> _albums = [];
  List<BirthdayInfo> _upcomingBirthdays = [];
  String? _familyId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHubData();
  }

  Future<void> _loadHubData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hub = await _hubService.getHub(widget.hubId);
      final relationships = await _extendedFamilyService.getHubRelationships(widget.hubId);
      
      // Get family ID for photos
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      
      // Load upcoming events for this hub
      final allEvents = await _calendarService.getEvents(limit: 50);
      final now = DateTime.now();
      final hubEvents = allEvents
          .where((event) => 
              (event.hubId == widget.hubId || event.hubIds.contains(widget.hubId)) &&
              event.startTime.isAfter(now))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      
      final upcomingEvents = hubEvents.take(5).toList();
      
      // Load photo albums (family-level, will be filtered by privacy)
      List<PhotoAlbum> albums = [];
      if (familyId != null) {
        albums = await _photoService.getAlbums(familyId);
        albums = albums.take(3).toList(); // Show top 3 albums
      }
      
      // Load upcoming birthdays for extended family members
      final upcomingBirthdays = await _getExtendedFamilyBirthdays(relationships);

      if (mounted) {
        setState(() {
          _hub = hub;
          _relationships = relationships;
          _upcomingEvents = upcomingEvents;
          _albums = albums;
          _upcomingBirthdays = upcomingBirthdays;
          _familyId = familyId;
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

  Future<List<BirthdayInfo>> _getExtendedFamilyBirthdays(List<ExtendedFamilyMember> relationships) async {
    final upcomingBirthdays = <BirthdayInfo>[];
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 60)); // Next 60 days
    
    try {
      // Get user models for extended family members
      final userProvider = Provider.of<UserDataProvider>(context, listen: false);
      
      for (var relationship in relationships) {
        try {
          final userModel = await userProvider.getUserModel(relationship.userId);
          if (userModel == null || userModel.birthday == null) continue;
          if (!userModel.birthdayNotificationsEnabled) continue;
          
          // Calculate this year's birthday
          final thisYearBirthday = DateTime(
            now.year,
            userModel.birthday!.month,
            userModel.birthday!.day,
          );
          
          // Calculate next year's birthday
          final nextYearBirthday = DateTime(
            now.year + 1,
            userModel.birthday!.month,
            userModel.birthday!.day,
          );
          
          DateTime? upcomingBirthday;
          if (thisYearBirthday.isAfter(now) && thisYearBirthday.isBefore(endDate)) {
            upcomingBirthday = thisYearBirthday;
          } else if (nextYearBirthday.isAfter(now) && nextYearBirthday.isBefore(endDate)) {
            upcomingBirthday = nextYearBirthday;
          }
          
          if (upcomingBirthday != null) {
            final age = upcomingBirthday.year - userModel.birthday!.year;
            upcomingBirthdays.add(BirthdayInfo(
              user: userModel,
              upcomingDate: upcomingBirthday,
              ageTurning: age,
            ));
          }
        } catch (e) {
          // Skip if user not found
          continue;
        }
      }
      
      // Sort by upcoming date
      upcomingBirthdays.sort((a, b) => a.upcomingDate.compareTo(b.upcomingDate));
      
      return upcomingBirthdays.take(5).toList(); // Show top 5
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Extended Family Hub')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hub == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Extended Family Hub')),
        body: const Center(child: Text('Hub not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_hub!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHubData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hub description
              if (_hub!.description.isNotEmpty) ...[
                Text(
                  _hub!.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppTheme.spacingLG),
              ],
              // Quick actions
              _buildQuickActions(),
              const SizedBox(height: AppTheme.spacingLG),
              // Upcoming events
              _buildUpcomingEventsSection(),
              const SizedBox(height: AppTheme.spacingLG),
              // Hub chat preview
              _buildHubChatSection(),
              const SizedBox(height: AppTheme.spacingLG),
              // Photo sharing
              _buildPhotoSharingSection(),
              const SizedBox(height: AppTheme.spacingLG),
              // Upcoming birthdays
              _buildBirthdaysSection(),
              const SizedBox(height: AppTheme.spacingLG),
              // Family members
              _buildFamilyMembersSection(),
              const SizedBox(height: AppTheme.spacingLG),
              // Family tree
              _buildFamilyTreeSection(),
              const SizedBox(height: AppTheme.spacingLG),
              // Privacy settings
              _buildPrivacySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _createEvent(),
            icon: const Icon(Icons.event),
            label: const Text('Create Event'),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSM),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HubChatScreen(
                  hubId: widget.hubId,
                  hubName: _hub?.name ?? 'Extended Family',
                ),
              ),
            ),
            icon: const Icon(Icons.chat),
            label: const Text('Chat'),
          ),
        ),
      ],
    );
  }

  Future<void> _createEvent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditEventScreen(
          initialHubIds: [widget.hubId],
        ),
      ),
    );

    if (result == true) {
      _loadHubData();
    }
  }

  Widget _buildUpcomingEventsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Events',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => _createEvent(),
                  child: const Text('Create Event'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            if (_upcomingEvents.isEmpty)
              const Text('No upcoming events')
            else
              ..._upcomingEvents.map((event) => ListTile(
                    leading: const Icon(Icons.event, color: Colors.blue),
                    title: Text(event.title),
                    subtitle: Text(
                      '${_formatDate(event.startTime)} • ${_getRsvpSummary(event)}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailsScreen(event: event),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);
    
    if (eventDate == today) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (eventDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getRsvpSummary(CalendarEvent event) {
    final going = event.rsvpStatus.values.where((s) => s == 'going').length;
    final maybe = event.rsvpStatus.values.where((s) => s == 'maybe').length;
    final declined = event.rsvpStatus.values.where((s) => s == 'declined').length;
    final total = event.invitedMemberIds.length;
    
    if (total == 0) return 'No invites';
    if (going == 0 && maybe == 0 && declined == 0) return '$total invited';
    
    final parts = <String>[];
    if (going > 0) parts.add('$going going');
    if (maybe > 0) parts.add('$maybe maybe');
    if (declined > 0) parts.add('$declined declined');
    
    return parts.join(', ');
  }

  Widget _buildHubChatSection() {
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HubChatScreen(
              hubId: widget.hubId,
              hubName: _hub?.name ?? 'Extended Family',
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extended Family Chat',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Chat with all extended family members',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSharingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Photo Albums',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PhotosHomeScreen(),
                    ),
                  ),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            if (_albums.isEmpty)
              const Text('No photo albums yet')
            else
              ..._albums.map((album) => ListTile(
                    leading: const Icon(Icons.photo_library, color: Colors.blue),
                    title: Text(album.name),
                    subtitle: Text('${album.photoCount} photos'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Navigate to photos screen - albums are family-level
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PhotosHomeScreen(),
                        ),
                      );
                    },
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthdaysSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Birthdays',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            if (_upcomingBirthdays.isEmpty)
              const Text('No upcoming birthdays')
            else
              ..._upcomingBirthdays.map((birthday) {
                final daysUntil = birthday.upcomingDate.difference(DateTime.now()).inDays;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      birthday.user.displayName.isNotEmpty
                          ? birthday.user.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ),
                  title: Text(birthday.user.displayName),
                  subtitle: Text(
                    daysUntil == 0
                        ? 'Today! Turning ${birthday.ageTurning}'
                        : daysUntil == 1
                            ? 'Tomorrow - Turning ${birthday.ageTurning}'
                            : '$daysUntil days - Turning ${birthday.ageTurning}',
                  ),
                  trailing: Icon(
                    Icons.cake,
                    color: daysUntil <= 7 ? Colors.orange : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyMembersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Family Members',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageRelationshipsScreen(hubId: widget.hubId),
                    ),
                  ),
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            if (_relationships.isEmpty)
              const Text('No extended family members added yet')
            else
              ..._relationships.map((relationship) => ListTile(
                    leading: CircleAvatar(
                      child: Text(relationship.relationship.displayName[0]),
                    ),
                    title: Text(relationship.relationship.displayName),
                    subtitle: Text(relationship.permission.displayName),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyTreeSection() {
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FamilyTreeScreen(hubId: widget.hubId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Icon(
                Icons.account_tree,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family Tree',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Visualize family relationships',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrivacySettingsScreen(hubId: widget.hubId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Icon(
                Icons.privacy_tip,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy Settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Control what extended family can see',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Members'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManageRelationshipsScreen(hubId: widget.hubId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('Privacy Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrivacySettingsScreen(hubId: widget.hubId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_tree),
              title: const Text('Family Tree'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FamilyTreeScreen(hubId: widget.hubId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


