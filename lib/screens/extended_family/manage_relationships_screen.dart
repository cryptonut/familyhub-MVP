import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/extended_family_relationship.dart';
import '../../services/extended_family_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/firestore_path_utils.dart';
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
    String? selectedUserId;
    String? userEmail;
    ExtendedFamilyRelationship selectedRelationship = ExtendedFamilyRelationship.other;
    ExtendedFamilyPermission selectedPermission = ExtendedFamilyPermission.viewOnly;
    String? customRelationshipName;
    bool isSearching = false;
    bool isAdding = false;
    String? searchError;
    final _emailController = TextEditingController();
    final _customNameController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Extended Family Member'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'Enter member\'s email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an email address';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setDialogState(() {
                          selectedUserId = null;
                          userEmail = null;
                          searchError = null;
                        });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (isSearching)
                    const Center(child: CircularProgressIndicator())
                  else if (searchError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        searchError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    )
                  else if (selectedUserId != null && userEmail != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text('User found: $userEmail')),
                        ],
                      ),
                    ),
                  if (selectedUserId == null && !isSearching)
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        
                        setDialogState(() {
                          isSearching = true;
                          searchError = null;
                        });

                        try {
                          final authService = AuthService();
                          final user = await authService.findUserByEmail(_emailController.text.trim());
                          
                          if (user == null) {
                            setDialogState(() {
                              searchError = 'User not found. They may need to sign up first.';
                              isSearching = false;
                            });
                            return;
                          }

                          // Check if user is already a member
                          final existing = await _service.getRelationship(
                            hubId: widget.hubId,
                            userId: user.uid,
                          );

                          if (existing != null) {
                            setDialogState(() {
                              searchError = 'This user is already a member of this hub.';
                              isSearching = false;
                            });
                            return;
                          }

                          setDialogState(() {
                            selectedUserId = user.uid;
                            userEmail = user.email ?? _emailController.text.trim();
                            isSearching = false;
                          });
                        } catch (e) {
                          setDialogState(() {
                            searchError = 'Error searching for user: $e';
                            isSearching = false;
                          });
                        }
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Search User'),
                    ),
                  if (selectedUserId != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Relationship:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ExtendedFamilyRelationship>(
                      value: selectedRelationship,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: ExtendedFamilyRelationship.values.map((relationship) {
                        return DropdownMenuItem(
                          value: relationship,
                          child: Text(relationship.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedRelationship = value;
                            if (value != ExtendedFamilyRelationship.other) {
                              customRelationshipName = null;
                              _customNameController.clear();
                            }
                          });
                        }
                      },
                    ),
                    if (selectedRelationship == ExtendedFamilyRelationship.other) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customNameController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Relationship Name',
                          hintText: 'e.g., Step-sister, Godmother',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (selectedRelationship == ExtendedFamilyRelationship.other &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Please enter a relationship name';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setDialogState(() {
                            customRelationshipName = value.trim().isEmpty ? null : value.trim();
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Permission Level:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ExtendedFamilyPermission>(
                      value: selectedPermission,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: ExtendedFamilyPermission.values.map((permission) {
                        return DropdownMenuItem(
                          value: permission,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(permission.displayName),
                              Text(
                                permission.description,
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedPermission = value;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isAdding ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isAdding || selectedUserId == null
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      if (selectedRelationship == ExtendedFamilyRelationship.other &&
                          (customRelationshipName == null || customRelationshipName!.isEmpty)) {
                        return;
                      }

                      setDialogState(() => isAdding = true);

                      try {
                        await _service.addExtendedFamilyMember(
                          hubId: widget.hubId,
                          userId: selectedUserId!,
                          relationship: selectedRelationship,
                          customRelationshipName: customRelationshipName,
                          permission: selectedPermission,
                        );

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          _loadRelationships();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Member added successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isAdding = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error adding member: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isAdding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Member'),
            ),
          ],
        ),
      ),
    ).then((_) {
      _emailController.dispose();
      _customNameController.dispose();
    });
  }

  void _showEditRelationshipDialog(ExtendedFamilyMember relationship) {
    ExtendedFamilyRelationship selectedRelationship = relationship.relationship;
    ExtendedFamilyPermission selectedPermission = relationship.permission;
    String? customRelationshipName = relationship.customRelationshipName;
    final _customNameController = TextEditingController(text: customRelationshipName);
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Relationship'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Relationship:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ExtendedFamilyRelationship>(
                    value: selectedRelationship,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: ExtendedFamilyRelationship.values.map((rel) {
                      return DropdownMenuItem(
                        value: rel,
                        child: Text(rel.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedRelationship = value;
                          if (value != ExtendedFamilyRelationship.other) {
                            customRelationshipName = null;
                            _customNameController.clear();
                          }
                        });
                      }
                    },
                  ),
                  if (selectedRelationship == ExtendedFamilyRelationship.other) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _customNameController,
                      decoration: const InputDecoration(
                        labelText: 'Custom Relationship Name',
                        hintText: 'e.g., Step-sister, Godmother',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (selectedRelationship == ExtendedFamilyRelationship.other &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please enter a relationship name';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setDialogState(() {
                          customRelationshipName = value.trim().isEmpty ? null : value.trim();
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Permission Level:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ExtendedFamilyPermission>(
                    value: selectedPermission,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: ExtendedFamilyPermission.values.map((permission) {
                      return DropdownMenuItem(
                        value: permission,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(permission.displayName),
                            Text(
                              permission.description,
                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedPermission = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _customNameController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                if (selectedRelationship == ExtendedFamilyRelationship.other &&
                    (customRelationshipName == null || customRelationshipName!.isEmpty)) {
                  return;
                }

                try {
                  // Find the relationship document ID
                  final relationships = await _service.getHubRelationships(widget.hubId);
                  final relationshipDoc = relationships.firstWhere(
                    (r) => r.userId == relationship.userId,
                  );

                  // Get the relationship ID from Firestore
                  final snapshot = await FirebaseFirestore.instance
                      .collection(FirestorePathUtils.getCollectionPath('extended_family_relationships'))
                      .where('hubId', isEqualTo: widget.hubId)
                      .where('userId', isEqualTo: relationship.userId)
                      .limit(1)
                      .get();

                  if (snapshot.docs.isNotEmpty) {
                    await _service.updateRelationship(
                      relationshipId: snapshot.docs.first.id,
                      relationship: selectedRelationship,
                      customRelationshipName: customRelationshipName,
                      permission: selectedPermission,
                    );

                    _customNameController.dispose();
                    Navigator.pop(dialogContext);
                    _loadRelationships();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Relationship updated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
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
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
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


