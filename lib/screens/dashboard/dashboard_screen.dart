import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/services/logger_service.dart';
import '../../services/auth_service.dart';
import '../../services/app_state.dart';
import '../../providers/user_data_provider.dart';
import '../../services/calendar_service.dart';
import '../../services/task_service.dart';
import '../../services/wallet_service.dart';
import '../../services/family_wallet_service.dart';
import '../../services/chat_service.dart';
import '../../models/calendar_event.dart';
import '../../models/task.dart';
import '../../models/user_model.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../utils/relationship_utils.dart';
import '../wallet/wallet_screen.dart';
import '../chat/private_chat_screen.dart';
import '../chat/chat_tabs_screen.dart';
import '../hubs/my_hubs_screen.dart';
import '../tasks/add_edit_task_screen.dart';
import '../tasks/refund_notification_dialog.dart';
import '../calendar/add_edit_event_screen.dart';
import '../calendar/scheduling_conflicts_screen.dart';
import '../wallet/approve_payout_dialog.dart';
import '../../widgets/relationship_dialog.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/skeletons/skeleton_widgets.dart';
import '../../widgets/quick_actions_fab.dart';
import '../../utils/app_theme.dart';
import '../../services/payout_service.dart';
import '../../services/recurrence_service.dart'; // Added for conflict detection
import '../../models/payout_request.dart';
import '../../services/birthday_service.dart';
import '../../services/profile_photo_service.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../widgets/chat_widget.dart';
import '../../models/chat_message.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide CalendarEvent;
import 'dart:io';
import 'package:flutter/foundation.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final CalendarService _calendarService = CalendarService();
  final TaskService _taskService = TaskService();
  final WalletService _walletService = WalletService();
  final FamilyWalletService _familyWalletService = FamilyWalletService();
  final PayoutService _payoutService = PayoutService();
  final BirthdayService _birthdayService = BirthdayService();
  final ProfilePhotoService _profilePhotoService = ProfilePhotoService();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CalendarEvent> _upcomingEvents = [];
  List<BirthdayInfo> _upcomingBirthdays = [];
  List<Task> _upcomingTasks = [];
  List<Task> _pendingApprovals = [];
  List<Map<String, dynamic>> _refundNotifications = []; // List of refund notification documents
  List<PayoutRequest> _pendingPayoutRequests = []; // Pending payout requests (for Bankers)
  Map<String, bool> _unreadMessages = {}; // Map of userId -> hasUnreadMessages
  double _walletBalance = 0.0;
  double _familyWalletBalance = 0.0;
  int _activeJobsCount = 0;
  int _completedJobsCount = 0;
  int _pendingApprovalsCount = 0;
  int _refundNotificationsCount = 0;
  int _pendingPayoutRequestsCount = 0;
  int _conflictCount = 0;
  bool _isLoadingDashboardData = false; // Only for dashboard-specific data, not user data

  @override
  void initState() {
    super.initState();
    // Load user data from provider (uses cache if available)
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    userProvider.loadUserData(forceRefresh: false).then((_) {
      // Once user data is loaded (from cache or fresh), load dashboard data
      if (mounted) {
        _loadDashboardData(showCachedFirst: true);
        _loadConflicts();
      }
    });
  }

  Future<void> _loadConflicts() async {
    try {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      
      final todayEvents = await _calendarService.getEventsForDate(now);
      final tomorrowEvents = await _calendarService.getEventsForDate(tomorrow);
      
      final combinedEvents = [...todayEvents, ...tomorrowEvents];
      final uniqueEvents = {for (var e in combinedEvents) e.id: e}.values.toList();
      
      final conflicts = _calendarService.findConflicts(uniqueEvents);
      
      int count = 0;
      for (var list in conflicts.values) {
        count += list.length;
      }
      
      if (mounted) {
        setState(() {
          _conflictCount = count;
        });
      }
    } catch (e) {
      Logger.error('Error loading conflicts', error: e, tag: 'DashboardScreen');
    }
  }

  Future<void> _loadDashboardData({bool showCachedFirst = false}) async {
    // Get user data from provider (uses cache)
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    
    // If showing cached first, don't show loading spinner
    if (!showCachedFirst) {
      setState(() => _isLoadingDashboardData = true);
    }
    
    // Ensure user data is loaded (will use cache if available)
    await userProvider.loadUserData(forceRefresh: false);
    
    // Get user data from provider
    final currentUserModel = userProvider.currentUser;
    final familyMembers = userProvider.familyMembers;
    
    if (currentUserModel == null) {
      Logger.warning('⚠️ Cannot load user model - Firestore may be unavailable', tag: 'DashboardScreen');
      if (mounted) {
        setState(() => _isLoadingDashboardData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot load user data. Firestore may be unavailable.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    
    try {
      // Clear familyId cache to ensure we have the latest value
      _taskService.clearFamilyIdCache();
      
      // Load upcoming birthdays (next 30 days)
      try {
        _upcomingBirthdays = await _birthdayService.getUpcomingBirthdays(days: 30);
      } catch (e) {
        Logger.warning('Error loading upcoming birthdays (non-critical)', error: e, tag: 'DashboardScreen');
        _upcomingBirthdays = [];
      }

      // Load upcoming events (next 7 days)
      final allEvents = await _calendarService.getEvents();
      final now = DateTime.now();
      final weekFromNow = now.add(const Duration(days: 7));
      _upcomingEvents = allEvents
          .where((event) => 
              event.startTime.isAfter(now) && 
              event.startTime.isBefore(weekFromNow))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

      // Load active tasks - force refresh to ensure we get latest data
      List<Task> allTasks = [];
      try {
        // Force refresh to ensure we get newly created jobs
        allTasks = await _taskService.getTasks(forceRefresh: true);
        Logger.debug('Dashboard: Loaded ${allTasks.length} total tasks', tag: 'DashboardScreen');
        
        // Debug: Log all tasks with full details
        if (allTasks.isEmpty) {
          Logger.warning('Dashboard: No tasks loaded from Firestore!', tag: 'DashboardScreen');
        } else {
          for (var task in allTasks) {
            Logger.debug('Dashboard: Task "${task.title}" (id: ${task.id}) - reward: ${task.reward}, needsApproval: ${task.needsApproval}, isCompleted: ${task.isCompleted}, createdBy: ${task.createdBy}', tag: 'DashboardScreen');
          }
        }
      } catch (e, st) {
        Logger.error('Dashboard: Error loading tasks', error: e, stackTrace: st, tag: 'DashboardScreen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading jobs: $e'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        // Continue with empty list - don't break the dashboard
        allTasks = [];
      }
      // Upcoming jobs = tasks with rewards OR needsApproval that are not completed and not awaiting approval
      _upcomingTasks = allTasks
          .where((task) => 
            ((task.reward != null && task.reward! > 0) || task.needsApproval == true) &&
            !task.isCompleted && 
            !task.isAwaitingApproval
          )
          .toList();
      
      // Sort tasks by due date (if available) or creation date
      _upcomingTasks.sort((a, b) {
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        } else if (a.dueDate != null) {
          return -1;
        } else if (b.dueDate != null) {
          return 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      // Calculate wallet balance using WalletService (handles negative balances for Bankers)
      // Pass the already-loaded tasks to avoid duplicate fetch and ensure consistency
      try {
        _walletBalance = await _walletService.calculateWalletBalance(tasks: allTasks);
      } catch (e) {
        Logger.warning('Error calculating wallet balance (non-critical)', error: e, tag: 'DashboardScreen');
        _walletBalance = 0.0;
      }
      
      // Get family wallet balance
      try {
        _familyWalletBalance = await _familyWalletService.getFamilyWalletBalance();
      } catch (e) {
        Logger.warning('Error getting family wallet balance (non-critical)', error: e, tag: 'DashboardScreen');
        _familyWalletBalance = 0.0;
      }
      
      // Check for unread messages for each family member (except current user)
      // This is non-critical, so we'll catch errors and continue
      try {
        final chatService = ChatService();
        final currentUserId = _auth.currentUser?.uid;
        _unreadMessages.clear();
        for (var member in familyMembers) {
          // Skip checking unread for current user
          if (member.uid == currentUserId) continue;
          
          try {
            final hasUnread = await chatService.hasUnreadMessages(member.uid);
            _unreadMessages[member.uid] = hasUnread;
          } catch (e) {
            Logger.warning('Error checking unread for ${member.displayName}', error: e, tag: 'DashboardScreen');
            // Continue with other members
          }
        }
      } catch (e) {
        Logger.warning('Error checking unread messages (non-critical)', error: e, tag: 'DashboardScreen');
        // Continue without unread status
      }

      // Count active and completed jobs
      // Jobs are defined as: tasks with rewards > 0 OR tasks with needsApproval (legacy jobs)
      final currentUserId = _auth.currentUser?.uid;
      
      // Debug: Log all tasks to see their reward values
      for (var task in allTasks) {
        Logger.debug('Dashboard: Task "${task.title}" - reward: ${task.reward}, needsApproval: ${task.needsApproval}, isCompleted: ${task.isCompleted}, createdBy: ${task.createdBy}', tag: 'DashboardScreen');
      }
      
      // Jobs are tasks with rewards OR tasks that need approval (legacy jobs)
      final jobs = allTasks.where((task) => 
        (task.reward != null && task.reward! > 0) || task.needsApproval == true
      ).toList();
      
      Logger.debug('Dashboard: Found ${jobs.length} jobs (${allTasks.where((t) => t.reward != null && t.reward! > 0).length} with rewards, ${allTasks.where((t) => (t.reward == null || t.reward == 0) && t.needsApproval == true).length} legacy) out of ${allTasks.length} total tasks', tag: 'DashboardScreen');
      
      _activeJobsCount = jobs.where((task) => 
        !task.isCompleted || task.isAwaitingApproval
      ).length;
      _completedJobsCount = jobs.where((task) => 
        task.isCompleted && !task.isAwaitingApproval
      ).length;
      
      Logger.debug('Dashboard: Active jobs: $_activeJobsCount, Completed jobs: $_completedJobsCount', tag: 'DashboardScreen');

      // Get pending approvals (jobs that need creator's action)
      _pendingApprovals = allTasks.where((task) {
        if (task.createdBy != currentUserId) return false;
        
        // Pending claim approval
        if (task.hasPendingClaim) return true;
        
        // Completed job awaiting approval
        if (task.isAwaitingApproval) return true;
        
        return false;
      }).toList();
      
      // Sort by creation date (oldest first - prioritize older approvals)
      _pendingApprovals.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _pendingApprovalsCount = _pendingApprovals.length;

      // Load refund notifications
      if (currentUserId != null) {
        final refundNotificationsSnapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUserId)
            .where('type', isEqualTo: 'job_refunded')
            .where('read', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .get();
        
        _refundNotifications = refundNotificationsSnapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
        _refundNotificationsCount = _refundNotifications.length;
      }

      // Load pending payout requests (for Bankers)
      if (currentUserId != null) {
        try {
          _pendingPayoutRequests = await _payoutService.getPendingPayoutRequests();
          _pendingPayoutRequestsCount = _pendingPayoutRequests.length;
        } catch (e) {
          Logger.warning('Error loading pending payout requests', error: e, tag: 'DashboardScreen');
        }
      }

    } catch (e) {
      Logger.error('Error loading dashboard data', error: e, stackTrace: StackTrace.current, tag: 'DashboardScreen');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDashboardData = false;
        });
      }
      
      // Refresh user data in background (non-blocking)
      userProvider.refreshInBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to listen to UserDataProvider changes
    return Consumer<UserDataProvider>(
      builder: (context, userProvider, child) {
        final currentUserModel = userProvider.currentUser;
        final familyMembers = userProvider.familyMembers;
        final familyCreator = userProvider.familyCreator;
        
        // Show loading only if we have no cached data AND dashboard data is loading
        if (currentUserModel == null && userProvider.isLoading) {
          return const LoadingIndicator(message: 'Loading dashboard...');
        }
        
        // If we have cached user data, show dashboard immediately (even if dashboard data is still loading)
        return Scaffold(
          body: _buildDashboardContent(
            currentUserModel: currentUserModel,
            familyMembers: familyMembers,
            familyCreator: familyCreator,
          ),
          floatingActionButton: _buildQuickActionsFAB(),
        );
      },
    );
  }

  Widget _buildQuickActionsFAB() {
    final appState = Provider.of<AppState>(context, listen: false);
    
    return QuickActionsFAB(
      actions: [
        QuickAction(
          label: 'Event',
          icon: Icons.event,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditEventScreen(),
              ),
            );
            if (result == true) {
              _loadDashboardData(showCachedFirst: false);
            }
          },
        ),
        QuickAction(
          label: 'Job',
          icon: Icons.task,
          onTap: () async {
            appState.setCurrentIndex(2); // Switch to Tasks tab
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddEditTaskScreen(),
              ),
            );
            if (result == true) {
              _loadDashboardData(showCachedFirst: false);
            }
          },
        ),
      ],
    );
  }
  
  Widget _buildDashboardContent({
    required UserModel? currentUserModel,
    required List<UserModel> familyMembers,
    required UserModel? familyCreator,
  }) {
    if (_isLoadingDashboardData && currentUserModel == null) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SkeletonStatCard(),
            SkeletonStatCard(),
            SkeletonEventCard(),
            SkeletonEventCard(),
            SkeletonTaskCard(),
            SkeletonTaskCard(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadDashboardData(showCachedFirst: false),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // My Family (Avatars)
            _buildMyFamily(
              currentUserModel: currentUserModel,
              familyMembers: familyMembers,
              familyCreator: familyCreator,
            ),
            const SizedBox(height: 16),

            // Conflict Warning
            if (_conflictCount > 0) ...[
              _buildConflictWarning(),
              const SizedBox(height: 16),
            ],

            // Family Chat Widget
            _buildFamilyChatWidget(),
            const SizedBox(height: 24),
            
            // Pending Approvals (prominent if there are any)
            if (_pendingApprovalsCount > 0) ...[
              _buildPendingApprovals(),
              const SizedBox(height: 16),
            ],
            
            // Refund Notifications (prominent if there are any)
            if (_refundNotificationsCount > 0) ...[
              _buildRefundNotifications(),
              const SizedBox(height: 16),
            ],
            
            // Pending Payout Requests (for Bankers)
            if (_pendingPayoutRequestsCount > 0) ...[
              _buildPendingPayoutRequests(familyMembers),
              const SizedBox(height: 16),
            ],
            
            // Quick Stats
            _buildQuickStats(),
            const SizedBox(height: 24),
            
            // Upcoming Birthdays
            if (_upcomingBirthdays.isNotEmpty) ...[
              _buildUpcomingBirthdays(),
              const SizedBox(height: 24),
            ],
            
            // Upcoming Events
            _buildUpcomingEvents(),
            const SizedBox(height: 24),
            
            // Upcoming Tasks
            _buildUpcomingTasks(familyMembers),
            const SizedBox(height: 24),
            
            // Wallet Balance Card (at the bottom)
            _buildWalletCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    return ModernCard(
      onTap: () {
        // Navigate to wallet/transaction history screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WalletScreen(),
          ),
        );
      },
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, 
                  color: Colors.blue.shade700, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'My Wallet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.blue.shade700),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_walletBalance >= 0 ? '' : '-'}\$${_walletBalance.abs().toStringAsFixed(2)} AUD',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _walletBalance >= 0 ? Colors.blue.shade700 : Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Earned from completed jobs',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.account_balance, 
                  color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Family Wallet:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '\$${_familyWalletBalance.toStringAsFixed(2)} AUD',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Available for job rewards',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictWarning() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SchedulingConflictsScreen()),
        ).then((_) => _loadDashboardData());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scheduling Conflicts Detected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  Text(
                    '$_conflictCount overlaps found today or tomorrow',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.orange.shade800),
          ],
        ),
      ),
    );
  }

  Widget _buildMyFamily({
    required UserModel? currentUserModel,
    required List<UserModel> familyMembers,
    required UserModel? familyCreator,
  }) {
    final currentUserId = _auth.currentUser?.uid;
    
    if (familyMembers.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no members
    }

    // Just the scrollable list of avatars (horizontal scroll if needed, or Wrap)
    // Using SingleChildScrollView for horizontal scrolling like a "Stories" bar
    // Wrapped in Center to center the list when it's smaller than screen width
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Shrink to fit children
          children: familyMembers.map((member) {
          final isCurrentUser = member.uid == currentUserId;
          final hasUnread = _unreadMessages[member.uid] == true;
          
          // Extract first name only
          String firstName = member.displayName.isNotEmpty
              ? member.displayName.split(' ').first
              : member.email.split('@')[0];
          
          // Check if current user can edit relationships (admin only)
          final canEditRelationship = currentUserModel != null && 
              familyCreator != null &&
              (familyCreator.uid == currentUserModel.uid || currentUserModel.isAdmin());
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isCurrentUser
                  ? () {
                      // Navigate to hubs screen on tap
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyHubsScreen(),
                        ),
                      );
                    }
                  : () {
                      // Navigate to private chat with this member
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrivateChatScreen(
                            recipientId: member.uid,
                            recipientName: member.displayName.isNotEmpty
                                ? member.displayName
                                : member.email.split('@')[0],
                          ),
                        ),
                      );
                    },
              onLongPress: isCurrentUser
                  ? () => _showProfilePhotoMenu(context, member, currentUserModel)
                  : canEditRelationship
                      ? () => _showRelationshipMenu(context, member, currentUserModel, familyCreator)
                      : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.purple.shade700,
                        backgroundImage: member.photoUrl != null && member.photoUrl!.isNotEmpty
                            ? NetworkImage(member.photoUrl!)
                            : null,
                        child: member.photoUrl == null || member.photoUrl!.isEmpty
                            ? Text(
                                firstName.isNotEmpty
                                    ? firstName[0].toUpperCase()
                                    : member.email.isNotEmpty
                                        ? member.email[0].toUpperCase()
                                        : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                ),
                              )
                            : null,
                      ),
                      if (hasUnread && !isCurrentUser)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    firstName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

  /// Extract first name from display name
  String _getFirstName(String displayName, String email) {
    if (displayName.isNotEmpty) {
      return displayName.split(' ').first;
    }
    return email.split('@')[0];
  }

  /// Show menu for profile photo (current user only)
  Future<void> _showProfilePhotoMenu(BuildContext context, UserModel member, UserModel? currentUser) async {
    if (currentUser == null || member.uid != currentUser.uid) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Enter Bitmoji URL'),
              onTap: () => Navigator.pop(context, 'bitmoji'),
            ),
            if (member.photoUrl != null && member.photoUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    try {
      if (result == 'delete') {
        await _profilePhotoService.deleteProfilePhoto();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo removed'),
              backgroundColor: Colors.green,
            ),
          );
          _loadDashboardData(showCachedFirst: false);
        }
      } else if (result == 'bitmoji') {
        // Show dialog with options: scan QR or enter URL
        final bitmojiChoice = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner),
                  title: const Text('Scan QR Code'),
                  onTap: () => Navigator.pop(context, 'scan'),
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Enter URL'),
                  onTap: () => Navigator.pop(context, 'enter'),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );

        if (bitmojiChoice == null || !mounted) return;

        String? url;

        if (bitmojiChoice == 'scan') {
          // Scan QR code
          final scannedUrl = await _scanQRCode(context);
          if (scannedUrl != null && mounted) {
            url = scannedUrl;
          } else {
            return; // User cancelled or error
          }
        } else if (bitmojiChoice == 'enter') {
          // Enter URL manually
          final urlController = TextEditingController();
          bool dialogClosed = false;
          
          try {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Enter Bitmoji URL'),
                content: TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    hintText: 'https://sdk.bitmoji.com/...',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      dialogClosed = true;
                      Navigator.pop(context, false);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      dialogClosed = true;
                      Navigator.pop(context, true);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            );

            if (confirmed == true && urlController.text.trim().isNotEmpty && mounted) {
              url = urlController.text.trim();
            }
          } catch (e) {
            Logger.error('Error in bitmoji URL dialog', error: e, tag: 'DashboardScreen');
          } finally {
            // Only dispose if dialog was actually shown and closed
            if (dialogClosed) {
              urlController.dispose();
            } else {
              // If dialog never opened, dispose immediately
              urlController.dispose();
            }
          }
        }

        // Save the URL if we have one
        if (url != null && url.isNotEmpty && mounted) {
          try {
            // Validate URL
            final uri = Uri.tryParse(url);
            if (uri != null && (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
              await _profilePhotoService.updatePhotoUrl(url);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bitmoji URL saved'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadDashboardData(showCachedFirst: false);
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid URL. Please enter a valid http or https URL.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving URL: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } else if (result == 'camera' || result == 'gallery') {
        final source = result == 'camera' ? ImageSource.camera : ImageSource.gallery;
        final pickedFile = await _imagePicker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );

        if (pickedFile != null && mounted) {
          if (kIsWeb) {
            final bytes = await pickedFile.readAsBytes();
            await _profilePhotoService.uploadProfilePhotoWeb(bytes, pickedFile.name);
          } else {
            final file = File(pickedFile.path);
            await _profilePhotoService.uploadProfilePhoto(file);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            _loadDashboardData(showCachedFirst: false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Scan QR code for bitmoji URL
  Future<String?> _scanQRCode(BuildContext context) async {
    final controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    
    String? scannedUrl;
    
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Scan QR Code'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            body: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final barcode = barcodes.first;
                  if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                    scannedUrl = barcode.rawValue;
                    Navigator.pop(context, scannedUrl);
                  }
                }
              },
            ),
          ),
        ),
      );

      return result ?? scannedUrl;
    } finally {
      controller.dispose();
    }
  }

  /// Show menu for relationship editing (admin only)
  Future<void> _showRelationshipMenu(
    BuildContext context,
    UserModel member,
    UserModel? currentUser,
    UserModel? familyCreator,
  ) async {
    if (currentUser == null || familyCreator == null) return;
    if (currentUser.uid != familyCreator.uid && !currentUser.isAdmin()) return;

    showDialog(
      context: context,
      builder: (context) => RelationshipDialog(
        user: member,
        currentUser: currentUser,
        familyCreator: familyCreator,
        onUpdated: () {
          _loadDashboardData(showCachedFirst: false);
        },
      ),
    );
  }

  Widget _buildPendingApprovals() {
    return ModernCard(
      color: Colors.orange.shade50,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Icon(Icons.notifications_active, 
                    color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Approvals',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      Text(
                        '$_pendingApprovalsCount action${_pendingApprovalsCount == 1 ? '' : 's'} needed',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_pendingApprovalsCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._pendingApprovals.take(3).map((task) => _buildApprovalCard(task)),
            if (_pendingApprovals.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () {
                    // Navigate to jobs tab (index 2)
                    Provider.of<AppState>(context, listen: false).setCurrentIndex(2);
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('View all $_pendingApprovalsCount approvals'),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(Task task) {
    final isPendingClaim = task.hasPendingClaim;
    final isAwaitingApproval = task.isAwaitingApproval;
    final taskService = TaskService();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(
                    isPendingClaim ? Icons.person_add : Icons.check_circle_outline,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPendingClaim 
                            ? 'Claim request pending approval'
                            : 'Job completed - awaiting approval',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      if (task.reward != null && task.reward! > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Reward: \$${task.reward!.toStringAsFixed(2)} AUD',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPendingClaim) ...[
                  // For pending claims: Approve or Reject
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        await taskService.rejectClaim(task.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Claim rejected'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          _loadDashboardData();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        if (task.claimedBy != null) {
                          await taskService.approveClaim(task.id, task.claimedBy!);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Claim approved!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadDashboardData();
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve Claim'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else if (isAwaitingApproval) ...[
                  // For completed jobs awaiting approval: Approve or View
                  TextButton.icon(
                    onPressed: () {
                      // Navigate to jobs tab to see details
                      Provider.of<AppState>(context, listen: false).setCurrentIndex(2);
                    },
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await taskService.approveJob(task.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Job approved!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadDashboardData();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Approve Job'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundNotifications() {
    return Card(
      elevation: 3,
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.undo, 
                    color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refund Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      Text(
                        '$_refundNotificationsCount notification${_refundNotificationsCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_refundNotificationsCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._refundNotifications.take(3).map((notification) => _buildRefundNotificationCard(notification)),
            if (_refundNotifications.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () {
                    // Navigate to jobs tab (index 2)
                    Provider.of<AppState>(context, listen: false).setCurrentIndex(2);
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('View all $_refundNotificationsCount notifications'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundNotificationCard(Map<String, dynamic> notification) {
    final jobId = notification['jobId'] as String?;
    final jobTitle = notification['jobTitle'] as String? ?? 'A job';
    final reason = notification['reason'] as String?;
    final note = notification['note'] as String?;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(
                    Icons.undo,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jobTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Funds have been returned to your wallet',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      if (reason != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Reason: $reason',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (note != null && note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Note: $note',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    // Mark notification as read
                    final notificationId = notification['id'] as String?;
                    if (notificationId != null) {
                      await _firestore
                          .collection('notifications')
                          .doc(notificationId)
                          .update({'read': true});
                    }
                    _loadDashboardData(showCachedFirst: false);
                  },
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Dismiss'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Mark notification as read
                    final notificationId = notification['id'] as String?;
                    if (notificationId != null) {
                      await _firestore
                          .collection('notifications')
                          .doc(notificationId)
                          .update({'read': true});
                    }
                    // Show refund notification dialog with options
                    if (jobId != null) {
                      final result = await showDialog(
                        context: context,
                        builder: (context) => RefundNotificationDialog(jobId: jobId),
                      );
                      if (result == true && mounted) {
                        _loadDashboardData();
                      }
                    }
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Manage Job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingPayoutRequests(List<UserModel> familyMembers) {
    return Card(
      elevation: 3,
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.request_quote, 
                    color: Colors.purple.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Payout Requests',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                      Text(
                        '$_pendingPayoutRequestsCount request${_pendingPayoutRequestsCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.purple.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_pendingPayoutRequestsCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._pendingPayoutRequests.take(3).map((request) => _buildPayoutRequestCard(request, familyMembers)),
            if (_pendingPayoutRequests.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () {
                    // Could navigate to a full payout requests screen
                    // For now, just refresh
                    _loadDashboardData();
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('View all $_pendingPayoutRequestsCount requests'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutRequestCard(PayoutRequest request, List<UserModel> familyMembers) {
    // Get requester name
    final requester = familyMembers.firstWhere(
      (m) => m.uid == request.userId,
      orElse: () => UserModel(
        uid: request.userId,
        email: '',
        displayName: 'Unknown',
        createdAt: DateTime.now(),
        familyId: '',
      ),
    );
    final requesterName = requester.displayName.isNotEmpty 
        ? requester.displayName 
        : requester.email;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: Icon(
                    Icons.person,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requesterName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requests \$${request.amount.toStringAsFixed(2)} AUD',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${request.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final result = await showDialog(
                      context: context,
                      builder: (context) => ApprovePayoutDialog(payoutRequest: request),
                    );
                    if (result == true && mounted) {
                      _loadDashboardData();
                    }
                  },
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Approve'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final reasonController = TextEditingController();
                    final reason = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Reject Payout Request'),
                        content: TextField(
                          controller: reasonController,
                          decoration: const InputDecoration(
                            labelText: 'Reason for rejection',
                            hintText: 'Enter reason...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, reasonController.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    );
                    if (reason != null && reason.isNotEmpty && mounted) {
                      try {
                        await _payoutService.rejectPayoutRequest(request.id, reason);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payout request rejected'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          _loadDashboardData();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return ModernCard(
      padding: EdgeInsets.zero, // Remove padding here, apply to InkWell children
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    final appState = Provider.of<AppState>(context, listen: false);
                    // Navigate to Tasks tab (index 2), Active tab (0)
                    appState.setCurrentIndexWithTasksTab(2, 0);
                  },
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt, color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _activeJobsCount.toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Active Jobs',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 60, color: Colors.grey.shade200), // Divider
              Expanded(
                child: InkWell(
                  onTap: () {
                    final appState = Provider.of<AppState>(context, listen: false);
                    // Navigate to Tasks tab (index 2), Completed tab (1)
                    appState.setCurrentIndexWithTasksTab(2, 1);
                  },
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _completedJobsCount.toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Completed',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          // Row 3: Add Job button
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddEditTaskScreen(),
                    ),
                  );
                  if (result == true && mounted) {
                    // Wait a moment for Firestore to process, then force refresh
                    await Future.delayed(const Duration(milliseconds: 500));
                    await _loadDashboardData(showCachedFirst: false);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Job'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {int? tabIndex}) {
    // Determine which tab to navigate to based on label
    int? targetTab;
    if (label == 'Active Jobs' || label == 'Completed') {
      targetTab = 2; // Jobs tab
    } else if (label == 'Approvals') {
      targetTab = 2; // Jobs tab (to see approvals)
    }
    
    return StatCard(
      title: label,
      value: value,
      icon: icon,
      color: color,
      onTap: targetTab != null
          ? () {
              final appState = Provider.of<AppState>(context, listen: false);
              if (tabIndex != null) {
                appState.setCurrentIndexWithTasksTab(targetTab!, tabIndex);
              } else {
                appState.setCurrentIndex(targetTab!);
              }
            }
          : null,
    );
  }

  Widget _buildUpcomingEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Upcoming Events',
          onSeeAll: () {
            // Navigate to calendar tab (index 1)
            Provider.of<AppState>(context, listen: false).setCurrentIndex(1);
          },
        ),
        const SizedBox(height: AppTheme.spacingSM),
        if (_upcomingEvents.isEmpty)
          ModernCard(
            child: EmptyState(
              icon: Icons.event_outlined,
              title: 'No upcoming events',
              message: 'Create your first event!',
            ),
          )
        else
          ..._upcomingEvents.take(5).map((event) => _buildEventCard(event)),
      ],
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(
            Icons.event,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(event.title),
        subtitle: Text(
          '${app_date_utils.AppDateUtils.formatDate(event.startTime)} '
          '${DateFormat('HH:mm').format(event.startTime)}',
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () {
          // Navigate to calendar tab (index 1)
          Provider.of<AppState>(context, listen: false).setCurrentIndex(1);
        },
      ),
    );
  }

  Widget _buildUpcomingTasks(List<UserModel> familyMembers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Upcoming Jobs',
          onSeeAll: () {
            // Navigate to jobs tab (index 2)
            Provider.of<AppState>(context, listen: false).setCurrentIndex(2);
          },
        ),
        const SizedBox(height: AppTheme.spacingSM),
        if (_upcomingTasks.isEmpty)
          ModernCard(
            child: EmptyState(
              icon: Icons.task_outlined,
              title: 'No active jobs',
              message: 'Create your first job!',
            ),
          )
        else
          ..._upcomingTasks.take(5).map((task) => _buildTaskCard(task, familyMembers)),
      ],
    );
  }

  Widget _buildTaskCard(Task task, List<UserModel> familyMembers) {
    final isOverdue = task.dueDate != null && 
        task.dueDate!.isBefore(DateTime.now()) && 
        !task.isCompleted;
    
    final currentUserId = _auth.currentUser?.uid;
    final isCreator = task.createdBy == currentUserId;
    final isClaimed = task.isClaimed;
    final hasPendingClaim = task.hasPendingClaim;
    final isClaimer = isClaimed && task.claimedBy == currentUserId;
    
    // For tasks that don't require claim: anyone (including creator) can complete if not claimed
    // For tasks that require claim: only the claimer can complete (after claiming)
    // Creators can always complete their own jobs (to get funds back)
    final canComplete = (!isClaimed && !hasPendingClaim && !task.requiresClaim) || isCreator;
    final canCompleteAsClaimer = isClaimer && task.requiresClaim;
    final canClaim = !isCreator && !isClaimed && !hasPendingClaim && !task.requiresClaim;
    final canClaimWithApproval = !isCreator && !isClaimed && !hasPendingClaim && task.requiresClaim;
    
    // Get claimer name if claimed
    String? claimerName;
    if (isClaimed && task.claimedBy != null) {
      final claimerId = task.claimedBy!;
      // Try to find in family members first
      final claimer = familyMembers.firstWhere(
        (m) => m.uid == claimerId,
        orElse: () => UserModel(
          uid: claimerId,
          email: '',
          displayName: 'Unknown',
          createdAt: DateTime.now(),
          familyId: '',
        ),
      );
      claimerName = claimer.displayName.isNotEmpty ? claimer.displayName : claimer.email;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Navigate to jobs tab (index 2) to see the job details
          Provider.of<AppState>(context, listen: false).setCurrentIndex(2);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getPriorityColor(task.priority).withOpacity(0.1),
                    child: Icon(
                      Icons.work_outline,
                      color: _getPriorityColor(task.priority),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Claim status
                        if (!task.requiresClaim && !isClaimed && !hasPendingClaim)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Open',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          )
                        else if (isClaimed && claimerName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Claimed by $claimerName',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          )
                        else if (hasPendingClaim)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Claim Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (task.priority == 'high')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'HIGH',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (task.dueDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Due: ${app_date_utils.AppDateUtils.formatDate(task.dueDate!)}',
                    style: TextStyle(
                      color: isOverdue ? Colors.red : Colors.grey[600],
                      fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (task.reward != null && task.reward! > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Reward: \$${task.reward!.toStringAsFixed(2)} AUD',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              if (canComplete || canCompleteAsClaimer) ...[
                // Job doesn't require claiming OR user is the claimer - show "Job Done!" button
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {}, // Stop event propagation to parent InkWell
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _taskService.completeTask(task.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Job completed!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadDashboardData();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error completing job: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Job Done!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
              ] else if (canClaimWithApproval) ...[
                // Job requires claiming - show "Claim Now" button
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {}, // Stop event propagation to parent InkWell
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _taskService.claimJob(task.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Job claimed successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadDashboardData();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error claiming job: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Claim Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Member colors for avatars (consistent with existing pattern)
  static final List<Color> _memberColors = [
    Colors.purple,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.cyan,
  ];

  Color _getMemberColor(int index) {
    return _memberColors[index % _memberColors.length];
  }

  Widget _buildUpcomingBirthdays() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Upcoming Birthdays',
          action: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              ).then((_) {
                // Refresh dashboard after profile edit
                _loadDashboardData();
              });
            },
            child: const Text('Edit Profile'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _upcomingBirthdays.length,
            itemBuilder: (context, index) {
              final birthday = _upcomingBirthdays[index];
              final member = birthday.user;
              final daysUntil = birthday.upcomingDate.difference(DateTime.now()).inDays;
              
              String relativeTime;
              if (daysUntil == 0) {
                relativeTime = 'Today!';
              } else if (daysUntil == 1) {
                relativeTime = 'Tomorrow';
              } else {
                relativeTime = 'In $daysUntil days';
              }

              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: Card(
                  elevation: 2,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      ).then((_) {
                        _loadDashboardData();
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: _getMemberColor(index),
                                child: Text(
                                  member.displayName.isNotEmpty
                                      ? member.displayName[0].toUpperCase()
                                      : member.email[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.pink,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cake,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Flexible(
                            child: Text(
                              member.displayName.isNotEmpty
                                  ? member.displayName
                                  : member.email.split('@')[0],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Turning ${birthday.ageTurning}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            relativeTime,
                            style: TextStyle(
                              fontSize: 9,
                              color: daysUntil <= 1 
                                  ? Colors.pink[700] 
                                  : Colors.grey[600],
                              fontWeight: daysUntil <= 1 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyChatWidget() {
    return ChatWidget(
      messagesStream: _chatService.getMessagesStream(),
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
        );

        await _chatService.sendMessage(message);
      },
      currentUserId: _chatService.currentUserId,
      currentUserName: _chatService.currentUserName,
      maxHeight: 400, // Max height for embedded chat
      onViewFullChat: () {
        // Navigate to full chat screen (ChatTabsScreen)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChatTabsScreen(),
          ),
        );
      },
      emptyStateMessage: 'No messages yet. Start the conversation!',
    );
  }
}

