import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/app_state.dart';
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
import '../hubs/my_hubs_screen.dart';
import '../tasks/add_edit_task_screen.dart';
import '../tasks/refund_notification_dialog.dart';
import '../wallet/approve_payout_dialog.dart';
import '../../widgets/relationship_dialog.dart';
import '../../widgets/ui_components.dart';
import '../../utils/app_theme.dart';
import '../../services/payout_service.dart';
import '../../models/payout_request.dart';
import '../../services/birthday_service.dart';
import '../../screens/profile/edit_profile_screen.dart';
import 'package:intl/intl.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CalendarEvent> _upcomingEvents = [];
  List<BirthdayInfo> _upcomingBirthdays = [];
  List<Task> _upcomingTasks = [];
  List<Task> _pendingApprovals = [];
  List<Map<String, dynamic>> _refundNotifications = []; // List of refund notification documents
  List<PayoutRequest> _pendingPayoutRequests = []; // Pending payout requests (for Bankers)
  List<UserModel> _familyMembers = [];
  Map<String, bool> _unreadMessages = {}; // Map of userId -> hasUnreadMessages
  UserModel? _familyCreator;
  UserModel? _currentUserModel;
  double _walletBalance = 0.0;
  double _familyWalletBalance = 0.0;
  int _activeJobsCount = 0;
  int _completedJobsCount = 0;
  int _pendingApprovalsCount = 0;
  int _refundNotificationsCount = 0;
  int _pendingPayoutRequestsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // Set up periodic refresh to check for new approvals
    _setupPeriodicRefresh();
  }

  void _setupPeriodicRefresh() {
    // Refresh every 30 seconds to check for new approvals
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadDashboardData();
        _setupPeriodicRefresh(); // Schedule next refresh
      }
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    // CRITICAL: Load family members FIRST, before any other operations
    // This ensures they're available even if other operations fail
    try {
      final authService = AuthService();
      final currentUserId = _auth.currentUser?.uid;
      
      // Get current user model first
      _currentUserModel = await authService.getCurrentUserModel();
      
      // Get all family members (this includes current user)
      final allFamilyMembers = await authService.getFamilyMembers();
      
      debugPrint('=== LOADING FAMILY MEMBERS (PRIORITY) ===');
      debugPrint('Current User ID: $currentUserId');
      debugPrint('Current user model: ${_currentUserModel?.displayName} (${_currentUserModel?.uid})');
      debugPrint('Current user familyId: "${_currentUserModel?.familyId}"');
      debugPrint('All family members from query: ${allFamilyMembers.length}');
      
      // Build the family members list immediately
      _familyMembers = [];
      if (allFamilyMembers.isNotEmpty) {
        debugPrint('✓ Using ${allFamilyMembers.length} members from query');
        // Sort: current user first, then others alphabetically
        final sorted = List<UserModel>.from(allFamilyMembers);
        sorted.sort((a, b) {
          if (a.uid == currentUserId) return -1;
          if (b.uid == currentUserId) return 1;
          return a.displayName.compareTo(b.displayName);
        });
        _familyMembers = sorted;
        debugPrint('✓ Sorted list has ${_familyMembers.length} members');
      } else if (_currentUserModel != null) {
        debugPrint('⚠️ Query returned empty, adding current user only');
        _familyMembers.add(_currentUserModel!);
      }
      
      debugPrint('=== FAMILY MEMBERS LOADED ===');
      debugPrint('_familyMembers.length: ${_familyMembers.length}');
      for (var member in _familyMembers) {
        debugPrint('  - ${member.displayName} (${member.uid}), familyId: "${member.familyId}"');
      }
      
      // Get family creator (non-critical)
      try {
        _familyCreator = await authService.getFamilyCreator();
        debugPrint('Family creator: ${_familyCreator?.displayName} (${_familyCreator?.uid})');
      } catch (e) {
        debugPrint('Error getting family creator (non-critical): $e');
        _familyCreator = null;
      }
    } catch (e) {
      debugPrint('Error loading family members: $e');
      // Even if this fails, try to at least show current user
      if (_currentUserModel != null && _familyMembers.isEmpty) {
        _familyMembers = [_currentUserModel!];
      }
    }
    
    try {
      // Clear familyId cache to ensure we have the latest value
      _taskService.clearFamilyIdCache();
      
      // Load upcoming birthdays (next 30 days)
      try {
        _upcomingBirthdays = await _birthdayService.getUpcomingBirthdays(days: 30);
      } catch (e) {
        debugPrint('Error loading upcoming birthdays (non-critical): $e');
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

      // Load active tasks with force refresh to ensure we get the latest data
      final allTasks = await _taskService.getTasks(forceRefresh: true);
      _upcomingTasks = allTasks
          .where((task) => !task.isCompleted && !task.isAwaitingApproval)
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
        debugPrint('Error calculating wallet balance (non-critical): $e');
        _walletBalance = 0.0;
      }
      
      // Get family wallet balance
      try {
        _familyWalletBalance = await _familyWalletService.getFamilyWalletBalance();
      } catch (e) {
        debugPrint('Error getting family wallet balance (non-critical): $e');
        _familyWalletBalance = 0.0;
      }
      
      // Check for unread messages for each family member (except current user)
      // This is non-critical, so we'll catch errors and continue
      try {
        final chatService = ChatService();
        final currentUserId = _auth.currentUser?.uid;
        _unreadMessages.clear();
        for (var member in _familyMembers) {
          // Skip checking unread for current user
          if (member.uid == currentUserId) continue;
          
          try {
            final hasUnread = await chatService.hasUnreadMessages(member.uid);
            _unreadMessages[member.uid] = hasUnread;
          } catch (e) {
            debugPrint('Error checking unread for ${member.displayName}: $e');
            // Continue with other members
          }
        }
      } catch (e) {
        debugPrint('Error checking unread messages (non-critical): $e');
        // Continue without unread status
      }

      // Count active and completed jobs
      final currentUserId = _auth.currentUser?.uid;
      _activeJobsCount = allTasks.where((task) => 
        !task.isCompleted || task.isAwaitingApproval
      ).length;
      _completedJobsCount = allTasks.where((task) => 
        task.isCompleted && !task.isAwaitingApproval
      ).length;

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
          debugPrint('Error loading pending payout requests: $e');
        }
      }

    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      debugPrint('Error stack trace: ${StackTrace.current}');
    } finally {
      if (mounted) {
        debugPrint('=== CALLING setState TO UPDATE UI ===');
        debugPrint('_familyMembers.length before setState: ${_familyMembers.length}');
        setState(() {
          _isLoading = false;
        });
        debugPrint('_familyMembers.length after setState: ${_familyMembers.length}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading dashboard...');
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // My Family Section (at the top)
            _buildMyFamily(),
            const SizedBox(height: 16),
            
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
              _buildPendingPayoutRequests(),
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
            _buildUpcomingTasks(),
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

  Widget _buildMyFamily() {
    final currentUserId = _auth.currentUser?.uid;
    
    return ModernCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Icon(Icons.people, 
                    color: Colors.purple.shade700, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'My Family',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_familyMembers.isEmpty)
                  Text(
                    'No members',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  )
                else
                  Text(
                    '${_familyMembers.length} member${_familyMembers.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_familyMembers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No family members yet',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _familyMembers.map((member) {
                  final isCurrentUser = member.uid == currentUserId;
                  final hasUnread = _unreadMessages[member.uid] == true;
                  
                  // Calculate relationship from current user's perspective
                  String? relationshipLabel;
                  if (_currentUserModel != null && _familyCreator != null) {
                    final relationship = RelationshipUtils.getRelationshipFromPerspective(
                      viewer: _currentUserModel!,
                      target: member,
                      creator: _familyCreator,
                      allMembers: _familyMembers,
                    );
                    relationshipLabel = relationship != null 
                        ? RelationshipUtils.getRelationshipLabel(relationship)
                        : null;
                  }
                  
                  // Check if current user can edit relationships
                  final canEditRelationship = _currentUserModel != null && 
                      _familyCreator != null &&
                      (_familyCreator!.uid == _currentUserModel!.uid || _currentUserModel!.isAdmin());
                  
                  return InkWell(
                    onTap: isCurrentUser ? () {
                      // Navigate to My Hubs page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyHubsScreen(),
                        ),
                      );
                    } : () async {
                      // Navigate to chat and wait for return
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrivateChatScreen(
                            recipientId: member.uid,
                            recipientName: member.displayName,
                          ),
                        ),
                      );
                      // Refresh dashboard data when returning from chat
                      // This updates the unread message indicators
                      if (mounted) {
                        _loadDashboardData();
                      }
                    },
                    onLongPress: canEditRelationship && !isCurrentUser ? () {
                      showDialog(
                        context: context,
                        builder: (context) => RelationshipDialog(
                          user: member,
                          currentUser: _currentUserModel,
                          familyCreator: _familyCreator,
                          onUpdated: () {
                            _loadDashboardData();
                          },
                        ),
                      );
                    } : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Opacity(
                      opacity: isCurrentUser ? 0.7 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCurrentUser 
                              ? Colors.purple.shade100 
                              : Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.purple.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.purple.shade700,
                                  radius: 20,
                                  child: Text(
                                    member.displayName.isNotEmpty
                                        ? member.displayName[0].toUpperCase()
                                        : member.email[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      member.displayName.isNotEmpty
                                          ? member.displayName
                                          : member.email.split('@')[0],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.purple.shade900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isCurrentUser) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '(You)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (relationshipLabel != null)
                                  Text(
                                    relationshipLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (member.roles.isNotEmpty)
                                  Text(
                                    member.roles.join(', ').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.purple.shade600,
                                    ),
                                  ),
                              ],
                            ),
                            if (!isCurrentUser) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                                color: Colors.purple.shade700,
                              ),
                            ],
                            if (canEditRelationship && !isCurrentUser) ...[
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Tap to edit relationship',
                                child: InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => RelationshipDialog(
                                        user: member,
                                        currentUser: _currentUserModel,
                                        familyCreator: _familyCreator,
                                        onUpdated: () {
                                          _loadDashboardData();
                                        },
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.purple.shade700,
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
                }).toList(),
              ),
          ],
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
                    if (notification['id'] != null) {
                      await _firestore
                          .collection('notifications')
                          .doc(notification['id'])
                          .update({'read': true});
                    }
                    _loadDashboardData();
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
                    if (notification['id'] != null) {
                      await _firestore
                          .collection('notifications')
                          .doc(notification['id'])
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

  Widget _buildPendingPayoutRequests() {
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
            ..._pendingPayoutRequests.take(3).map((request) => _buildPayoutRequestCard(request)),
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

  Widget _buildPayoutRequestCard(PayoutRequest request) {
    // Get requester name
    final requester = _familyMembers.firstWhere(
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Active Jobs',
                _activeJobsCount.toString(),
                Icons.task_alt,
                Colors.orange,
                tabIndex: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Completed',
                _completedJobsCount.toString(),
                Icons.check_circle,
                Colors.green,
                tabIndex: 1,
              ),
            ),
            if (_pendingApprovalsCount > 0) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Approvals',
                  _pendingApprovalsCount.toString(),
                  Icons.notifications_active,
                  Colors.orange,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
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
                _loadDashboardData();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Job'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
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

  Widget _buildUpcomingTasks() {
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
          ..._upcomingTasks.take(5).map((task) => _buildTaskCard(task)),
      ],
    );
  }

  Widget _buildTaskCard(Task task) {
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
      final claimer = _familyMembers.firstWhere(
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
}

