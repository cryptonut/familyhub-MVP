import 'package:flutter/material.dart';
import '../../models/hub.dart';
import '../../models/student_profile.dart';
import '../../services/homeschooling_service.dart';
import '../../services/hub_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/premium_feature_gate.dart';
import '../hubs/hub_settings_screen.dart';
import '../hubs/invite_members_dialog.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'student_management_screen.dart';
import 'assignment_tracking_screen.dart';
import 'lesson_planning_screen.dart';

/// Main screen for homeschooling hub management
class HomeschoolingHubScreen extends StatefulWidget {
  final String hubId;

  const HomeschoolingHubScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<HomeschoolingHubScreen> createState() => _HomeschoolingHubScreenState();
}

class _HomeschoolingHubScreenState extends State<HomeschoolingHubScreen> {
  final HubService _hubService = HubService();
  final HomeschoolingService _homeschoolingService = HomeschoolingService();
  Hub? _hub;
  List<StudentProfile> _students = [];
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
      final students = await _homeschoolingService.getStudentProfiles(widget.hubId);

      if (mounted) {
        setState(() {
          _hub = hub;
          _students = students;
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
        appBar: AppBar(title: const Text('Homeschooling Hub')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hub == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Homeschooling Hub')),
        body: const Center(child: Text('Hub not found')),
      );
    }

    return PremiumFeatureGate(
      featureName: 'homeschooling',
      child: Scaffold(
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
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                ],

                // Quick stats
                _buildQuickStats(),

                const SizedBox(height: AppTheme.spacingLG),

                // Main features
                _buildFeatureCards(),

                const SizedBox(height: AppTheme.spacingLG),

                // Active students
                _buildActiveStudents(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: ModernCard(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              children: [
                Text(
                  '${_students.length}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Students',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingMD),
        Expanded(
          child: ModernCard(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              children: [
                FutureBuilder<int>(
                  future: _homeschoolingService
                      .getAssignments(hubId: widget.hubId)
                      .then((assignments) => assignments.length),
                  builder: (context, snapshot) {
                    return Text(
                      '${snapshot.data ?? 0}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Assignments',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ModernCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentManagementScreen(hubId: widget.hubId),
              ),
            );
          },
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Icon(
                Icons.person,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Management',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage student profiles and information',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ModernCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssignmentTrackingScreen(hubId: widget.hubId),
              ),
            );
          },
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Icon(
                Icons.assignment,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assignment Tracking',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create and track assignments',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ModernCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LessonPlanningScreen(hubId: widget.hubId),
              ),
            );
          },
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Icon(
                Icons.book,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lesson Planning',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plan lessons and track progress',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveStudents() {
    if (_students.isEmpty) {
      return EmptyState(
        icon: Icons.person_outline,
        title: 'No Students Yet',
        message: 'Add your first student to get started',
        action: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentManagementScreen(hubId: widget.hubId),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Student'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Students',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ..._students.take(3).map((student) => ModernCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentManagementScreen(
                      hubId: widget.hubId,
                      initialStudentId: student.id,
                    ),
                  ),
                );
              },
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Text(
                      student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (student.gradeLevel != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Grade ${student.gradeLevel}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            )),
        if (_students.length > 3)
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentManagementScreen(hubId: widget.hubId),
                ),
              );
            },
            child: Text('View All ${_students.length} Students'),
          ),
      ],
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
              leading: const Icon(Icons.info_outline),
              title: const Text('Hub Information'),
              onTap: () async {
                Navigator.pop(context);
                if (_hub != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HubSettingsScreen(hub: _hub!),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Manage Members'),
              onTap: () async {
                Navigator.pop(context);
                if (_hub != null) {
                  final authService = AuthService();
                  final hubService = HubService();
                  final members = <UserModel>[];
                  
                  // Load hub members
                  for (var memberId in _hub!.memberIds) {
                    final user = await authService.getUserModel(memberId);
                    if (user != null) {
                      members.add(user);
                    }
                  }
                  
                  if (mounted) {
                    await showDialog(
                      context: context,
                      builder: (context) => InviteMembersDialog(
                        hub: _hub!,
                        currentMembers: members,
                      ),
                    );
                    // Reload hub after member changes
                    _loadHubData();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

