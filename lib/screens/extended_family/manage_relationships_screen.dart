import 'package:flutter/material.dart';
import '../../models/extended_family_relationship.dart';
import '../../services/extended_family_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

/// Screen for managing extended family relationships
class ManageRelationshipsScreen extends StatefulWidget {
  final String hubId;

  const ManageRelationshipsScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<ManageRelationshipsScreen> createState() => _ManageRelationshipsScreenState();
}

class _ManageRelationshipsScreenState extends State<ManageRelationshipsScreen> {
  final ExtendedFamilyService _service = ExtendedFamilyService();
  final AuthService _authService = AuthService();
  List<ExtendedFamilyMember> _relationships = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRelationships();
  }

  Future<void> _loadRelationships() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final relationships = await _service.getHubRelationships(widget.hubId);
      if (mounted) {
        setState(() {
          _relationships = relationships;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Relationships'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMemberDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _relationships.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      Text(
                        'No extended family members yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      ElevatedButton.icon(
                        onPressed: () => _showAddMemberDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Member'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  itemCount: _relationships.length,
                  itemBuilder: (context, index) {
                    final relationship = _relationships[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(relationship.relationship.displayName[0]),
                        ),
                        title: Text(relationship.relationship.displayName),
                        subtitle: Text(relationship.permission.displayName),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: const Text('Edit Relationship'),
                              onTap: () => _showEditRelationshipDialog(relationship),
                            ),
                            PopupMenuItem(
                              child: const Text('Remove'),
                              onTap: () => _confirmRemoveMember(relationship),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    // TODO: Implement add member dialog with user selection and relationship picker
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Extended Family Member'),
        content: const Text('Member invitation flow will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditRelationshipDialog(ExtendedFamilyMember relationship) {
    // TODO: Implement edit relationship dialog
  }

  void _confirmRemoveMember(ExtendedFamilyMember relationship) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove ${relationship.relationship.displayName} from this hub?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _service.removeExtendedFamilyMember(
                  hubId: widget.hubId,
                  userId: relationship.userId,
                );
                _loadRelationships();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error removing member: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}


