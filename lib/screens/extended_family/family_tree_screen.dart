import 'package:flutter/material.dart';
import '../../models/extended_family_relationship.dart';
import '../../services/extended_family_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

/// Screen for visualizing family tree
class FamilyTreeScreen extends StatefulWidget {
  final String hubId;

  const FamilyTreeScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  final ExtendedFamilyService _service = ExtendedFamilyService();
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
      appBar: AppBar(title: const Text('Family Tree')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _relationships.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_tree,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      Text(
                        'No family relationships yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      Text(
                        'Add extended family members to build your family tree',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Tree Visualization',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      Text(
                        'Family tree visualization will be displayed here. This is a placeholder for the tree component.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppTheme.spacingLG),
                      // Group relationships by type
                      ...ExtendedFamilyRelationship.values.map((relationshipType) {
                        final members = _relationships
                            .where((r) => r.relationship == relationshipType)
                            .toList();
                        if (members.isEmpty) return const SizedBox.shrink();
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingMD),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  relationshipType.displayName,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: AppTheme.spacingSM),
                                ...members.map((member) => ListTile(
                                      leading: const CircleAvatar(),
                                      title: Text('Member ${member.userId.substring(0, 8)}...'),
                                      subtitle: Text(member.permission.displayName),
                                    )),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}


