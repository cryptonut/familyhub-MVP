import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/hub.dart';
import '../../models/user_model.dart';
import '../../models/extended_family_hub_data.dart';
import '../../services/extended_family_hub_service.dart';
import '../../services/auth_service.dart';
import '../../services/hub_service.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/family_tree_widget.dart';

class ExtendedFamilyMemberManagementScreen extends StatefulWidget {
  final Hub hub;

  const ExtendedFamilyMemberManagementScreen({
    super.key,
    required this.hub,
  });

  @override
  State<ExtendedFamilyMemberManagementScreen> createState() =>
      _ExtendedFamilyMemberManagementScreenState();
}

class _ExtendedFamilyMemberManagementScreenState
    extends State<ExtendedFamilyMemberManagementScreen> {
  final ExtendedFamilyHubService _extendedFamilyService =
      ExtendedFamilyHubService();
  final AuthService _authService = AuthService();

  List<UserModel> _members = [];
  ExtendedFamilyHubData? _hubData;
  bool _isLoading = true;
  String? _currentUserId;
  bool _isHubCreator = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUserId = _authService.currentUser?.uid;
      _isHubCreator = _currentUserId == widget.hub.creatorId;

      // Load hub data
      _hubData = await _extendedFamilyService.getExtendedFamilyData(widget.hub.id);

      // Load members
      final memberIds = widget.hub.memberIds;
      final members = <UserModel>[];
      for (var memberId in memberIds) {
        try {
          final userModel = await _authService.getUserModel(memberId);
          if (userModel != null) {
            members.add(userModel);
          }
        } catch (e) {
          // Skip members that can't be loaded
        }
      }

      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteMember() async {
    final emailController = TextEditingController();
    RelationshipType? selectedRelationship;
    PrivacyLevel selectedPrivacy = PrivacyLevel.minimal;
    ExtendedFamilyRole selectedRole = ExtendedFamilyRole.viewer;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Extended Family Member'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              const Text('Relationship:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<RelationshipType>(
                value: selectedRelationship,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: RelationshipType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) => selectedRelationship = value,
              ),
              const SizedBox(height: 16),
              const Text('Privacy Level:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<PrivacyLevel>(
                value: selectedPrivacy,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: PrivacyLevel.values.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(level.displayName),
                        Text(
                          level.description,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) selectedPrivacy = value;
                },
              ),
              const SizedBox(height: 16),
              const Text('Role:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<ExtendedFamilyRole>(
                value: selectedRole,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: ExtendedFamilyRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(role.displayName),
                        Text(
                          role.description,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) selectedRole = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );

    if (result == true && emailController.text.isNotEmpty) {
      try {
        await _extendedFamilyService.inviteExtendedFamilyMember(
          hubId: widget.hub.id,
          email: emailController.text.trim(),
          relationship: selectedRelationship,
          privacyLevel: selectedPrivacy,
          role: selectedRole,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invitation sent!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error sending invite: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editMemberSettings(UserModel member) async {
    final data = _hubData ?? ExtendedFamilyHubData();
    final currentRelationship = data.getRelationship(member.uid);
    final currentPrivacy = data.getPrivacyLevel(member.uid);
    final currentRole = data.getRole(member.uid);

    RelationshipType? selectedRelationship = currentRelationship;
    PrivacyLevel selectedPrivacy = currentPrivacy;
    ExtendedFamilyRole selectedRole = currentRole;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${member.displayName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<RelationshipType>(
                value: selectedRelationship,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  border: OutlineInputBorder(),
                ),
                items: RelationshipType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) => selectedRelationship = value,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PrivacyLevel>(
                value: selectedPrivacy,
                decoration: const InputDecoration(
                  labelText: 'Privacy Level',
                  border: OutlineInputBorder(),
                ),
                items: PrivacyLevel.values.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(level.displayName),
                        Text(
                          level.description,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) selectedPrivacy = value;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ExtendedFamilyRole>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: ExtendedFamilyRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(role.displayName),
                        Text(
                          role.description,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) selectedRole = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        if (selectedRelationship != null) {
          await _extendedFamilyService.setRelationship(
            widget.hub.id,
            member.uid,
            selectedRelationship!,
          );
        }

        await _extendedFamilyService.setPrivacyLevel(
          widget.hub.id,
          member.uid,
          selectedPrivacy,
        );

        await _extendedFamilyService.setMemberRole(
          widget.hub.id,
          member.uid,
          selectedRole,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings updated!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating settings: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.hub.name} - Members'),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            if (_isHubCreator)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _inviteMember,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Invite Extended Family Member'),
                ),
              ),
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.people), text: 'Members'),
                Tab(icon: Icon(Icons.account_tree), text: 'Family Tree'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Members Tab
                  _members.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No members yet',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isHubCreator
                                    ? 'Tap the button above to invite extended family members'
                                    : 'Wait for the hub creator to invite members',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final isCurrentUser = member.uid == _currentUserId;
                            final relationship = _hubData?.getRelationship(member.uid);
                            final privacy = _hubData?.getPrivacyLevel(member.uid) ?? PrivacyLevel.minimal;
                            final role = _hubData?.getRole(member.uid) ?? ExtendedFamilyRole.viewer;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(member.displayName[0].toUpperCase()),
                                ),
                                title: Text(member.displayName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (relationship != null)
                                      Text('Relationship: ${relationship.displayName}'),
                                    Text('Privacy: ${privacy.displayName}'),
                                    Text('Role: ${role.displayName}'),
                                    if (isCurrentUser)
                                      const Text(
                                        '(You)',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.blue,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: _isHubCreator && !isCurrentUser
                                    ? IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _editMemberSettings(member),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                  // Family Tree Tab
                  FamilyTreeWidget(hub: widget.hub),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

