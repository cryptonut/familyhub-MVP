import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/logger_service.dart';
import '../../services/budget_service.dart';
import '../../models/budget.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../services/budget_category_service.dart';

class CreateBudgetScreen extends StatefulWidget {
  const CreateBudgetScreen({super.key});

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  final BudgetService _budgetService = BudgetService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  BudgetType _selectedType = BudgetType.family;
  String _selectedPeriod = 'monthly';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _createBudget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isCreating = true);

    try {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        throw Exception('Invalid amount');
      }

      await _budgetService.createBudget(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        totalAmount: amount,
        startDate: _startDate,
        endDate: _endDate,
        period: _selectedPeriod,
      );

      // Initialize default categories
      final budgets = await _budgetService.getBudgets();
      final createdBudget = budgets.firstWhere(
        (b) => b.name == _nameController.text.trim(),
        orElse: () => budgets.first,
      );

      final categoryService = BudgetCategoryService();
      await categoryService.initializeDefaultCategories(createdBudget.id);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget created successfully!')),
        );
      }
    } catch (e) {
      Logger.error('Error creating budget', error: e, tag: 'CreateBudgetScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating budget: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Budget'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Budget Name',
                hintText: 'e.g., Monthly Family Budget',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a budget name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Add a description for this budget',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            DropdownButtonFormField<BudgetType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Budget Type',
                border: OutlineInputBorder(),
              ),
              items: BudgetType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Total Budget Amount',
                hintText: '0.00',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMD),
            DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: const InputDecoration(
                labelText: 'Period',
                border: OutlineInputBorder(),
              ),
              items: ['weekly', 'monthly', 'yearly', 'one-off', 'custom'].map((period) {
                return DropdownMenuItem(
                  value: period,
                  child: Text(period.toUpperCase().replaceAll('-', ' ')),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPeriod = value;
                    // For one-off budgets, set end date same as start date
                    if (value == 'one-off') {
                      _endDate = _startDate;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingMD),
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectStartDate,
            ),
            const SizedBox(height: AppTheme.spacingXS),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_endDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectEndDate,
            ),
            const SizedBox(height: AppTheme.spacingLG),
            ElevatedButton(
              onPressed: _isCreating ? null : _createBudget,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Budget'),
            ),
          ],
        ),
      ),
    );
  }
}

