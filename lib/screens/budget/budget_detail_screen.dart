import 'package:flutter/material.dart';
import '../../models/budget.dart';
import '../../models/budget_item.dart';
import '../../services/budget_item_service.dart';
import '../../services/budget_analytics_service.dart';
import '../../services/subscription_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/budget_item_list.dart';
import '../../widgets/budget_item_completion_dialog.dart';
import '../../widgets/budget_item_edit_dialog.dart';
import '../../widgets/premium_feature_gate.dart';
import 'package:intl/intl.dart';

/// Budget detail screen with items, progress, and adherence
class BudgetDetailScreen extends StatefulWidget {
  final Budget budget;

  const BudgetDetailScreen({
    super.key,
    required this.budget,
  });

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  final BudgetItemService _itemService = BudgetItemService();
  final BudgetAnalyticsService _analyticsService = BudgetAnalyticsService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  List<BudgetItem> _items = [];
  BudgetProgressMetrics? _progressMetrics;
  bool _isLoading = true;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _loadData();
  }

  Future<void> _checkPremiumStatus() async {
    final hasPremium = await _subscriptionService.hasActiveSubscription();
    setState(() => _isPremium = hasPremium);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _itemService.getItems(widget.budget.id);
      print('DEBUG: Loaded ${items.length} items for budget ${widget.budget.id}');
      for (var item in items) {
        print('DEBUG: Item ${item.id}: ${item.name}, parentItemId: ${item.parentItemId}');
      }
      
      final progressMetrics = await _analyticsService.getProgressMetrics(
        budget: widget.budget,
        isPremium: _isPremium,
      );
      
      if (mounted) {
        setState(() {
          _items = items;
          _progressMetrics = progressMetrics;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('ERROR loading items: $e');
      print('STACK: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _handleItemTap(BudgetItem item) async {
    // If it's a new item placeholder, show add dialog
    if (item.id == 'new') {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => BudgetItemEditDialog(
          budgetId: widget.budget.id,
        ),
      );
      
      if (result == true) {
        _loadData();
      }
      return;
    }
    
    // For existing items, show edit dialog if not complete, or completion dialog if complete
    if (item.status == BudgetItemStatus.complete) {
      // Show read-only details or allow reopening
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estimated: \$${item.estimatedAmount.toStringAsFixed(2)}'),
              if (item.actualAmount != null)
                Text('Actual: \$${item.actualAmount!.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              Text('Status: ${item.status.name}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Show edit dialog
                showDialog<bool>(
                  context: context,
                  builder: (context) => BudgetItemEditDialog(
                    item: item,
                    budgetId: widget.budget.id,
                  ),
                ).then((result) {
                  if (result == true) _loadData();
                });
              },
              child: const Text('Edit'),
            ),
          ],
        ),
      );
    } else {
      // Show edit dialog for incomplete items
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => BudgetItemEditDialog(
          item: item,
          budgetId: widget.budget.id,
        ),
      );
      
      if (result == true) {
        _loadData();
      }
    }
  }

  Future<void> _handleItemComplete(BudgetItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BudgetItemCompletionDialog(
        item: item,
        budgetId: widget.budget.id,
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _handleReorder(String budgetId, List<String> itemIds) async {
    try {
      await _itemService.reorderItems(budgetId, itemIds);
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reordering items: $e')),
      );
    }
  }

  Future<void> _handleItemDelete(BudgetItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete "${item.name}"? This action cannot be undone.'),
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
        await _itemService.deleteItem(widget.budget.id, item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting item: $e')),
          );
        }
      }
    }
  }

  Color _getAdherenceColor(BudgetAdherenceStatus status) {
    switch (status) {
      case BudgetAdherenceStatus.onTrack:
        return Colors.green;
      case BudgetAdherenceStatus.warning:
        return Colors.orange;
      case BudgetAdherenceStatus.overBudget:
        return Colors.red;
    }
  }

  void _showAdherenceWarningDialog() {
    if (_progressMetrics == null) return;
    
    final totalEstimated = _progressMetrics!.totalEstimated;
    final budgetTotal = widget.budget.totalAmount;
    final exceedsBy = totalEstimated - budgetTotal;
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Budget Warning'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (totalEstimated > budgetTotal) ...[
              Text(
                'The total estimated amount of all budget items (${currencyFormat.format(totalEstimated)}) exceeds your budget total (${currencyFormat.format(budgetTotal)}).',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'You are over budget by: ${currencyFormat.format(exceedsBy)}',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'To resolve this, you can:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Adjust item estimates to reduce total'),
              const Text('• Increase your budget total'),
              const Text('• Remove or modify budget items'),
            ] else ...[
              Text(
                'Your actual spending is approaching or exceeding your estimated amounts.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Consider reviewing your budget items and spending.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.budget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _handleItemTap(BudgetItem(
              id: 'new',
              budgetId: widget.budget.id,
              name: '',
              estimatedAmount: 0,
              createdBy: '',
              createdAt: DateTime.now(),
            )),
            tooltip: 'Add Item',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Budget Overview Card
                    ModernCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Budget Overview',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Budget:',
                                style: theme.textTheme.bodyLarge,
                              ),
                              Text(
                                currencyFormat.format(widget.budget.totalAmount),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          if (_progressMetrics != null) ...[
                            const SizedBox(height: AppTheme.spacingSM),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Actual Spending:',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Text(
                                  currencyFormat.format(_progressMetrics!.totalActual),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getAdherenceColor(_progressMetrics!.budgetAdherence),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Progress Metrics Card
                    if (_progressMetrics != null) ...[
                      ModernCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progress',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingSM),
                            
                            // Item Progress (Free & Premium)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Items:',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Text(
                                  '${_progressMetrics!.completedItems}/${_progressMetrics!.totalItems} (${_progressMetrics!.itemProgress.toStringAsFixed(1)}%)',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingXS),
                            LinearProgressIndicator(
                              value: _progressMetrics!.itemProgress / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor,
                              ),
                            ),
                            
                            // Dollar Progress (Premium only)
                            if (_isPremium) ...[
                              const SizedBox(height: AppTheme.spacingSM),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Dollars:',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  Text(
                                    '${_progressMetrics!.dollarProgress.toStringAsFixed(1)}%',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingXS),
                              LinearProgressIndicator(
                                value: _progressMetrics!.dollarProgress / 100,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getAdherenceColor(_progressMetrics!.budgetAdherence),
                                ),
                              ),
                            ] else
                              PremiumFeatureGate(
                                featureName: 'Dollar Progress Tracking',
                                child: const SizedBox.shrink(),
                              ),
                            
                            // Budget Adherence Indicator (clickable if warning/over budget)
                            const SizedBox(height: AppTheme.spacingSM),
                            InkWell(
                              onTap: _progressMetrics!.budgetAdherence != BudgetAdherenceStatus.onTrack
                                  ? () => _showAdherenceWarningDialog()
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(AppTheme.spacingSM),
                                decoration: BoxDecoration(
                                  color: _getAdherenceColor(_progressMetrics!.budgetAdherence).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getAdherenceColor(_progressMetrics!.budgetAdherence).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _progressMetrics!.budgetAdherence == BudgetAdherenceStatus.onTrack
                                          ? Icons.check_circle
                                          : _progressMetrics!.budgetAdherence == BudgetAdherenceStatus.warning
                                              ? Icons.warning
                                              : Icons.error,
                                      color: _getAdherenceColor(_progressMetrics!.budgetAdherence),
                                    ),
                                    const SizedBox(width: AppTheme.spacingSM),
                                    Expanded(
                                      child: Text(
                                        _progressMetrics!.budgetAdherence == BudgetAdherenceStatus.onTrack
                                            ? 'On Track'
                                            : _progressMetrics!.budgetAdherence == BudgetAdherenceStatus.warning
                                                ? 'Warning'
                                                : 'Over Budget',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: _getAdherenceColor(_progressMetrics!.budgetAdherence),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (_progressMetrics!.budgetAdherence != BudgetAdherenceStatus.onTrack)
                                      Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: _getAdherenceColor(_progressMetrics!.budgetAdherence),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                    ],

                    // Budget Items Section
                    Text(
                      'Budget Items',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    SizedBox(
                      height: 400, // Fixed height for ReorderableListView
                      child: BudgetItemList(
                        items: _items,
                        onItemTap: _handleItemTap,
                        onItemComplete: _handleItemComplete,
                        onItemDelete: _handleItemDelete,
                        onReorder: _handleReorder,
                        budgetId: widget.budget.id,
                        isPremium: _isPremium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
