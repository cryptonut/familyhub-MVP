import 'package:flutter/material.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt; // Temporarily disabled
import '../../core/services/logger_service.dart';
import '../../models/shopping_category.dart';
import '../../models/shopping_item.dart';
import '../../services/shopping_service.dart';
import '../../widgets/toast_notification.dart';

class AddShoppingItemDialog extends StatefulWidget {
  final String listId;
  final List<ShoppingCategory> categories;
  final ShoppingItem? item; // For editing existing items

  const AddShoppingItemDialog({
    super.key,
    required this.listId,
    required this.categories,
    this.item,
  });

  @override
  State<AddShoppingItemDialog> createState() => _AddShoppingItemDialogState();
}

class _AddShoppingItemDialogState extends State<AddShoppingItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final ShoppingService _shoppingService = ShoppingService();
  
  int _quantity = 1;
  String? _selectedUnit;
  ShoppingCategory? _selectedCategory;
  bool _isLoading = false;
  
  // Speech to text - TEMPORARILY DISABLED
  // final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  final List<String> _commonUnits = [
    'pcs',
    'kg',
    'g',
    'L',
    'mL',
    'lb',
    'oz',
    'pack',
    'box',
    'bag',
    'can',
    'bottle',
    'bunch',
    'dozen',
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    
    // If editing, populate fields with existing item data
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _notesController.text = widget.item!.notes ?? '';
      _quantity = widget.item!.quantity;
      _selectedUnit = widget.item!.unit;
      _selectedCategory = widget.categories.firstWhere(
        (c) => c.id == widget.item!.categoryId || c.name == widget.item!.categoryName,
        orElse: () => widget.categories.firstWhere(
          (c) => c.id == 'other',
          orElse: () => widget.categories.first,
        ),
      );
    } else {
      // Set default category for new items
      if (widget.categories.isNotEmpty) {
        _selectedCategory = widget.categories.firstWhere(
          (c) => c.id == 'other',
          orElse: () => widget.categories.first,
        );
      }
    }
  }

  Future<void> _initSpeech() async {
    // _speechAvailable = await _speech.initialize();
    _speechAvailable = false; // Disabled
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    // _speech.cancel();
    super.dispose();
  }

  void _onNameChanged() {
    // Auto-suggest category based on name
    if (_nameController.text.isNotEmpty) {
      final suggestedId = _shoppingService.suggestCategory(_nameController.text);
      if (suggestedId != null) {
        final suggested = widget.categories.firstWhere(
          (c) => c.id == suggestedId,
          orElse: () => _selectedCategory ?? widget.categories.first,
        );
        if (suggested.id != _selectedCategory?.id) {
          setState(() => _selectedCategory = suggested);
        }
      }
    }
  }

  Future<void> _startListening() async {
    // DISABLED
    if (mounted) {
      ToastNotification.warning(context, 'Speech recognition temporarily disabled');
    }
    return;
    /* DISABLED
    if (!_speechAvailable) {
      if (mounted) {
        ToastNotification.warning(context, 'Speech recognition not available');
      }
      return;
    }

    setState(() => _isListening = true);
    
    await _speech.listen(
      onResult: (result) {
        _nameController.text = result.recognizedWords;
        if (result.finalResult) {
          setState(() => _isListening = false);
          _onNameChanged();
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
    );
    */ // END DISABLED
  }

  void _stopListening() {
    // _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.item != null) {
        // Update existing item
        final updatedItem = widget.item!.copyWith(
          name: _nameController.text.trim(),
          quantity: _quantity,
          unit: _selectedUnit,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          categoryId: _selectedCategory?.id,
          categoryName: _selectedCategory?.name ?? 'Other',
          updatedAt: DateTime.now(),
        );
        await _shoppingService.updateShoppingItem(updatedItem);
      } else {
        // Add new item
        final addedItem = await _shoppingService.addShoppingItem(
          listId: widget.listId,
          name: _nameController.text.trim(),
          quantity: _quantity,
          unit: _selectedUnit,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          categoryId: _selectedCategory?.id,
          categoryName: _selectedCategory?.name ?? 'Other',
        );

        if (mounted) {
          Navigator.pop(context, addedItem);
          return;
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      Logger.error('Error ${widget.item != null ? 'updating' : 'adding'} item', error: e, tag: 'AddShoppingItemDialog');
      if (mounted) {
        ToastNotification.error(context, 'Error ${widget.item != null ? 'updating' : 'adding'} item: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.item != null ? 'Edit Item' : 'Add Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field with voice input
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'e.g., Milk',
                        prefixIcon: const Icon(Icons.shopping_basket),
                        suffixIcon: _speechAvailable
                            ? IconButton(
                                icon: Icon(
                                  _isListening ? Icons.mic : Icons.mic_none,
                                  color: _isListening ? Colors.red : null,
                                ),
                                onPressed: _isListening
                                    ? _stopListening
                                    : _startListening,
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter item name';
                        }
                        return null;
                      },
                      onChanged: (_) => _onNameChanged(),
                      autofocus: true,
                    ),
                  ),
                ],
              ),
              if (_isListening)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Listening...',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Quantity and unit
              Row(
                children: [
                  // Quantity
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quantity',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            IconButton.outlined(
                              icon: const Icon(Icons.remove),
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '$_quantity',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              icon: const Icon(Icons.add),
                              onPressed: () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Unit
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit (optional)',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._commonUnits.map((unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedUnit = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<ShoppingCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: widget.categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Text(category.icon ?? '📦'),
                        const SizedBox(width: 8),
                        Text(category.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g., Low fat, brand preference...',
                  prefixIcon: Icon(Icons.notes),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _save,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(widget.item != null ? Icons.save : Icons.add),
          label: Text(widget.item != null ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
