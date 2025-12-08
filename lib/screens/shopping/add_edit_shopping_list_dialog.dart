import 'package:flutter/material.dart';
import '../../models/shopping_list.dart';
import '../../services/shopping_service.dart';
import '../../widgets/toast_notification.dart';
import '../../core/services/logger_service.dart';

class AddEditShoppingListDialog extends StatefulWidget {
  final ShoppingList? list;

  const AddEditShoppingListDialog({super.key, this.list});

  @override
  State<AddEditShoppingListDialog> createState() => _AddEditShoppingListDialogState();
}

class _AddEditShoppingListDialogState extends State<AddEditShoppingListDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ShoppingService _shoppingService = ShoppingService();
  bool _isLoading = false;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    if (widget.list != null) {
      _nameController.text = widget.list!.name;
      _descriptionController.text = widget.list!.description ?? '';
      _isDefault = widget.list!.isDefault;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.list != null) {
        // Update existing list
        final updatedList = widget.list!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isDefault: _isDefault,
          updatedAt: DateTime.now(),
        );
        await _shoppingService.updateShoppingList(updatedList);
      } else {
        // Create new list
        final newList = await _shoppingService.createShoppingList(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isDefault: _isDefault,
        );
        if (mounted) {
          Navigator.pop(context, newList);
          return;
        }
      }

      if (mounted) {
        Navigator.pop(context, widget.list);
      }
    } catch (e, st) {
      Logger.error('Error ${widget.list != null ? 'updating' : 'creating'} list', error: e, stackTrace: st, tag: 'AddEditShoppingListDialog');
      if (mounted) {
        ToastNotification.error(context, 'Error ${widget.list != null ? 'updating' : 'creating'} list: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.list != null ? 'Edit List' : 'Create List'),
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
                  labelText: 'List Name',
                  hintText: 'e.g., Weekly Groceries',
                  prefixIcon: Icon(Icons.shopping_cart),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a list name';
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add a description...',
                  prefixIcon: Icon(Icons.description),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Set as default list'),
                subtitle: const Text('This list will be shown first'),
                value: _isDefault,
                onChanged: (value) {
                  setState(() => _isDefault = value ?? false);
                },
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
              : Icon(widget.list != null ? Icons.save : Icons.add),
          label: Text(widget.list != null ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
