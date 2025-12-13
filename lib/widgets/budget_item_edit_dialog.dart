import 'package:flutter/material.dart';
import '../models/budget_item.dart';
import '../services/budget_item_service.dart';
import '../utils/app_theme.dart';

/// Dialog for creating or editing a budget item
class BudgetItemEditDialog extends StatefulWidget {
  final BudgetItem? item; // null for new item
  final String budgetId;
  final String? parentItemId; // For sub-items

  const BudgetItemEditDialog({
    super.key,
    this.item,
    required this.budgetId,
    this.parentItemId,
  });

  @override
  State<BudgetItemEditDialog> createState() => _BudgetItemEditDialogState();
}

class _BudgetItemEditDialogState extends State<BudgetItemEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _thresholdController = TextEditingController();
  final BudgetItemService _itemService = BudgetItemService();
  
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _descriptionController.text = widget.item!.description;
      _amountController.text = widget.item!.estimatedAmount.toStringAsFixed(2);
      _thresholdController.text = widget.item!.adherenceThreshold.toStringAsFixed(1);
    } else {
      _thresholdController.text = '5.0'; // Default threshold
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final estimatedAmount = double.parse(_amountController.text);
      final threshold = double.tryParse(_thresholdController.text) ?? 5.0;

      if (estimatedAmount <= 0) {
        throw Exception('Estimated amount must be greater than zero');
      }

      if (widget.item != null) {
        // Update existing item
        final updatedItem = widget.item!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          estimatedAmount: estimatedAmount,
          adherenceThreshold: threshold,
          updatedAt: DateTime.now(),
        );
        await _itemService.updateItem(widget.budgetId, updatedItem);
      } else {
        // Create new item
        await _itemService.createItem(
          budgetId: widget.budgetId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          estimatedAmount: estimatedAmount,
          parentItemId: widget.parentItemId,
          adherenceThreshold: threshold,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.item != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Item' : 'Add Budget Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g., Airfare, Accommodation',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Estimated Amount *',
                  hintText: '0.00',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an estimated amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _thresholdController,
                decoration: const InputDecoration(
                  labelText: 'Adherence Threshold (%)',
                  hintText: '5.0',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                  helperText: 'Warning threshold for going over budget',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final threshold = double.tryParse(value);
                    if (threshold != null && threshold < 0) {
                      return 'Threshold must be 0 or greater';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Update' : 'Add Item'),
        ),
      ],
    );
  }
}

