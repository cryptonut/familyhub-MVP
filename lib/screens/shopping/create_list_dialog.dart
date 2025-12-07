import 'package:flutter/material.dart';

class CreateListDialog extends StatefulWidget {
  const CreateListDialog({super.key});

  @override
  State<CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<CreateListDialog> {
  final _nameController = TextEditingController();
  bool _isDefault = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Shopping List'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'List Name',
              hintText: 'e.g., Weekly Groceries',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _createList(),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Set as default list'),
            value: _isDefault,
            onChanged: (value) => setState(() => _isDefault = value ?? false),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty ? null : _createList,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _createList() {
    if (_nameController.text.trim().isNotEmpty) {
      Navigator.pop(context, _nameController.text.trim());
    }
  }
}
