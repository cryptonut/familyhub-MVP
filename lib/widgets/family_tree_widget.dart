import 'package:flutter/material.dart';
import '../models/extended_family_hub_data.dart';
import '../models/hub.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/extended_family_hub_service.dart';

/// Widget to display a simple family tree visualization for extended family hubs
class FamilyTreeWidget extends StatefulWidget {
  final Hub hub;

  const FamilyTreeWidget({
    super.key,
    required this.hub,
  });

  @override
  State<FamilyTreeWidget> createState() => _FamilyTreeWidgetState();
}

class _FamilyTreeWidgetState extends State<FamilyTreeWidget> {
  final ExtendedFamilyHubService _extendedFamilyService = ExtendedFamilyHubService();
  final AuthService _authService = AuthService();

  List<UserModel> _members = [];
  ExtendedFamilyHubData? _hubData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _hubData = await _extendedFamilyService.getExtendedFamilyData(widget.hub.id);

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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No family members yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Invite extended family members to see the family tree',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Family Tree',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          _buildFamilyTree(),
        ],
      ),
    );
  }

  Widget _buildFamilyTree() {
    // Group members by relationship type
    final groupedByRelationship = <RelationshipType, List<UserModel>>{};
    
    for (var member in _members) {
      final relationship = _hubData?.getRelationship(member.uid);
      if (relationship != null) {
        groupedByRelationship.putIfAbsent(relationship, () => []).add(member);
      } else {
        // Members without a relationship go to "other"
        groupedByRelationship.putIfAbsent(RelationshipType.other, () => []).add(member);
      }
    }

    return Column(
      children: groupedByRelationship.entries.map((entry) {
        return _buildRelationshipGroup(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildRelationshipGroup(RelationshipType relationship, List<UserModel> members) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getRelationshipIcon(relationship),
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  relationship.displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('${members.length}'),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: members.map((member) {
                return _buildMemberChip(member);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberChip(UserModel member) {
    final privacy = _hubData?.getPrivacyLevel(member.uid) ?? PrivacyLevel.minimal;
    final role = _hubData?.getRole(member.uid) ?? ExtendedFamilyRole.viewer;

    return Tooltip(
      message: 'Privacy: ${privacy.displayName}, Role: ${role.displayName}',
      child: Chip(
        avatar: CircleAvatar(
          child: Text(member.displayName[0].toUpperCase()),
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
        label: Text(member.displayName),
        onDeleted: null, // Read-only for now
        deleteIcon: _buildPrivacyIcon(privacy),
      ),
    );
  }

  Widget _buildPrivacyIcon(PrivacyLevel privacy) {
    IconData icon;
    Color color;

    switch (privacy) {
      case PrivacyLevel.minimal:
        icon = Icons.lock_outline;
        color = Colors.grey;
        break;
      case PrivacyLevel.standard:
        icon = Icons.lock_open;
        color = Colors.orange;
        break;
      case PrivacyLevel.full:
        icon = Icons.verified;
        color = Colors.green;
        break;
    }

    return Icon(icon, size: 16, color: color);
  }

  IconData _getRelationshipIcon(RelationshipType relationship) {
    switch (relationship) {
      case RelationshipType.grandparent:
        return Icons.elderly;
      case RelationshipType.aunt:
      case RelationshipType.uncle:
        return Icons.family_restroom;
      case RelationshipType.cousin:
        return Icons.people;
      case RelationshipType.sibling:
        return Icons.group;
      case RelationshipType.other:
        return Icons.person;
    }
  }
}

