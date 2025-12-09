import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import '../../models/shopping_list.dart';
import '../../services/shopping_service.dart';
import '../../widgets/toast_notification.dart';

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
      ShoppingList result;
      if (widget.list == null) {
        // Create new list
        result = await _shoppingService.createShoppingList(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isDefault: _isDefault,
        );
      } else {
        // Update existing list
        await _shoppingService.updateShoppingList(
          widget.list!.copyWith(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            isDefault: _isDefault,
            updatedAt: DateTime.now(),
          ),
        );
        result = widget.list!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isDefault: _isDefault,
          updatedAt: DateTime.now(),
        );
      }

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e, st) {
      Logger.error('Error saving list', error: e, stackTrace: st, tag: 'AddEditShoppingListDialog');
      if (mounted) {
        ToastNotification.error(context, 'Failed to save list');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.list == null ? 'Create Shopping List' : 'Edit Shopping List'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'List Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a list name';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Set as default list'),
                value: _isDefault,
                onChanged: _isLoading
                    ? null
                    : (value) => setState(() => _isDefault = value ?? false),
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
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.list == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

