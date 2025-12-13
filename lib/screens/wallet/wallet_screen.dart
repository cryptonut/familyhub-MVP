import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/services/logger_service.dart';
import '../../services/task_service.dart';
import '../../services/wallet_service.dart';
import '../../services/payout_service.dart';
import '../../services/recurring_payment_service.dart';
import '../../services/auth_service.dart';
import '../../models/task.dart';
import '../../models/recurring_payment.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../tasks/view_task_screen.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'request_payout_dialog.dart';
import 'recurring_payments_screen.dart';
import '../budget/budget_home_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  final PayoutService _payoutService = PayoutService();
  final RecurringPaymentService _recurringPaymentService = RecurringPaymentService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Task> _createdJobs = []; // Jobs created by user (if Banker/Admin)
  List<Task> _completedJobs = []; // Jobs completed by user
  List<RecurringPayment> _pocketMoneyPayments = []; // Recurring payments received
  Map<String, String> _userNames = {}; // Map of user ID to display name
  Map<String, double> _runningBalances = {}; // Map of task ID to running balance after that transaction
  double _totalBalance = 0.0;
  bool _isLoading = true;
  bool _isBanker = false;

  @override
  void initState() {
    super.initState();
    _loadTransactionHistory();
  }

  Future<void> _loadTransactionHistory() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch tasks once to ensure consistency between transactions and balance
      final taskService = TaskService();
      final allTasks = await taskService.getTasks(forceRefresh: true);
      
      // Get transactions using WalletService (pass tasks to avoid duplicate fetch)
      final transactions = await _walletService.getTransactions(tasks: allTasks);
      _createdJobs = transactions['created'] ?? [];
      _completedJobs = transactions['completed'] ?? [];
      
      // Calculate total balance using the same tasks list
      _totalBalance = await _walletService.calculateWalletBalance(tasks: allTasks);
      
      // Calculate running balances for each transaction
      _calculateRunningBalances();
      
      // Check if user is Banker
      final userModel = await _authService.getCurrentUserModel();
      _isBanker = userModel?.isBanker() == true || userModel?.isAdmin() == true;
      
      // Load pocket money payments
      _pocketMoneyPayments = await _recurringPaymentService.getUserRecurringPayments();
      
      // Fetch user names for all jobs and pocket money
      final userIds = <String>{};
      for (var task in _createdJobs) {
        if (task.createdBy != null && task.createdBy!.isNotEmpty) {
          userIds.add(task.createdBy!);
        }
        if (task.claimedBy != null && task.claimedBy!.isNotEmpty) {
          userIds.add(task.claimedBy!);
        }
        if (task.assignedTo.isNotEmpty) {
          userIds.add(task.assignedTo);
        }
      }
      for (var task in _completedJobs) {
        if (task.claimedBy != null && task.claimedBy!.isNotEmpty) {
          userIds.add(task.claimedBy!);
        }
        if (task.assignedTo.isNotEmpty) {
          userIds.add(task.assignedTo);
        }
      }
      for (var payment in _pocketMoneyPayments) {
        if (payment.fromUserId.isNotEmpty) {
          userIds.add(payment.fromUserId);
        }
      }
      
      for (var userId in userIds) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            _userNames[userId] = userData?['displayName'] as String? ?? 
                                 userData?['email'] as String? ?? 
                                 'Unknown User';
          }
        } catch (e) {
          Logger.warning('Error fetching user name for $userId', error: e, tag: 'WalletScreen');
          _userNames[userId] = 'Unknown User';
        }
      }
      
    } catch (e) {
      Logger.error('Error loading transaction history', error: e, tag: 'WalletScreen');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Calculate running balance after each transaction
  /// Transactions are sorted chronologically (oldest first), then we work forward
  void _calculateRunningBalances() {
    _runningBalances.clear();
    
    // Create a list of all transactions with their type and date
    final List<Map<String, dynamic>> allTransactions = [];
    
    // Add created jobs (liabilities - negative)
    for (var task in _createdJobs) {
      final transactionDate = task.createdAt;
      allTransactions.add({
        'task': task,
        'type': 'created',
        'date': transactionDate,
        'amount': -(task.reward ?? 0),
      });
    }
    
    // Add completed jobs (income - positive)
    for (var task in _completedJobs) {
      final transactionDate = task.completedAt ?? task.createdAt;
      allTransactions.add({
        'task': task,
        'type': 'completed',
        'date': transactionDate,
        'amount': task.reward ?? 0,
      });
    }
    
    // Sort by date (oldest first)
    allTransactions.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    
    // Calculate running balance starting from 0
    double runningBalance = 0.0;
    for (var transaction in allTransactions) {
      runningBalance += transaction['amount'] as double;
      final task = transaction['task'] as Task;
      _runningBalances[task.id] = runningBalance;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet & Transactions'),
        actions: [
          if (_isBanker)
            IconButton(
              icon: const Icon(Icons.account_balance_wallet),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecurringPaymentsScreen(),
                  ),
                );
                if (result == true && mounted) {
                  _loadTransactionHistory();
                }
              },
              tooltip: 'Manage Recurring Payments',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTransactionHistory,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Summary Card
                    _buildBalanceCard(),
                    
                    // Transaction History
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transaction History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Pocket Money Section (if user receives pocket money)
                          if (_pocketMoneyPayments.isNotEmpty) ...[
                            Text(
                              'Pocket Money',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._pocketMoneyPayments.map((payment) => _buildPocketMoneyCard(payment)),
                            const SizedBox(height: 24),
                          ],
                          if (_createdJobs.isEmpty && _completedJobs.isEmpty && _pocketMoneyPayments.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No transactions yet',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Create or complete jobs with rewards to see transactions here',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            // Created Jobs (Outgoing/Liability)
                            if (_createdJobs.isNotEmpty) ...[
                              Text(
                                'Jobs Created (Liability)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._createdJobs.map((task) => _buildCreatedJobCard(task)),
                              const SizedBox(height: 24),
                            ],
                            // Completed Jobs (Income)
                            if (_completedJobs.isNotEmpty) ...[
                              Text(
                                'Jobs Completed (Income)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._completedJobs.map((task) => _buildTransactionCard(task)),
                            ],
                          ],
                        ],
                      ),
                    ),
                    
                    // Budget Section - at the bottom
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        ),
                        child: InkWell(
                          onTap: () {
                            try {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const BudgetHomeScreen(),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error opening budgets: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    color: AppTheme.primaryColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Family Budgets',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Track income, expenses, and savings goals',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to manage budgets',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade500,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_totalBalance >= 0 ? '' : '-'}\$${_totalBalance.abs().toStringAsFixed(2)} AUD',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: _totalBalance >= 0 ? Colors.white : Colors.red.shade100,
            ),
          ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_completedJobs.length} completed, ${_createdJobs.length} created',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              if (_totalBalance > 0) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await showDialog(
                        context: context,
                        builder: (context) => RequestPayoutDialog(
                          currentBalance: _totalBalance,
                        ),
                      );
                      if (result == true && mounted) {
                        _loadTransactionHistory();
                      }
                    },
                    icon: const Icon(Icons.request_quote),
                    label: const Text('Request Payout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Task task) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewTaskScreen(task: task),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(
            Icons.check_circle,
            color: Colors.green.shade700,
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.completedAt != null) ...[
              Text(
                'Completed: ${dateFormat.format(task.completedAt!)} at ${timeFormat.format(task.completedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ] else ...[
              Text(
                'Completed: ${dateFormat.format(task.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (task.claimedBy != null && task.claimStatus == 'approved')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Completed by: ${_userNames[task.claimedBy] ?? _userNames[task.assignedTo] ?? "Unknown"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else if (task.assignedTo.isNotEmpty && task.assignedTo != task.createdBy)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Assigned to: ${_userNames[task.assignedTo] ?? "Unknown"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+\$${task.reward!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'AUD',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (_runningBalances.containsKey(task.id)) ...[
                      const SizedBox(width: 4),
                      Text(
                        'Balance: \$${_runningBalances[task.id]!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCreatedJobCard(Task task) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isCompleted = task.isCompleted && !task.isAwaitingApproval;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.red.shade50,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewTaskScreen(task: task),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCompleted ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            isCompleted ? Icons.check_circle : Icons.pending,
            color: isCompleted ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Created: ${dateFormat.format(task.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (isCompleted && task.completedAt != null)
              Text(
                'Completed: ${dateFormat.format(task.completedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              )
            else if (!isCompleted)
              Text(
                task.isAwaitingApproval 
                    ? 'Awaiting approval' 
                    : 'Pending completion',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '-\$${task.reward!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'AUD',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (_runningBalances.containsKey(task.id)) ...[
                      const SizedBox(width: 4),
                      Text(
                        'Balance: \$${_runningBalances[task.id]!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildPocketMoneyCard(RecurringPayment payment) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final giverName = _userNames[payment.fromUserId] ?? 'Unknown';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.green.shade50,
      child: InkWell(
        onTap: () {
          // Could show details or navigate to recurring payments
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pocket Money from $giverName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${payment.amount.toStringAsFixed(2)} AUD ${payment.frequency}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                    if (payment.nextPaymentDate != null)
                      Text(
                        'Next: ${dateFormat.format(payment.nextPaymentDate!)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

