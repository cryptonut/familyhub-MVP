import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/relationship_utils.dart';

class RelationshipDialog extends StatefulWidget {
  final UserModel user;
  final UserModel? currentUser;
  final UserModel? familyCreator;
  final VoidCallback onUpdated;

  const RelationshipDialog({
    super.key,
    required this.user,
    required this.currentUser,
    required this.familyCreator,
    required this.onUpdated,
  });

  @override
  State<RelationshipDialog> createState() => _RelationshipDialogState();
}

class _RelationshipDialogState extends State<RelationshipDialog> {
  final AuthService _authService = AuthService();
  String? _selectedRelationship;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedRelationship = widget.user.relationship;
  }

  bool _canEdit() {
    if (widget.currentUser == null || widget.familyCreator == null) {
      return false;
    }
    
    final isCreator = widget.familyCreator!.uid == widget.currentUser!.uid;
    final isAdmin = widget.currentUser!.isAdmin();
    
    return isCreator || isAdmin;
  }

  Future<void> _saveRelationship() async {
    if (!_canEdit()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the family creator or Admins can update relationships'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _authService.updateRelationship(
        widget.user.uid,
        _selectedRelationship,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Relationship updated for ${widget.user.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUpdated();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating relationship: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _canEdit();
    final availableRelationships = RelationshipUtils.getAvailableRelationships();

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              widget.user.displayName.isNotEmpty
                  ? widget.user.displayName[0].toUpperCase()
                  : widget.user.email[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.user.displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!canEdit) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Only the family creator or Admins can edit relationships.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const Text(
              'Relationship (from family creator\'s perspective):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            if (canEdit)
              DropdownButtonFormField<String>(
                value: _selectedRelationship,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select relationship',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...availableRelationships.map((rel) {
                    return DropdownMenuItem<String>(
                      value: rel,
                      child: Text(RelationshipUtils.getRelationshipLabel(rel)),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRelationship = value;
                  });
                },
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _selectedRelationship != null
                      ? RelationshipUtils.getRelationshipLabel(_selectedRelationship)
                      : 'Not set',
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
              ),
            if (widget.user.relationship != null) ...[
              const SizedBox(height: 16),
              Text(
                'Current: ${RelationshipUtils.getRelationshipLabel(widget.user.relationship)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (canEdit)
          ElevatedButton(
            onPressed: _isSaving ? null : _saveRelationship,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
      ],
    );
  }
}

