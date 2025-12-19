import 'package:flutter/material.dart';
import '../../models/hub.dart';
import '../../models/student_profile.dart';
import '../../models/learning_milestone.dart';
import '../../models/assignment.dart';
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
import 'resource_library_screen.dart';
import 'progress_reports_screen.dart';

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
  final AuthService _authService = AuthService();
  Hub? _hub;
  List<StudentProfile> _students = [];
  List<LearningMilestone> _recentMilestones = [];
  List<UserModel> _hubMembers = [];
  int _resourceCount = 0;
  int _pendingAssignments = 0;
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
      
      // Load additional data
      final resources = await _homeschoolingService.getEducationalResources(hubId: widget.hubId);
      final assignments = await _homeschoolingService.getAssignments(hubId: widget.hubId);
      final pendingAssignments = assignments
          .where((a) => a.status == AssignmentStatus.pending ||
              a.status == AssignmentStatus.inProgress)
          .length;
      
      // Get recent milestones from all students
      final allMilestones = <LearningMilestone>[];
      for (var student in students) {
        final milestones = await _homeschoolingService.getLearningMilestones(
          hubId: widget.hubId,
          studentId: student.id,
        );
        allMilestones.addAll(milestones);
      }
      allMilestones.sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
      final recentMilestones = allMilestones.take(5).toList();
      
      // Load hub members (co-teachers)
      final hubMembers = <UserModel>[];
      if (hub != null) {
        for (var memberId in hub.memberIds) {
          try {
            final user = await _authService.getUserModel(memberId);
            if (user != null) {
              hubMembers.add(user);
            }
          } catch (e) {
            // Skip if user not found
          }
        }
      }

      if (mounted) {
        setState(() {
          _hub = hub;
          _students = students;
          _resourceCount = resources.length;
          _pendingAssignments = pendingAssignments;
          _recentMilestones = recentMilestones;
          _hubMembers = hubMembers;
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

                // Recent milestones
                if (_recentMilestones.isNotEmpty) ...[
                  _buildRecentMilestones(),
                  const SizedBox(height: AppTheme.spacingLG),
                ],

                // Co-teaching / Members section
                _buildCoTeachingSection(),

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
                Text(
                  '$_pendingAssignments',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _pendingAssignments > 0
                            ? Colors.orange
                            : Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pending',
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
                Text(
                  '$_resourceCount',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Resources',
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                builder: (context) => ResourceLibraryScreen(hubId: widget.hubId),
              ),
            );
          },
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Icon(
                Icons.library_books,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resource Library',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Educational materials and links',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ModernCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProgressReportsScreen(hubId: widget.hubId),
              ),
            );
          },
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              Icon(
                Icons.assessment,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress Reports',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View student progress and reports',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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

  Widget _buildRecentMilestones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Achievements',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ..._recentMilestones.map((milestone) => ModernCard(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
              child: Row(
                children: [
                  Icon(
                    _getMilestoneIcon(milestone.type),
                    size: 32,
                    color: _getMilestoneColor(milestone.type),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (milestone.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            milestone.description!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (milestone.subject != null) ...[
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(milestone.subject!),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  IconData _getMilestoneIcon(MilestoneType type) {
    switch (type) {
      case MilestoneType.achievement:
        return Icons.emoji_events;
      case MilestoneType.streak:
        return Icons.local_fire_department;
      case MilestoneType.mastery:
        return Icons.star;
      case MilestoneType.completion:
        return Icons.check_circle;
      case MilestoneType.improvement:
        return Icons.trending_up;
    }
  }

  Color _getMilestoneColor(MilestoneType type) {
    switch (type) {
      case MilestoneType.achievement:
        return Colors.amber;
      case MilestoneType.streak:
        return Colors.orange;
      case MilestoneType.mastery:
        return Colors.purple;
      case MilestoneType.completion:
        return Colors.green;
      case MilestoneType.improvement:
        return Colors.blue;
    }
  }

  Widget _buildCoTeachingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Co-Teachers & Collaborators',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (_hub != null)
              TextButton(
                onPressed: () async {
                  final members = <UserModel>[];
                  for (var memberId in _hub!.memberIds) {
                    final user = await _authService.getUserModel(memberId);
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
                    _loadHubData();
                  }
                },
                child: const Text('Manage'),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),
        if (_hubMembers.isEmpty)
          const Text('No collaborators yet')
        else
          Wrap(
            spacing: AppTheme.spacingSM,
            runSpacing: AppTheme.spacingSM,
            children: _hubMembers.map((member) => Chip(
                  avatar: CircleAvatar(
                    radius: 12,
                    child: Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  label: Text(member.displayName),
                  onDeleted: member.uid == _hub?.creatorId
                      ? null
                      : () {
                          // Remove member (would need hub service method)
                        },
                )).toList(),
          ),
        const SizedBox(height: AppTheme.spacingSM),
        Text(
          'All hub members can collaborate on lesson planning, share resources, and view student progress.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
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

