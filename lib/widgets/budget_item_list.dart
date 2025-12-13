import 'package:flutter/material.dart';
import '../models/budget_item.dart';
import '../utils/app_theme.dart';
import 'ui_components.dart';

/// Widget for displaying a list of budget items with drag-to-reorder
class BudgetItemList extends StatefulWidget {
  final List<BudgetItem> items;
  final Function(BudgetItem) onItemTap;
  final Function(BudgetItem) onItemComplete;
  final Function(BudgetItem) onItemDelete;
  final Function(String, List<String>) onReorder; // budgetId, List<itemId>
  final String budgetId;
  final bool isPremium;

  const BudgetItemList({
    super.key,
    required this.items,
    required this.onItemTap,
    required this.onItemComplete,
    required this.onItemDelete,
    required this.onReorder,
    required this.budgetId,
    this.isPremium = false,
  });

  @override
  State<BudgetItemList> createState() => _BudgetItemListState();
}

class _BudgetItemListState extends State<BudgetItemList> {
  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: EmptyState(
          icon: Icons.list_alt,
          title: 'No budget items yet',
          message: 'Add items to break down your budget into manageable pieces',
          action: ElevatedButton.icon(
            onPressed: () => widget.onItemTap(BudgetItem(
              id: 'new',
              budgetId: widget.budgetId,
              name: '',
              estimatedAmount: 0,
              createdBy: '',
              createdAt: DateTime.now(),
            )),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: widget.items.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final reorderedItems = List<BudgetItem>.from(widget.items);
        final item = reorderedItems.removeAt(oldIndex);
        reorderedItems.insert(newIndex, item);
        final itemIds = reorderedItems.map((i) => i.id).toList();
        widget.onReorder(widget.budgetId, itemIds);
      },
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return _BudgetItemTile(
          key: ValueKey(item.id),
          item: item,
          onTap: () => widget.onItemTap(item),
          onComplete: () => widget.onItemComplete(item),
          onDelete: () => widget.onItemDelete(item),
          isPremium: widget.isPremium,
        );
      },
    );
  }
}

/// Individual budget item tile
class _BudgetItemTile extends StatelessWidget {
  final BudgetItem item;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final bool isPremium;

  const _BudgetItemTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onComplete,
    required this.onDelete,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adherenceStatus = item.adherenceStatus;
    final isComplete = item.status == BudgetItemStatus.complete;

    // Color based on adherence status
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (adherenceStatus) {
      case BudgetAdherenceStatus.onTrack:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'On Track';
        break;
      case BudgetAdherenceStatus.warning:
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        statusText = 'Warning';
        break;
      case BudgetAdherenceStatus.overBudget:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Over Budget';
        break;
    }

    // If not complete, show pending status
    if (!isComplete) {
      statusColor = Colors.grey;
      statusIcon = Icons.pending;
      statusText = 'Pending';
    }

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: ListTile(
        leading: Icon(
          Icons.drag_handle,
          color: theme.colorScheme.onSurface.withOpacity(0.3),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: isComplete ? TextDecoration.lineThrough : null,
            color: isComplete ? theme.colorScheme.onSurface.withOpacity(0.6) : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.description.isNotEmpty)
              Text(
                item.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Est: \$${item.estimatedAmount.toStringAsFixed(2)}',
                  style: theme.textTheme.bodySmall,
                ),
                if (item.actualAmount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Actual: \$${item.actualAmount!.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item.adherencePercentage != 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${item.adherencePercentage > 0 ? '+' : ''}${item.adherencePercentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: adherenceStatus == BudgetAdherenceStatus.onTrack
                            ? Colors.green
                            : adherenceStatus == BudgetAdherenceStatus.warning
                                ? Colors.orange
                                : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (!isComplete) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: onComplete,
                tooltip: 'Mark Complete',
                color: theme.colorScheme.primary,
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Delete Item',
              color: Colors.red,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

