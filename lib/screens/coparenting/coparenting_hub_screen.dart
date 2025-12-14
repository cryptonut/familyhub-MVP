import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/hub.dart';
import '../../models/user_model.dart';
import '../../models/chat_message.dart';
import '../../services/coparenting_service.dart';
import '../../services/hub_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/premium_feature_gate.dart';
import '../../widgets/chat_widget.dart';
import '../../services/chat_service.dart';
import '../hubs/hub_settings_screen.dart';
import '../hubs/invite_members_dialog.dart';
import '../hubs/hub_chat_screen.dart';
import 'custody_schedules_screen.dart';
import 'schedule_change_requests_screen.dart';
import 'expenses_screen.dart';

/// Main screen for co-parenting hub management
class CoparentingHubScreen extends StatefulWidget {
  final String hubId;

  const CoparentingHubScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<CoparentingHubScreen> createState() => _CoparentingHubScreenState();
}

class _CoparentingHubScreenState extends State<CoparentingHubScreen> {
  final HubService _hubService = HubService();
  final CoparentingService _coparentingService = CoparentingService();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  Hub? _hub;
  List<UserModel> _members = [];
  int _pendingExpenses = 0;
  int _pendingScheduleChanges = 0;
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
      final members = <UserModel>[];
      
      // Load hub members
      if (hub != null) {
        for (var memberId in hub.memberIds) {
          final user = await _authService.getUserModel(memberId);
          if (user != null) {
            members.add(user);
          }
        }
      }

      final pendingExpenses = await _coparentingService.getPendingApprovalsCount(widget.hubId);
      
      // Count pending schedule change requests
      // TODO: Add method to CoparentingService to get pending schedule changes count
      final pendingScheduleChanges = 0; // Placeholder for now

      if (mounted) {
        setState(() {
          _hub = hub;
          _members = members;
          _pendingExpenses = pendingExpenses;
          _pendingScheduleChanges = pendingScheduleChanges;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Co-Parenting Hub')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hub == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Co-Parenting Hub')),
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
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                ],

                // Members section
                _buildMembersSection(),

                const SizedBox(height: AppTheme.spacingLG),

                // Quick stats
                _buildQuickStats(),

                const SizedBox(height: AppTheme.spacingLG),

                // Main features
                _buildFeatureCards(),

                const SizedBox(height: AppTheme.spacingLG),

                // Chat widget
                _buildChatWidget(),
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
            Text(
              'Members',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '${_members.length}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),
        if (_hub != null)
          ElevatedButton.icon(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) => InviteMembersDialog(
                  hub: _hub!,
                  currentMembers: _members,
                ),
              );
              _loadHubData();
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Invite New Members'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        if (_members.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingMD),
          ..._members.take(3).map((member) => ModernCard(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: member.photoUrl != null
                          ? NetworkImage(member.photoUrl!)
                          : null,
                      child: member.photoUrl == null
                          ? Text(
                              member.displayName.isNotEmpty
                                  ? member.displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(fontSize: 18),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (member.email.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              member.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          if (_members.length > 3)
            TextButton(
              onPressed: () {
                // Show all members dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('All Members'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: member.photoUrl != null
                                  ? NetworkImage(member.photoUrl!)
                                  : null,
                              child: member.photoUrl == null
                                  ? Text(
                                      member.displayName.isNotEmpty
                                          ? member.displayName[0].toUpperCase()
                                          : '?',
                                    )
                                  : null,
                            ),
                            title: Text(member.displayName),
                            subtitle: member.email.isNotEmpty
                                ? Text(member.email)
                                : null,
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              child: Text('View All ${_members.length} Members'),
            ),
        ],
      ],
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: ModernCard(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              children: [
                Text(
                  '$_pendingExpenses',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _pendingExpenses > 0
                            ? Colors.orange
                            : Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pending Expenses',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingMD),
        Expanded(
          child: ModernCard(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              children: [
                Text(
                  '$_pendingScheduleChanges',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _pendingScheduleChanges > 0
                            ? Colors.orange
                            : Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Schedule Requests',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ModernCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustodySchedulesScreen(hubId: widget.hubId),
              ),
            );
          },
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custody Schedules',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage custody schedules and exceptions',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ModernCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ScheduleChangeRequestsScreen(hubId: widget.hubId),
              ),
            );
          },
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Stack(
                children: [
                  Icon(
                    Icons.swap_horiz,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  if (_pendingScheduleChanges > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_pendingScheduleChanges',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule Change Requests',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Request and manage schedule changes',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ModernCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExpensesScreen(hubId: widget.hubId),
              ),
            );
          },
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Stack(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  if (_pendingExpenses > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_pendingExpenses',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shared Expenses',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track and split expenses',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chat',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ChatWidget(
          messagesStream: _chatService.getHubMessagesStream(widget.hubId),
          onSendMessage: (messageText) async {
            final currentUserId = _chatService.currentUserId;
            final currentUserName = _chatService.currentUserName ?? 'You';
            
            if (currentUserId == null) {
              throw Exception('User not authenticated');
            }

            final message = ChatMessage(
              id: const Uuid().v4(),
              senderId: currentUserId,
              senderName: currentUserName,
              content: messageText,
              timestamp: DateTime.now(),
              hubId: widget.hubId,
            );

            await _chatService.sendHubMessage(widget.hubId, message);
          },
          currentUserId: _chatService.currentUserId,
          currentUserName: _chatService.currentUserName,
          emptyStateMessage: 'No messages yet. Start the conversation!',
          onViewFullChat: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HubChatScreen(
                  hubId: widget.hubId,
                  hubName: _hub?.name ?? 'Co-Parenting Hub',
                ),
              ),
            );
          },
        ),
      ],
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
              leading: const Icon(Icons.info_outline),
              title: const Text('Hub Information'),
              onTap: () async {
                Navigator.pop(context);
                if (_hub != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HubSettingsScreen(hub: _hub!),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Manage Members'),
              onTap: () async {
                Navigator.pop(context);
                if (_hub != null) {
                  await showDialog(
                    context: context,
                    builder: (context) => InviteMembersDialog(
                      hub: _hub!,
                      currentMembers: _members,
                    ),
                  );
                  _loadHubData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

