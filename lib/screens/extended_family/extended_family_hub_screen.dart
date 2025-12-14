import 'package:flutter/material.dart';
import '../../models/hub.dart';
import '../../models/extended_family_relationship.dart';
import '../../services/extended_family_service.dart';
import '../../services/extended_family_privacy_service.dart';
import '../../services/hub_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/premium_feature_gate.dart';
import 'manage_relationships_screen.dart';
import 'privacy_settings_screen.dart';
import 'family_tree_screen.dart';

/// Screen for managing extended family hub
class ExtendedFamilyHubScreen extends StatefulWidget {
  final String hubId;

  const ExtendedFamilyHubScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<ExtendedFamilyHubScreen> createState() => _ExtendedFamilyHubScreenState();
}

class _ExtendedFamilyHubScreenState extends State<ExtendedFamilyHubScreen> {
  final HubService _hubService = HubService();
  final ExtendedFamilyService _extendedFamilyService = ExtendedFamilyService();
  Hub? _hub;
  List<ExtendedFamilyMember> _relationships = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHubData();
  }

  Future<void> _loadHubData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hub = await _hubService.getHub(widget.hubId);
      final relationships = await _extendedFamilyService.getHubRelationships(widget.hubId);

      if (mounted) {
        setState(() {
          _hub = hub;
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Extended Family Hub')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hub == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Extended Family Hub')),
        body: const Center(child: Text('Hub not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_hub!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHubData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hub description
              if (_hub!.description.isNotEmpty) ...[
                Text(
                  _hub!.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppTheme.spacingLG),
              ],
              // Quick actions
              _buildQuickActions(),
              const SizedBox(height: AppTheme.spacingLG),
              // Family members
              _buildFamilyMembersSection(),
              const SizedBox(height: AppTheme.spacingLG),
              // Family tree
              _buildFamilyTreeSection(),
              const SizedBox(height: AppTheme.spacingLG),
              // Privacy settings
              _buildPrivacySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ManageRelationshipsScreen(hubId: widget.hubId),
              ),
            ),
            icon: const Icon(Icons.people),
            label: const Text('Manage Members'),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSM),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FamilyTreeScreen(hubId: widget.hubId),
              ),
            ),
            icon: const Icon(Icons.account_tree),
            label: const Text('Family Tree'),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyMembersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Family Members',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageRelationshipsScreen(hubId: widget.hubId),
                    ),
                  ),
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            if (_relationships.isEmpty)
              const Text('No extended family members added yet')
            else
              ..._relationships.map((relationship) => ListTile(
                    leading: CircleAvatar(
                      child: Text(relationship.relationship.displayName[0]),
                    ),
                    title: Text(relationship.relationship.displayName),
                    subtitle: Text(relationship.permission.displayName),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyTreeSection() {
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FamilyTreeScreen(hubId: widget.hubId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Icon(
                Icons.account_tree,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family Tree',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Visualize family relationships',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrivacySettingsScreen(hubId: widget.hubId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Icon(
                Icons.privacy_tip,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy Settings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Control what extended family can see',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Members'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManageRelationshipsScreen(hubId: widget.hubId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('Privacy Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrivacySettingsScreen(hubId: widget.hubId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_tree),
              title: const Text('Family Tree'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FamilyTreeScreen(hubId: widget.hubId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


