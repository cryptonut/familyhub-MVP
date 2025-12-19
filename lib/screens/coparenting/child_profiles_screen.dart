import 'package:flutter/material.dart';
import '../../models/child_profile.dart';
import '../../services/coparenting_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'create_edit_child_profile_screen.dart';

class ChildProfilesScreen extends StatefulWidget {
  final String hubId;

  const ChildProfilesScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<ChildProfilesScreen> createState() => _ChildProfilesScreenState();
}

class _ChildProfilesScreenState extends State<ChildProfilesScreen> {
  final CoparentingService _service = CoparentingService();
  List<ChildProfile> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      final profiles = await _service.getChildProfiles(widget.hubId);
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Profiles'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfiles,
              child: _profiles.isEmpty
                  ? EmptyState(
                      icon: Icons.child_care,
                      title: 'No Child Profiles Yet',
                      message: 'Add child profiles to share information',
                      action: FloatingActionButton.extended(
                        onPressed: () => _createProfile(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Child Profile'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      itemCount: _profiles.length,
                      itemBuilder: (context, index) {
                        final profile = _profiles[index];
                        return ModernCard(
                          onTap: () => _viewProfile(profile),
                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    child: Text(
                                      profile.name.isNotEmpty
                                          ? profile.name[0].toUpperCase()
                                          : '?',
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingMD),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        if (profile.dateOfBirth != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'DOB: ${_formatDate(profile.dateOfBirth!)}',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ],
                              ),
                              if (profile.schoolName != null ||
                                  profile.medicalInfo != null) ...[
                                const SizedBox(height: AppTheme.spacingSM),
                                const Divider(),
                                const SizedBox(height: AppTheme.spacingSM),
                                if (profile.schoolName != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.school, size: 16),
                                      const SizedBox(width: AppTheme.spacingXS),
                                      Text(
                                        profile.schoolName!,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                if (profile.medicalInfo != null) ...[
                                  const SizedBox(height: AppTheme.spacingXS),
                                  Row(
                                    children: [
                                      const Icon(Icons.medical_services, size: 16),
                                      const SizedBox(width: AppTheme.spacingXS),
                                      Expanded(
                                        child: Text(
                                          profile.medicalInfo!,
                                          style: Theme.of(context).textTheme.bodySmall,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProfile(),
        icon: const Icon(Icons.add),
        label: const Text('Add Child Profile'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _createProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditChildProfileScreen(hubId: widget.hubId),
      ),
    );

    if (result == true) {
      _loadProfiles();
    }
  }

  Future<void> _viewProfile(ChildProfile profile) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditChildProfileScreen(
          hubId: widget.hubId,
          profile: profile,
        ),
      ),
    );

    if (result == true) {
      _loadProfiles();
    }
  }
}

