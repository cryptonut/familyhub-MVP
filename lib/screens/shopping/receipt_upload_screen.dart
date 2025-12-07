import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/services/logger_service.dart';
import '../../models/shopping_receipt.dart';
import '../../services/shopping_service.dart';
import '../../widgets/toast_notification.dart';
import '../../utils/app_theme.dart';

class ReceiptUploadScreen extends StatefulWidget {
  final String? listId;

  const ReceiptUploadScreen({super.key, this.listId});

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  final ShoppingService _shoppingService = ShoppingService();
  final ImagePicker _picker = ImagePicker();
  
  File? _imageFile;
  ShoppingReceipt? _receipt;
  bool _isProcessing = false;
  bool _isUploading = false;
  
  // Editable extracted data
  final _storeNameController = TextEditingController();
  final _totalController = TextEditingController();
  DateTime? _purchaseDate;
  List<ReceiptItem> _extractedItems = [];

  @override
  void dispose() {
    _storeNameController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _receipt = null;
          _extractedItems = [];
        });
        await _processImage();
      }
    } catch (e) {
      Logger.error('Error picking image', error: e, tag: 'ReceiptUploadScreen');
      if (mounted) {
        ToastNotification.error(context, 'Error selecting image');
      }
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    setState(() => _isProcessing = true);

    try {
      // Use ML Kit for text recognition
      final inputImage = InputImage.fromFile(_imageFile!);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      // Parse the recognized text
      _parseReceiptText(recognizedText.text);

      if (mounted) {
        setState(() => _isProcessing = false);
        ToastNotification.success(context, 'Receipt processed! Please verify the data.');
      }
    } catch (e) {
      Logger.error('Error processing receipt', error: e, tag: 'ReceiptUploadScreen');
      if (mounted) {
        setState(() => _isProcessing = false);
        ToastNotification.error(context, 'Error processing receipt: $e');
      }
    }
  }

  void _parseReceiptText(String text) {
    final lines = text.split('\n');
    final items = <ReceiptItem>[];
    String? storeName;
    double? total;
    DateTime? date;

    // Common store name patterns (first few lines)
    if (lines.isNotEmpty) {
      for (var i = 0; i < lines.length && i < 5; i++) {
        final line = lines[i].trim();
        if (line.length > 3 && !_isPrice(line) && !_isDate(line)) {
          storeName = line;
          break;
        }
      }
    }

    // Look for date
    for (var line in lines) {
      final dateMatch = RegExp(r'(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})').firstMatch(line);
      if (dateMatch != null) {
        try {
          final dateStr = dateMatch.group(1)!;
          // Try different date formats
          date = _parseDate(dateStr);
          if (date != null) break;
        } catch (e) {
          // Continue looking
        }
      }
    }

    // Look for items and prices
    final pricePattern = RegExp(r'(\$?\d+\.?\d{0,2})\s*$');
    
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Look for total
      if (trimmed.toLowerCase().contains('total') ||
          trimmed.toLowerCase().contains('amount due')) {
        final match = pricePattern.firstMatch(trimmed);
        if (match != null) {
          total = _parsePrice(match.group(1)!);
          continue;
        }
      }

      // Skip common non-item lines
      if (_shouldSkipLine(trimmed)) continue;

      // Try to extract item and price
      final priceMatch = pricePattern.firstMatch(trimmed);
      if (priceMatch != null) {
        final price = _parsePrice(priceMatch.group(1)!);
        if (price != null && price > 0 && price < 1000) {
          // Reasonable item price
          final itemName = trimmed
              .replaceAll(priceMatch.group(0)!, '')
              .replaceAll(RegExp(r'\d+\s*[xX@]\s*'), '') // Remove quantity prefix
              .trim();
          
          if (itemName.length > 2) {
            // Extract quantity if present
            int quantity = 1;
            final qtyMatch = RegExp(r'^(\d+)\s*[xX@]').firstMatch(trimmed);
            if (qtyMatch != null) {
              quantity = int.tryParse(qtyMatch.group(1)!) ?? 1;
            }

            items.add(ReceiptItem(
              name: _cleanItemName(itemName),
              quantity: quantity,
              price: price,
            ));
          }
        }
      }
    }

    // Update state
    setState(() {
      _storeNameController.text = storeName ?? '';
      _totalController.text = total?.toStringAsFixed(2) ?? '';
      _purchaseDate = date;
      _extractedItems = items;
    });

    Logger.debug('Parsed receipt: store=$storeName, date=$date, total=$total, items=${items.length}',
        tag: 'ReceiptUploadScreen');
  }

  bool _isPrice(String text) {
    return RegExp(r'^\$?\d+\.\d{2}$').hasMatch(text.trim());
  }

  bool _isDate(String text) {
    return RegExp(r'\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}').hasMatch(text);
  }

  DateTime? _parseDate(String dateStr) {
    try {
      // Try common formats
      final formats = [
        RegExp(r'(\d{2})/(\d{2})/(\d{4})'), // DD/MM/YYYY
        RegExp(r'(\d{2})-(\d{2})-(\d{4})'), // DD-MM-YYYY
        RegExp(r'(\d{2})\.(\d{2})\.(\d{4})'), // DD.MM.YYYY
        RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2})'), // D/M/YY
      ];

      for (var format in formats) {
        final match = format.firstMatch(dateStr);
        if (match != null) {
          int day = int.parse(match.group(1)!);
          int month = int.parse(match.group(2)!);
          int year = int.parse(match.group(3)!);
          
          if (year < 100) year += 2000;
          
          // Swap day/month if needed (US format)
          if (month > 12 && day <= 12) {
            final temp = day;
            day = month;
            month = temp;
          }
          
          return DateTime(year, month, day);
        }
      }
    } catch (e) {
      Logger.debug('Could not parse date: $dateStr', tag: 'ReceiptUploadScreen');
    }
    return null;
  }

  double? _parsePrice(String priceStr) {
    try {
      return double.parse(priceStr.replaceAll('\$', '').trim());
    } catch (e) {
      return null;
    }
  }

  bool _shouldSkipLine(String line) {
    final lower = line.toLowerCase();
    final skipPatterns = [
      'subtotal', 'tax', 'gst', 'change', 'cash', 'credit', 'debit',
      'card', 'visa', 'mastercard', 'eftpos', 'thank', 'receipt',
      'abn', 'acn', 'phone', 'tel', 'address', 'www', 'http',
    ];
    return skipPatterns.any((p) => lower.contains(p));
  }

  String _cleanItemName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s\-&]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  Future<void> _saveReceipt() async {
    if (_imageFile == null) {
      ToastNotification.warning(context, 'Please select a receipt image first');
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Upload receipt and image
      final receipt = await _shoppingService.uploadReceipt(
        listId: widget.listId,
        imageFile: _imageFile!,
      );

      // Update with OCR data
      final updatedReceipt = receipt.copyWith(
        storeName: _storeNameController.text.trim().isEmpty
            ? null
            : _storeNameController.text.trim(),
        purchaseDate: _purchaseDate,
        total: double.tryParse(_totalController.text),
        items: _extractedItems,
        isProcessed: true,
        isVerified: true,
      );

      await _shoppingService.updateReceiptWithOcrData(updatedReceipt);

      if (mounted) {
        ToastNotification.success(context, 'Receipt saved successfully!');
        Navigator.pop(context, updatedReceipt);
      }
    } catch (e) {
      Logger.error('Error saving receipt', error: e, tag: 'ReceiptUploadScreen');
      if (mounted) {
        ToastNotification.error(context, 'Error saving receipt: $e');
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Receipt'),
        actions: [
          if (_imageFile != null && !_isProcessing && !_isUploading)
            TextButton.icon(
              onPressed: _saveReceipt,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image selection
            if (_imageFile == null) ...[
              _buildImagePicker(),
            ] else ...[
              _buildImagePreview(),
              const SizedBox(height: AppTheme.spacingM),
              // Processing indicator
              if (_isProcessing) ...[
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Processing receipt...'),
                    ],
                  ),
                ),
              ] else ...[
                // Extracted data form
                _buildExtractedDataForm(),
                const SizedBox(height: AppTheme.spacingM),
                // Extracted items
                _buildExtractedItems(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppTheme.spacingM),
            const Text(
              'Upload a receipt to extract items',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
                const SizedBox(width: AppTheme.spacingM),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            _imageFile!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _imageFile = null;
                      _receipt = null;
                      _extractedItems = [];
                      _storeNameController.clear();
                      _totalController.clear();
                      _purchaseDate = null;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExtractedDataForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Receipt Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            // Store name
            TextField(
              controller: _storeNameController,
              decoration: const InputDecoration(
                labelText: 'Store Name',
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            // Date and total row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _purchaseDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _purchaseDate = date);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _purchaseDate != null
                            ? '${_purchaseDate!.day}/${_purchaseDate!.month}/${_purchaseDate!.year}'
                            : 'Select date',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: TextField(
                    controller: _totalController,
                    decoration: const InputDecoration(
                      labelText: 'Total',
                      prefixIcon: Icon(Icons.attach_money),
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedItems() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Extracted Items (${_extractedItems.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            if (_extractedItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No items extracted',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Text(
                        'Add items manually if needed',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _extractedItems.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _extractedItems[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${item.quantity}',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(item.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editItem(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _removeItem(index),
                        ),
                      ],
                    ),
                    onTap: () => _editItem(index),
                  );
                },
              ),
            if (_extractedItems.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Items Total:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${_extractedItems.fold<double>(0, (sum, item) => sum + item.price).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addItem() async {
    final result = await showDialog<ReceiptItem>(
      context: context,
      builder: (context) => _ItemEditDialog(),
    );

    if (result != null) {
      setState(() {
        _extractedItems.add(result);
      });
    }
  }

  void _editItem(int index) async {
    final result = await showDialog<ReceiptItem>(
      context: context,
      builder: (context) => _ItemEditDialog(item: _extractedItems[index]),
    );

    if (result != null) {
      setState(() {
        _extractedItems[index] = result;
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _extractedItems.removeAt(index);
    });
  }
}

class _ItemEditDialog extends StatefulWidget {
  final ReceiptItem? item;

  const _ItemEditDialog({this.item});

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _priceController.text = widget.item!.price.toStringAsFixed(2);
      _quantity = widget.item!.quantity;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Item Name',
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quantity', style: TextStyle(fontSize: 12)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        Text('$_quantity'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixText: '\$ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final price = double.tryParse(_priceController.text) ?? 0;
            
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter item name')),
              );
              return;
            }

            Navigator.pop(
              context,
              ReceiptItem(
                name: name,
                quantity: _quantity,
                price: price,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
