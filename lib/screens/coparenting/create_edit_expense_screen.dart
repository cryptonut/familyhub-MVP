import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../models/user_model.dart';
import '../../models/coparenting_expense.dart';
import '../../services/coparenting_service.dart';
import '../../services/auth_service.dart';
import '../../services/hub_service.dart';
import '../../utils/app_theme.dart';
import '../../core/services/logger_service.dart';

/// Screen for creating or editing a co-parenting expense
class CreateEditExpenseScreen extends StatefulWidget {
  final String hubId;
  final CoparentingExpense? expense;

  const CreateEditExpenseScreen({
    super.key,
    required this.hubId,
    this.expense,
  });

  @override
  State<CreateEditExpenseScreen> createState() => _CreateEditExpenseScreenState();
}

class _CreateEditExpenseScreenState extends State<CreateEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final CoparentingService _service = CoparentingService();
  final HubService _hubService = HubService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  
  List<UserModel> _members = [];
  String? _selectedChildId;
  String _selectedCategory = 'Medical';
  DateTime? _expenseDate;
  double _splitRatio = 50.0;
  File? _selectedReceipt;
  String? _receiptUrl;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingReceipt = false;

  final List<String> _categories = [
    'Medical',
    'Education',
    'Activities',
    'Clothing',
    'Food',
    'Transportation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _descriptionController.text = widget.expense!.description;
      _amountController.text = widget.expense!.amount.toStringAsFixed(2);
      _selectedChildId = widget.expense!.childId;
      _selectedCategory = widget.expense!.category;
      _expenseDate = widget.expense!.expenseDate;
      _splitRatio = widget.expense!.splitRatio;
      _receiptUrl = widget.expense!.receiptUrl;
    } else {
      _expenseDate = DateTime.now();
    }
    _loadData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hub = await _hubService.getHub(widget.hubId);
      final members = <UserModel>[];
      if (hub != null) {
        for (final memberId in hub.memberIds) {
          final user = await _authService.getUserModel(memberId);
          if (user != null) {
            members.add(user);
          }
        }
      }

      if (mounted) {
        setState(() {
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
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _selectExpenseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _expenseDate = picked;
      });
    }
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedReceipt = File(pickedFile.path);
          _receiptUrl = null; // Clear existing URL if new image selected
        });
      }
    } catch (e) {
      Logger.error('Error picking receipt image', error: e, tag: 'CreateEditExpenseScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadReceipt() async {
    if (_selectedReceipt == null) {
      return _receiptUrl; // Return existing URL if no new image
    }

    setState(() {
      _isUploadingReceipt = true;
    });

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final expenseId = widget.expense?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final fileName = 'expense_receipts/${widget.hubId}/$expenseId.jpg';
      
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(
        _selectedReceipt!,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'hubId': widget.hubId,
          },
        ),
      );

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _isUploadingReceipt = false;
          _receiptUrl = downloadUrl;
        });
      }

      return downloadUrl;
    } catch (e) {
      Logger.error('Error uploading receipt', error: e, tag: 'CreateEditExpenseScreen');
      if (mounted) {
        setState(() {
          _isUploadingReceipt = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a child'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload receipt if new one selected
      String? finalReceiptUrl = _receiptUrl;
      if (_selectedReceipt != null) {
        finalReceiptUrl = await _uploadReceipt();
      }

      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      if (widget.expense == null) {
        await _service.createExpense(
          hubId: widget.hubId,
          childId: _selectedChildId!,
          category: _selectedCategory,
          description: _descriptionController.text.trim(),
          amount: amount,
          paidBy: currentUserId,
          splitRatio: _splitRatio,
          receiptUrl: finalReceiptUrl,
          expenseDate: _expenseDate ?? DateTime.now(),
        );
      } else {
        // For editing, we'd need an update method in the service
        // For now, we'll show a message that editing isn't fully supported yet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Editing expenses is not yet supported. Please delete and recreate.'),
            backgroundColor: Colors.orange,
          ),
        );
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
        return;
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Child selection
                    DropdownButtonFormField<String>(
                      value: _selectedChildId,
                      decoration: const InputDecoration(
                        labelText: 'Child *',
                        border: OutlineInputBorder(),
                        helperText: 'Select the child for this expense',
                      ),
                      items: _members.map((member) {
                        return DropdownMenuItem(
                          value: member.uid,
                          child: Text(member.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedChildId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a child';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        border: OutlineInputBorder(),
                        helperText: 'What is this expense for?',
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

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount *',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                        helperText: 'Enter the expense amount',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an amount';
                        }
                        final amount = double.tryParse(value.trim());
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Expense date
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Expense Date *',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _expenseDate != null
                                  ? DateFormat('MMM d, y').format(_expenseDate!)
                                  : 'Select date',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _selectExpenseDate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Split ratio
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Split Ratio: ${_splitRatio.toStringAsFixed(0)}% / ${(100 - _splitRatio).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Slider(
                          value: _splitRatio,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '${_splitRatio.toStringAsFixed(0)}%',
                          onChanged: (value) {
                            setState(() {
                              _splitRatio = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Receipt section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Receipt (optional)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            if (_selectedReceipt != null || _receiptUrl != null) ...[
                              if (_selectedReceipt != null)
                                Image.file(
                                  _selectedReceipt!,
                                  height: 200,
                                  fit: BoxFit.contain,
                                )
                              else if (_receiptUrl != null)
                                Image.network(
                                  _receiptUrl!,
                                  height: 200,
                                  fit: BoxFit.contain,
                                ),
                              const SizedBox(height: AppTheme.spacingMD),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: _isUploadingReceipt
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedReceipt = null;
                                              _receiptUrl = null;
                                            });
                                          },
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Remove'),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (!kIsWeb)
                                    ElevatedButton.icon(
                                      onPressed: _isUploadingReceipt
                                          ? null
                                          : () => _pickReceipt(ImageSource.camera),
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Camera'),
                                    ),
                                  ElevatedButton.icon(
                                    onPressed: _isUploadingReceipt
                                        ? null
                                        : () => _pickReceipt(ImageSource.gallery),
                                    icon: const Icon(Icons.photo_library),
                                    label: Text(kIsWeb ? 'Choose File' : 'Gallery'),
                                  ),
                                ],
                              ),
                            ],
                            if (_isUploadingReceipt) ...[
                              const SizedBox(height: AppTheme.spacingMD),
                              const Center(child: CircularProgressIndicator()),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: (_isSaving || _isUploadingReceipt) ? null : _saveExpense,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.expense == null ? 'Add Expense' : 'Update Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }
}

