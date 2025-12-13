import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import '../../services/budget_service.dart';
import '../../models/budget.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/premium_feature_gate.dart';
import '../../services/subscription_service.dart';
import 'create_budget_screen.dart';
import 'budget_detail_screen.dart';

class BudgetHomeScreen extends StatefulWidget {
  const BudgetHomeScreen({super.key});

  @override
  State<BudgetHomeScreen> createState() => _BudgetHomeScreenState();
}

class _BudgetHomeScreenState extends State<BudgetHomeScreen> {
  final BudgetService _budgetService = BudgetService();
  List<Budget> _budgets = [];
  bool _isLoading = true;
  bool _hasPremiumAccess = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumAccess();
    _loadBudgets();
  }

  Future<void> _checkPremiumAccess() async {
    final subscriptionService = SubscriptionService();
    final hasAccess = await subscriptionService.hasActiveSubscription();
    if (mounted) {
      setState(() {
        _hasPremiumAccess = hasAccess;
      });
    }
  }

  Future<void> _loadBudgets() async {
    setState(() => _isLoading = true);
    try {
      final budgets = await _budgetService.getBudgets(activeOnly: true);
      if (mounted) {
        setState(() {
          _budgets = budgets;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Error loading budgets', error: e, tag: 'BudgetHomeScreen');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading budgets: $e')),
        );
      }
    }
  }

  Future<void> _createBudget() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateBudgetScreen(),
      ),
    );

    if (result == true) {
      _loadBudgets();
    }
  }

  void _navigateToBudgetDetail(Budget budget) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BudgetDetailScreen(budget: budget),
      ),
    ).then((_) => _loadBudgets());
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget?'),
        content: Text(
          'Are you sure you want to delete "${budget.name}"? This will also delete all items and transactions associated with this budget. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _budgetService.deleteBudget(budget.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Budget deleted successfully')),
          );
          _loadBudgets();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting budget: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createBudget,
            tooltip: 'Create Budget',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _budgets.isEmpty
              ? EmptyState(
                  icon: Icons.account_balance_wallet,
                  title: 'No Budgets Yet',
                  message: 'Create your first budget to start tracking your family finances.',
                  action: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create Budget'),
                    onPressed: _createBudget,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBudgets,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    itemCount: _budgets.length,
                    itemBuilder: (context, index) {
                      final budget = _budgets[index];
                      return ModernCard(
                        margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(AppTheme.spacingMD),
                          title: Text(
                            budget.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: AppTheme.spacingXS),
                              Text(
                                budget.description.isNotEmpty
                                    ? budget.description
                                    : '${budget.type.name.toUpperCase()} Budget',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppTheme.spacingXS),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      budget.period.toUpperCase(),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  const SizedBox(width: AppTheme.spacingXS),
                                  if (budget.type == BudgetType.individual)
                                    Chip(
                                      label: const Text(
                                        'INDIVIDUAL',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  if (budget.type == BudgetType.project)
                                    Chip(
                                      label: const Text(
                                        'PROJECT',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${budget.totalAmount.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  Text(
                                    '${budget.startDate.day}/${budget.startDate.month} - ${budget.endDate.day}/${budget.endDate.month}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              PopupMenuButton(
                                icon: const Icon(Icons.more_vert),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete Budget'),
                                      ],
                                    ),
                                    onTap: () {
                                      // Delay to allow popup to close
                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        _deleteBudget(budget);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _navigateToBudgetDetail(budget),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

