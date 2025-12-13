import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/budget_item.dart';
import '../services/budget_item_service.dart';
import '../utils/app_theme.dart';
import 'package:intl/intl.dart';

/// Dialog for completing a budget item with actual cost and receipt
class BudgetItemCompletionDialog extends StatefulWidget {
  final BudgetItem item;
  final String budgetId;

  const BudgetItemCompletionDialog({
    super.key,
    required this.item,
    required this.budgetId,
  });

  @override
  State<BudgetItemCompletionDialog> createState() => _BudgetItemCompletionDialogState();
}

class _BudgetItemCompletionDialogState extends State<BudgetItemCompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final BudgetItemService _itemService = BudgetItemService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _receiptImage;
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with estimated amount
    _amountController.text = widget.item.estimatedAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _receiptImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadReceipt() async {
    if (_receiptImage == null) return null;

    try {
      setState(() => _isUploading = true);
      
      final receiptId = DateTime.now().millisecondsSinceEpoch.toString();
      final storagePath = 'budget_receipts/${widget.budgetId}/${widget.item.id}/$receiptId.jpg';
      final ref = _storage.ref().child(storagePath);
      
      await ref.putFile(_receiptImage!);
      final receiptUrl = await ref.getDownloadURL();

      setState(() => _isUploading = false);
      return receiptUrl;
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading receipt: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final actualAmount = double.parse(_amountController.text);
      
      if (actualAmount <= 0) {
        throw Exception('Amount must be greater than zero');
      }

      // Upload receipt if provided
      String? receiptUrl;
      String? receiptId;
      if (_receiptImage != null) {
        receiptId = DateTime.now().millisecondsSinceEpoch.toString();
        receiptUrl = await _uploadReceipt();
      }

      // Complete the item
      await _itemService.completeItem(
        budgetId: widget.budgetId,
        itemId: widget.item.id,
        actualAmount: actualAmount,
        receiptUrl: receiptUrl,
        receiptId: receiptId,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing item: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final estimatedAmount = currencyFormat.format(widget.item.estimatedAmount);

    return AlertDialog(
      title: Text('Complete: ${widget.item.name}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estimated amount display
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Estimated Amount:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      estimatedAmount,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // Actual amount input
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Actual Amount',
                  hintText: 'Enter the actual cost',
                  prefixText: '\$',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the actual amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Receipt upload
              Text(
                'Receipt (Optional)',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickReceipt,
                      icon: Icon(_receiptImage != null ? Icons.check : Icons.camera_alt),
                      label: Text(_receiptImage != null ? 'Receipt Added' : 'Take Photo'),
                    ),
                  ),
                  if (_receiptImage != null) ...[
                    const SizedBox(width: AppTheme.spacingS),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _receiptImage = null),
                      tooltip: 'Remove Receipt',
                    ),
                  ],
                ],
              ),
              if (_isUploading)
                const Padding(
                  padding: EdgeInsets.only(top: AppTheme.spacingS),
                  child: LinearProgressIndicator(),
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
          onPressed: _isSubmitting || _isUploading ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Complete Item'),
        ),
      ],
    );
  }
}

