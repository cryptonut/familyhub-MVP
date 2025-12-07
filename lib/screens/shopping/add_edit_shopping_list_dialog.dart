import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shopping_list.dart';
import '../../models/user_model.dart';
import '../../services/shopping_service.dart';
import '../../providers/user_data_provider.dart';
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
  
  bool _isDefault = false;
  bool _isLoading = false;
  List<String> _selectedMembers = [];
  List<UserModel> _familyMembers = [];

  bool get _isEditing => widget.list != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.list!.name;
      _descriptionController.text = widget.list!.description ?? '';
      _isDefault = widget.list!.isDefault;
      _selectedMembers = List.from(widget.list!.sharedWith);
    }
    _loadFamilyMembers();
  }

  void _loadFamilyMembers() {
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    setState(() {
      _familyMembers = userProvider.familyMembers;
    });
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
      
      if (_isEditing) {
        final updated = widget.list!.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isDefault: _isDefault,
          sharedWith: _selectedMembers,
        );
        await _shoppingService.updateShoppingList(updated);
        result = updated;
      } else {
        result = await _shoppingService.createShoppingList(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          isDefault: _isDefault,
          sharedWith: _selectedMembers,
        );
      }

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.error(context, 'Error saving list: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text(_isEditing ? 'Edit List' : 'New Shopping List'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'List Name',
                  hintText: 'e.g., Weekly Groceries',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a list name';
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 16),
              
              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add a description...',
                  prefixIcon: Icon(Icons.notes),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Default checkbox
              CheckboxListTile(
                value: _isDefault,
                onChanged: (value) {
                  setState(() => _isDefault = value ?? false);
                },
                title: const Text('Set as default list'),
                subtitle: const Text(
                  'Default list appears first and opens automatically',
                  style: TextStyle(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              
              // Share with family members
              Text(
                'Share with',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_familyMembers.isEmpty)
                Text(
                  'No family members found',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...List.generate(_familyMembers.length, (index) {
                  final member = _familyMembers[index];
                  final isSelected = _selectedMembers.contains(member.uid);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedMembers.add(member.uid);
                        } else {
                          _selectedMembers.remove(member.uid);
                        }
                      });
                    },
                    title: Text(member.displayName),
                    subtitle: member.relationship != null
                        ? Text(
                            member.relationship!,
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                    secondary: CircleAvatar(
                      backgroundImage: member.photoUrl != null
                          ? NetworkImage(member.photoUrl!)
                          : null,
                      child: member.photoUrl == null
                          ? Text(member.displayName.isNotEmpty
                              ? member.displayName[0].toUpperCase()
                              : '?')
                          : null,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
