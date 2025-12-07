import 'package:flutter/material.dart';
import '../../services/shopping_service.dart';
import '../../models/shopping_list_item.dart';

class AddItemDialog extends StatefulWidget {
  final ShoppingService shoppingService;
  final String listId;
  final ShoppingListItem? existingItem;

  const AddItemDialog({
    super.key,
    required this.shoppingService,
    required this.listId,
    this.existingItem,
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  List<String> _suggestions = [];
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _nameController.text = widget.existingItem!.name;
      _quantityController.text = widget.existingItem!.quantity.toString();
      _categoryController.text = widget.existingItem!.category ?? '';
      _notesController.text = widget.existingItem!.notes ?? '';
    } else {
      _quantityController.text = '1';
    }
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final query = _nameController.text.trim();
    if (query.length >= 2) {
      _loadSuggestions(query);
    } else {
      setState(() => _suggestions = []);
    }
  }

  Future<void> _loadSuggestions(String query) async {
    try {
      final suggestions = await widget.shoppingService.getItemSuggestions(query);
      if (mounted) {
        setState(() => _suggestions = suggestions);
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _startListening() async {
    setState(() => _isListening = true);
    // TODO: Implement speech-to-text
    // For now, show a placeholder
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech-to-text coming soon'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    setState(() => _isListening = false);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an item name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    if (quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantity must be at least 1'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.existingItem != null) {
        // Update existing item
        final updatedItem = widget.existingItem!.copyWith(
          name: name,
          quantity: quantity,
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
        await widget.shoppingService.updateItem(updatedItem);
      } else {
        // Create new item
        await widget.shoppingService.addItem(
          widget.listId,
          name,
          quantity: quantity,
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context, {'success': true});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingItem != null ? 'Edit Item' : 'Add Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : Colors.grey,
                      ),
                      onPressed: _isLoading ? null : _startListening,
                      tooltip: 'Speech-to-text',
                    ),
                  ],
                ),
              ),
              enabled: !_isLoading,
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(suggestion),
                      onTap: () {
                        _nameController.text = suggestion;
                        setState(() => _suggestions = []);
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., Produce, Dairy, Meat',
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              enabled: !_isLoading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.existingItem != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
