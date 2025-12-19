import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/coparenting_expense.dart';
import '../../models/user_model.dart';
import '../../services/coparenting_service.dart';
import '../../services/auth_service.dart';
import '../../services/hub_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'create_edit_expense_screen.dart';

/// Screen for managing co-parenting expenses
class ExpensesScreen extends StatefulWidget {
  final String hubId;

  const ExpensesScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final CoparentingService _service = CoparentingService();
  final HubService _hubService = HubService();
  final AuthService _authService = AuthService();
  List<CoparentingExpense> _expenses = [];
  List<UserModel> _members = [];
  String? _selectedChildId;
  ExpenseStatus? _selectedStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hub = await _hubService.getHub(widget.hubId);
      final expenses = await _service.getExpenses(
        hubId: widget.hubId,
        childId: _selectedChildId,
        status: _selectedStatus,
      );
      
      // Load hub members
      final members = <UserModel>[];
      if (hub != null) {
        for (var memberId in hub.memberIds) {
          final user = await _authService.getUserModel(memberId);
          if (user != null) {
            members.add(user);
          }
        }
      }

      if (mounted) {
        setState(() {
          _expenses = expenses;
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expenses: $e')),
        );
      }
    }
  }

  UserModel? _getMember(String userId) {
    try {
      return _members.firstWhere((m) => m.uid == userId);
    } catch (e) {
      return null;
    }
  }

  Color _getStatusColor(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.pending:
        return Colors.orange;
      case ExpenseStatus.approved:
        return Colors.green;
      case ExpenseStatus.rejected:
        return Colors.red;
      case ExpenseStatus.paid:
        return Colors.blue;
    }
  }

  String _getStatusLabel(ExpenseStatus status) {
    switch (status) {
      case ExpenseStatus.pending:
        return 'Pending';
      case ExpenseStatus.approved:
        return 'Approved';
      case ExpenseStatus.rejected:
        return 'Rejected';
      case ExpenseStatus.paid:
        return 'Paid';
    }
  }

  Future<void> _approveExpense(CoparentingExpense expense) async {
    try {
      await _service.approveExpense(
        hubId: widget.hubId,
        expenseId: expense.id,
      );
      if (mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Expense approved'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving expense: $e')),
        );
      }
    }
  }

  Future<void> _rejectExpense(CoparentingExpense expense) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject expense: ${expense.description}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Enter rejection reason',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (reasonController.text.isNotEmpty) {
          await _service.rejectExpenseWithReason(
            hubId: widget.hubId,
            expenseId: expense.id,
            reason: reasonController.text,
          );
        } else {
          await _service.rejectExpense(
            hubId: widget.hubId,
            expenseId: expense.id,
          );
        }
        if (mounted) {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense rejected'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rejecting expense: $e')),
          );
        }
      }
    }
  }

  Future<void> _markAsPaid(CoparentingExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Text('Mark expense "${expense.description}" as paid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.markExpenseAsPaid(
          hubId: widget.hubId,
          expenseId: expense.id,
        );
        if (mounted) {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Expense marked as paid'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error marking expense as paid: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Expenses'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filters
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedChildId,
                          decoration: const InputDecoration(
                            labelText: 'Child',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Children')),
                            ..._members.map((member) => DropdownMenuItem(
                                  value: member.uid,
                                  child: Text(member.displayName),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedChildId = value;
                            });
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: DropdownButtonFormField<ExpenseStatus>(
                          value: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Statuses')),
                            ...ExpenseStatus.values.map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(_getStatusLabel(status)),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value;
                            });
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Expenses list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: _expenses.isEmpty
                        ? Center(
                            child: EmptyState(
                              icon: Icons.attach_money_outlined,
                              title: 'No Expenses',
                              message: 'Track and split expenses with your co-parent',
                              action: ElevatedButton.icon(
                                onPressed: () => _showCreateExpenseDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Expense'),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(AppTheme.spacingMD),
                            itemCount: _expenses.length,
                            itemBuilder: (context, index) {
                              final expense = _expenses[index];
                              final child = _getMember(expense.childId);
                              final paidBy = _getMember(expense.paidBy);
                              final isPending = expense.status == ExpenseStatus.pending;
                              final isApproved = expense.status == ExpenseStatus.approved;
                              final currentUserId = _authService.currentUser?.uid;
                              final canApprove = isPending && currentUserId != null && currentUserId != expense.paidBy;
                              final amountOwed = expense.amount * (expense.splitRatio / 100);

                              return Card(
                                margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                                child: Padding(
                                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  expense.description,
                                                  style: Theme.of(context).textTheme.titleMedium,
                                                ),
                                                Text(
                                                  expense.category,
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                                if (child != null)
                                                  Text(
                                                    'For: ${child.displayName}',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                Text(
                                                  'Date: ${DateFormat('MMM d, y').format(expense.expenseDate)}',
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '\$${expense.amount.toStringAsFixed(2)}',
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(expense.status).withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  _getStatusLabel(expense.status),
                                                  style: TextStyle(
                                                    color: _getStatusColor(expense.status),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            'Paid by: ${paidBy?.displayName ?? 'Unknown'}',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Split: ${expense.splitRatio.toStringAsFixed(0)}% / ${(100 - expense.splitRatio).toStringAsFixed(0)}%',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      if (currentUserId != expense.paidBy) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'You owe: \$${amountOwed.toStringAsFixed(2)}',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                        ),
                                      ],
                                      if (expense.receiptUrl != null) ...[
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () => _showReceiptImage(expense.receiptUrl!),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.receipt, size: 18),
                                              const SizedBox(width: 4),
                                              Text(
                                                'View Receipt',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: Colors.blue,
                                                      decoration: TextDecoration.underline,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (canApprove) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => _rejectExpense(expense),
                                              icon: const Icon(Icons.close, size: 18),
                                              label: const Text('Reject'),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () => _approveExpense(expense),
                                              icon: const Icon(Icons.check, size: 18),
                                              label: const Text('Approve'),
                                              style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (isApproved && currentUserId == expense.paidBy) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _markAsPaid(expense),
                                            icon: const Icon(Icons.payment, size: 18),
                                            label: const Text('Mark as Paid'),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  void _showCreateExpenseDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditExpenseScreen(
          hubId: widget.hubId,
        ),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _showReceiptImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Receipt'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.network(imageUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
