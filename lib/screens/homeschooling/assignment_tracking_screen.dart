import 'package:flutter/material.dart';
import '../../models/assignment.dart' show Assignment, AssignmentStatus;
import '../../models/student_profile.dart';
import '../../services/homeschooling_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'create_edit_assignment_screen.dart';

/// Screen for tracking assignments in a homeschooling hub
class AssignmentTrackingScreen extends StatefulWidget {
  final String hubId;
  final String? studentId;

  const AssignmentTrackingScreen({
    super.key,
    required this.hubId,
    this.studentId,
  });

  @override
  State<AssignmentTrackingScreen> createState() => _AssignmentTrackingScreenState();
}

class _AssignmentTrackingScreenState extends State<AssignmentTrackingScreen> {
  final HomeschoolingService _service = HomeschoolingService();
  List<Assignment> _assignments = [];
  List<StudentProfile> _students = [];
  String? _selectedStudentId;
  AssignmentStatus? _selectedStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.studentId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final students = await _service.getStudentProfiles(widget.hubId);
      final assignments = await _service.getAssignments(
        hubId: widget.hubId,
        studentId: _selectedStudentId,
        status: _selectedStatus,
      );

      if (mounted) {
        setState(() {
          _students = students;
          _assignments = assignments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  StudentProfile? _getStudent(String studentId) {
    try {
      return _students.firstWhere((s) => s.id == studentId);
    } catch (e) {
      return null;
    }
  }

  Color _getStatusColor(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.pending:
        return Colors.orange;
      case AssignmentStatus.inProgress:
        return Colors.blue;
      case AssignmentStatus.completed:
        return Colors.green;
      case AssignmentStatus.graded:
        return Colors.purple;
      case AssignmentStatus.overdue:
        return Colors.red;
    }
  }

  String _getEmptyStateMessage() {
    // Provide context-aware empty state messages based on active filters
    if (_selectedStudentId != null && _selectedStatus != null) {
      final student = _getStudent(_selectedStudentId!);
      final statusLabel = _getStatusLabel(_selectedStatus!);
      return 'No $statusLabel assignments for ${student?.name ?? "this student"}';
    } else if (_selectedStudentId != null) {
      final student = _getStudent(_selectedStudentId!);
      return 'No assignments for ${student?.name ?? "this student"}';
    } else if (_selectedStatus != null) {
      final statusLabel = _getStatusLabel(_selectedStatus!);
      return 'No $statusLabel assignments';
    } else {
      return 'Create your first assignment';
    }
  }

  String _getStatusLabel(AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.pending:
        return 'Pending';
      case AssignmentStatus.inProgress:
        return 'In Progress';
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.graded:
        return 'Graded';
      case AssignmentStatus.overdue:
        return 'Overdue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateEditAssignmentScreen(
                    hubId: widget.hubId,
                    students: _students,
                  ),
                ),
              );
              if (result == true) {
                // Wait a moment for Firestore to process, then refresh
                await Future.delayed(const Duration(milliseconds: 500));
                _loadData();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                // Student filter
                if (_students.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    value: _selectedStudentId,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Student',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Students'),
                      ),
                      ..._students.map((student) => DropdownMenuItem<String?>(
                            value: student.id,
                            child: Text(student.name),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStudentId = value;
                      });
                      _loadData();
                    },
                  ),
                if (_students.isNotEmpty) const SizedBox(height: AppTheme.spacingMD),
                // Status filter
                DropdownButtonFormField<AssignmentStatus?>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<AssignmentStatus?>(
                      value: null,
                      child: Text('All Statuses'),
                    ),
                    ...AssignmentStatus.values.map((status) => DropdownMenuItem<AssignmentStatus?>(
                          value: status,
                          child: Text(_getStatusLabel(status)),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                    _loadData();
                  },
                ),
              ],
            ),
          ),

          // Assignments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _assignments.isEmpty
                    ? EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'No Assignments',
                        message: _getEmptyStateMessage(),
                        action: (_selectedStudentId == null && _selectedStatus == null)
                            ? ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CreateEditAssignmentScreen(
                                        hubId: widget.hubId,
                                        students: _students,
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    // Wait a moment for Firestore to process, then refresh
                                    await Future.delayed(const Duration(milliseconds: 500));
                                    _loadData();
                                  }
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Create Assignment'),
                              )
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                          itemCount: _assignments.length,
                          itemBuilder: (context, index) {
                            final assignment = _assignments[index];
                            final student = _getStudent(assignment.studentId);
                            final isOverdue = assignment.dueDate.isBefore(DateTime.now()) &&
                                assignment.status != AssignmentStatus.completed &&
                                assignment.status != AssignmentStatus.graded;

                            return ModernCard(
                              padding: const EdgeInsets.all(AppTheme.spacingMD),
                              margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              assignment.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            if (student != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                student.name,
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(assignment.status)
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getStatusColor(assignment.status),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _getStatusLabel(assignment.status),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(assignment.status),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (assignment.description != null) ...[
                                    const SizedBox(height: AppTheme.spacingMD),
                                    Text(
                                      assignment.description!,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                  const SizedBox(height: AppTheme.spacingMD),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.subject,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        assignment.subject,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const SizedBox(width: AppTheme.spacingMD),
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: isOverdue ? Colors.red : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDate(assignment.dueDate),
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: isOverdue ? Colors.red : null,
                                              fontWeight: isOverdue ? FontWeight.bold : null,
                                            ),
                                      ),
                                    ],
                                  ),
                                  if (assignment.grade != null) ...[
                                    const SizedBox(height: AppTheme.spacingMD),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.grade,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Grade: ${assignment.grade!.toStringAsFixed(1)}%',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: AppTheme.spacingMD),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CreateEditAssignmentScreen(
                                                hubId: widget.hubId,
                                                students: _students,
                                                assignment: assignment,
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            // Wait a moment for Firestore to process, then refresh
                                            await Future.delayed(const Duration(milliseconds: 500));
                                            _loadData();
                                          }
                                        },
                                        child: const Text('Edit'),
                                      ),
                                      if (assignment.status != AssignmentStatus.completed &&
                                          assignment.status != AssignmentStatus.graded)
                                        TextButton(
                                          onPressed: () => _markComplete(assignment),
                                          child: const Text('Mark Complete'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _markComplete(Assignment assignment) async {
    try {
      await _service.updateAssignmentStatus(
        hubId: widget.hubId,
        assignmentId: assignment.id,
        status: AssignmentStatus.completed,
        completedBy: _service.currentUserId,
      );
      if (mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment marked as complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

