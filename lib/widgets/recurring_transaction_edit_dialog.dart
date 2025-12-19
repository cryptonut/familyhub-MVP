import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../models/budget_item.dart';
import '../models/budget_transaction.dart';
import '../services/recurring_transaction_service.dart';
import '../services/budget_item_service.dart';
import '../utils/app_theme.dart';

/// Dialog for creating or editing a recurring transaction
class RecurringTransactionEditDialog extends StatefulWidget {
  final RecurringTransaction? recurring; // null for new transaction
  final String budgetId;

  const RecurringTransactionEditDialog({
    super.key,
    this.recurring,
    required this.budgetId,
  });

  @override
  State<RecurringTransactionEditDialog> createState() => _RecurringTransactionEditDialogState();
}

class _RecurringTransactionEditDialogState extends State<RecurringTransactionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final RecurringTransactionService _recurringService = RecurringTransactionService();
  final BudgetItemService _itemService = BudgetItemService();
  
  List<BudgetItem> _budgetItems = [];
  BudgetItem? _selectedItem;
  TransactionType _selectedType = TransactionType.expense;
  RecurringFrequency _selectedFrequency = RecurringFrequency.monthly;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _hasEndDate = false;
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBudgetItems();
    if (widget.recurring != null) {
      _descriptionController.text = widget.recurring!.description;
      _amountController.text = widget.recurring!.amount.toStringAsFixed(2);
      _selectedType = widget.recurring!.type;
      _selectedFrequency = widget.recurring!.frequency;
      _startDate = widget.recurring!.startDate;
      _endDate = widget.recurring!.endDate;
      _hasEndDate = _endDate != null;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBudgetItems() async {
    try {
      final items = await _itemService.getItems(widget.budgetId);
      if (mounted) {
        setState(() {
          _budgetItems = items;
          _isLoading = false;
          // If editing, find the selected item
          if (widget.recurring != null) {
            try {
              _selectedItem = items.firstWhere(
                (item) => item.id == widget.recurring!.itemId,
              );
            } catch (e) {
              // Item not found, use first item if available
              _selectedItem = items.isNotEmpty ? items.first : null;
            }
          } else if (items.isNotEmpty) {
            _selectedItem = items.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading budget items: $e')),
        );
      }
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a budget item')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text);
      if (amount <= 0) {
        throw Exception('Amount must be greater than zero');
      }

      if (widget.recurring != null) {
        // Update existing recurring transaction
        await _recurringService.updateRecurringTransaction(
          budgetId: widget.budgetId,
          recurringId: widget.recurring!.id,
          itemId: _selectedItem!.id,
          type: _selectedType,
          amount: amount,
          description: _descriptionController.text.trim(),
          frequency: _selectedFrequency,
          startDate: _startDate,
          endDate: _hasEndDate ? _endDate : null,
        );
      } else {
        // Create new recurring transaction
        await _recurringService.createRecurringTransaction(
          budgetId: widget.budgetId,
          itemId: _selectedItem!.id,
          type: _selectedType,
          amount: amount,
          description: _descriptionController.text.trim(),
          frequency: _selectedFrequency,
          startDate: _startDate,
          endDate: _hasEndDate ? _endDate : null,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving recurring transaction: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.recurring != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Recurring Transaction' : 'Add Recurring Transaction'),
      content: SingleChildScrollView(
        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Budget Item Selection
                    DropdownButtonFormField<BudgetItem>(
                      value: _selectedItem,
                      decoration: const InputDecoration(
                        labelText: 'Budget Item *',
                        border: OutlineInputBorder(),
                      ),
                      items: _budgetItems.map((item) {
                        return DropdownMenuItem<BudgetItem>(
                          value: item,
                          child: Text(item.name),
                        );
                      }).toList(),
                      onChanged: (item) {
                        setState(() => _selectedItem = item);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a budget item';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // Transaction Type
                    DropdownButtonFormField<TransactionType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type *',
                        border: OutlineInputBorder(),
                      ),
                      items: TransactionType.values.map((type) {
                        return DropdownMenuItem<TransactionType>(
                          value: type,
                          child: Text(type.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (type) {
                        setState(() => _selectedType = type!);
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        hintText: 'e.g., Monthly Rent, Weekly Groceries',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // Amount
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount *',
                        hintText: '0.00',
                        prefixText: '\$',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount greater than zero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // Frequency
                    DropdownButtonFormField<RecurringFrequency>(
                      value: _selectedFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency *',
                        border: OutlineInputBorder(),
                      ),
                      items: RecurringFrequency.values.map((freq) {
                        return DropdownMenuItem<RecurringFrequency>(
                          value: freq,
                          child: Text(_getFrequencyLabel(freq)),
                        );
                      }).toList(),
                      onChanged: (freq) {
                        setState(() => _selectedFrequency = freq!);
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // Start Date
                    InkWell(
                      onTap: _selectStartDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date *',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('MMM d, y').format(_startDate)),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // End Date (optional)
                    CheckboxListTile(
                      title: const Text('Set End Date'),
                      value: _hasEndDate,
                      onChanged: (value) {
                        setState(() {
                          _hasEndDate = value ?? false;
                          if (!_hasEndDate) {
                            _endDate = null;
                          } else if (_endDate == null) {
                            _endDate = _startDate.add(const Duration(days: 365));
                          }
                        });
                      },
                    ),
                    if (_hasEndDate) ...[
                      const SizedBox(height: AppTheme.spacingSM),
                      InkWell(
                        onTap: _selectEndDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_endDate != null
                                  ? DateFormat('MMM d, y').format(_endDate!)
                                  : 'Select date'),
                              const Icon(Icons.calendar_today, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
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
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  String _getFrequencyLabel(RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.biweekly:
        return 'Bi-weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.quarterly:
        return 'Quarterly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }
}

