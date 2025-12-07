import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/shopping_service.dart';
import '../../models/shopping_list.dart';
import '../../models/receipt.dart';

class ReceiptUploadScreen extends StatefulWidget {
  final ShoppingList list;

  const ReceiptUploadScreen({super.key, required this.list});

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  final ShoppingService _shoppingService = ShoppingService();
  File? _selectedImage;
  bool _isProcessing = false;
  Receipt? _extractedReceipt;
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final List<ReceiptItem> _items = [];

  @override
  void dispose() {
    _storeController.dispose();
    _dateController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _extractedReceipt = null;
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _extractedReceipt = null;
      });
    }
  }

  Future<void> _processReceipt() async {
    if (_selectedImage == null) return;

    setState(() => _isProcessing = true);

    try {
      // TODO: Implement OCR processing
      // For now, show a placeholder form
      await Future.delayed(const Duration(seconds: 1));

      // Mock extracted data - in real implementation, this would come from OCR
      final mockReceipt = Receipt(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        listId: widget.list.id,
        familyId: widget.list.familyId,
        store: 'Store Name',
        date: DateTime.now(),
        items: [
          ReceiptItem(name: 'Item 1', quantity: 2, price: 5.99),
          ReceiptItem(name: 'Item 2', quantity: 1, price: 3.50),
        ],
        total: 15.48,
        uploadedBy: '', // Will be set when saving
        uploadedAt: DateTime.now(),
      );

      setState(() {
        _extractedReceipt = mockReceipt;
        _storeController.text = mockReceipt.store;
        _dateController.text = mockReceipt.date.toString().split(' ')[0];
        _totalController.text = mockReceipt.total.toStringAsFixed(2);
        _items.clear();
        _items.addAll(mockReceipt.items);
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OCR processing complete. Please review and edit the extracted data.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveReceipt() async {
    if (_storeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a store name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _shoppingService.uploadReceiptImage(
          _selectedImage!,
          widget.list.id,
        );
      }

      final receipt = Receipt(
        id: _extractedReceipt?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        listId: widget.list.id,
        familyId: widget.list.familyId,
        store: _storeController.text.trim(),
        date: _dateController.text.isNotEmpty
            ? DateTime.parse(_dateController.text)
            : DateTime.now(),
        items: _items,
        total: double.tryParse(_totalController.text) ?? 0.0,
        imageUrl: imageUrl,
        uploadedBy: '', // Will be set by service
        uploadedAt: DateTime.now(),
        isEdited: _extractedReceipt != null,
      );

      await _shoppingService.saveReceipt(receipt);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _AddReceiptItemDialog(
        onAdd: (item) {
          setState(() {
            _items.add(item);
            _recalculateTotal();
          });
        },
      ),
    );
  }

  void _editItem(int index) {
    showDialog(
      context: context,
      builder: (context) => _AddReceiptItemDialog(
        existingItem: _items[index],
        onAdd: (item) {
          setState(() {
            _items[index] = item;
            _recalculateTotal();
          });
        },
      ),
    );
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
      _recalculateTotal();
    });
  }

  void _recalculateTotal() {
    final total = _items.fold<double>(
      0.0,
      (sum, item) => sum + item.total,
    );
    _totalController.text = total.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Receipt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image selection
            if (_selectedImage == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long, size: 64),
                      const SizedBox(height: 16),
                      const Text('Select receipt image'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _takePhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Stack(
                children: [
                  Image.file(_selectedImage!, height: 200, fit: BoxFit.cover),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_isProcessing && _extractedReceipt == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _processReceipt,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Extract Receipt Data'),
                  ),
                ),
            ],
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('Processing receipt...')),
            ],
            if (_extractedReceipt != null || _items.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Receipt Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _storeController,
                decoration: const InputDecoration(
                  labelText: 'Store',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  hintText: 'YYYY-MM-DD',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text('Qty: ${item.quantity} × \$${item.price.toStringAsFixed(2)} = \$${item.total.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editItem(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteItem(index),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _totalController,
                decoration: const InputDecoration(
                  labelText: 'Total',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _extractedReceipt != null || _items.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _saveReceipt,
                child: const Text('Save Receipt'),
              ),
            )
          : null,
    );
  }
}

class _AddReceiptItemDialog extends StatefulWidget {
  final ReceiptItem? existingItem;
  final Function(ReceiptItem) onAdd;

  const _AddReceiptItemDialog({
    this.existingItem,
    required this.onAdd,
  });

  @override
  State<_AddReceiptItemDialog> createState() => _AddReceiptItemDialogState();
}

class _AddReceiptItemDialogState extends State<_AddReceiptItemDialog> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _nameController.text = widget.existingItem!.name;
      _quantityController.text = widget.existingItem!.quantity.toString();
      _priceController.text = widget.existingItem!.price.toStringAsFixed(2);
    } else {
      _quantityController.text = '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter item name')),
      );
      return;
    }

    widget.onAdd(ReceiptItem(
      name: name,
      quantity: quantity,
      price: price,
    ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingItem != null ? 'Edit Item' : 'Add Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Item Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(
              labelText: 'Price',
              border: OutlineInputBorder(),
              prefixText: '\$',
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
