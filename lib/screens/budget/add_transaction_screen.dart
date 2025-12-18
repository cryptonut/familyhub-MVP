import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/services/logger_service.dart';
import '../../services/budget_transaction_service.dart';
import '../../services/budget_category_service.dart';
import '../../models/budget_transaction.dart';
import '../../models/budget_category.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../utils/firestore_path_utils.dart';
import '../../services/auth_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final String budgetId;
  final TransactionType? initialType;
  final String? initialCategoryId;

  const AddTransactionScreen({
    super.key,
    required this.budgetId,
    this.initialType,
    this.initialCategoryId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final BudgetTransactionService _transactionService = BudgetTransactionService();
  final BudgetCategoryService _categoryService = BudgetCategoryService();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  BudgetCategory? _selectedCategory;
  List<BudgetCategory> _categories = [];
  DateTime _selectedDate = DateTime.now();
  File? _receiptImage;
  bool _isSubmitting = false;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _categoryService.getCategories(budgetId: widget.budgetId);
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
          if (widget.initialCategoryId != null) {
            _selectedCategory = categories.firstWhere(
              (c) => c.id == widget.initialCategoryId,
              orElse: () => categories.first,
            );
          }
        });
      }
    } catch (e) {
      Logger.error('Error loading categories', error: e, tag: 'AddTransactionScreen');
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickReceiptImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() => _receiptImage = File(pickedFile.path));
    }
  }

  Future<String?> _uploadReceiptImage() async {
    if (_receiptImage == null) return null;

    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel?.familyId == null) return null;

      final familyId = userModel!.familyId!;
      final receiptId = DateTime.now().millisecondsSinceEpoch.toString();
      final storagePath = 'budget_receipts/$familyId/${widget.budgetId}/$receiptId.jpg';
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      
      await ref.putFile(_receiptImage!);
      final url = await ref.getDownloadURL();
      
      return url;
    } catch (e) {
      Logger.error('Error uploading receipt', error: e, tag: 'AddTransactionScreen');
      return null;
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        throw Exception('Invalid amount');
      }

      String? receiptUrl;
      String? receiptId;
      if (_receiptImage != null) {
        receiptUrl = await _uploadReceiptImage();
        receiptId = DateTime.now().millisecondsSinceEpoch.toString();
      }

      await _transactionService.createTransaction(
        budgetId: widget.budgetId,
        itemId: widget.budgetId, // Using budgetId as itemId - transactions must be linked to a budget item
        categoryId: _selectedCategory?.id,
        type: _selectedType,
        amount: amount,
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        receiptUrl: receiptUrl,
        receiptId: receiptId,
        source: 'manual',
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction added successfully!')),
        );
      }
    } catch (e) {
      Logger.error('Error creating transaction', error: e, tag: 'AddTransactionScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding transaction: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<TransactionType> newSelection) {
                setState(() => _selectedType = newSelection.first);
              },
            ),
            const SizedBox(height: AppTheme.spacingMD),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
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
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What is this transaction for?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMD),
            if (_isLoadingCategories)
              const Center(child: CircularProgressIndicator())
            else if (_categories.isNotEmpty)
              DropdownButtonFormField<BudgetCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<BudgetCategory>(
                    value: null,
                    child: Text('No Category'),
                  ),
                  ..._categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          if (category.icon != null) ...[
                            Text(category.icon!),
                            const SizedBox(width: AppTheme.spacingXS),
                          ],
                          Text(category.name),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
            const SizedBox(height: AppTheme.spacingMD),
            ListTile(
              title: const Text('Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            if (_receiptImage != null)
              Card(
                child: Column(
                  children: [
                    Image.file(_receiptImage!, height: 200),
                    TextButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Remove Receipt'),
                      onPressed: () {
                        setState(() => _receiptImage = null);
                      },
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Add Receipt Photo'),
                onPressed: _pickReceiptImage,
              ),
            const SizedBox(height: AppTheme.spacingLG),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitTransaction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

