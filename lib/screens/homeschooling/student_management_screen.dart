import 'package:flutter/material.dart';
import '../../models/student_profile.dart';
import '../../models/assignment.dart' show Assignment, AssignmentStatus;
import '../../services/homeschooling_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'create_edit_student_screen.dart';

/// Screen for managing students in a homeschooling hub
class StudentManagementScreen extends StatefulWidget {
  final String hubId;
  final String? initialStudentId;

  const StudentManagementScreen({
    super.key,
    required this.hubId,
    this.initialStudentId,
  });

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final HomeschoolingService _service = HomeschoolingService();
  List<StudentProfile> _students = [];
  bool _isLoading = true;
  String? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _selectedStudentId = widget.initialStudentId;
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final students = await _service.getStudentProfiles(widget.hubId);
      if (mounted) {
        setState(() {
          _students = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading students: $e')),
        );
      }
    }
  }

  Future<void> _deleteStudent(StudentProfile student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to delete ${student.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteStudentProfile(widget.hubId, student.id);
        if (mounted) {
          _loadStudents();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting student: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateEditStudentScreen(
                    hubId: widget.hubId,
                  ),
                ),
              );
              if (result == true) {
                _loadStudents();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? EmptyState(
                  icon: Icons.person_outline,
                  title: 'No Students',
                  message: 'Add your first student to get started',
                  action: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateEditStudentScreen(
                            hubId: widget.hubId,
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadStudents();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Student'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStudents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      return ModernCard(
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  child: Text(
                                    student.name.isNotEmpty
                                        ? student.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingMD),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      if (student.gradeLevel != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Grade ${student.gradeLevel}',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ],
                                      if (student.subjects.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 4,
                                          children: student.subjects
                                              .take(3)
                                              .map((subject) => Chip(
                                                    label: Text(
                                                      subject,
                                                      style: const TextStyle(fontSize: 10),
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                  ))
                                              .toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                PopupMenuButton(
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CreateEditStudentScreen(
                                            hubId: widget.hubId,
                                            student: student,
                                          ),
                                        ),
                                      ).then((result) {
                                        if (result == true) {
                                          _loadStudents();
                                        }
                                      });
                                    } else if (value == 'delete') {
                                      _deleteStudent(student);
                                    }
                                  },
                                ),
                              ],
                            ),
                            if (student.dateOfBirth != null) ...[
                              const SizedBox(height: AppTheme.spacingMD),
                              const Divider(),
                              const SizedBox(height: AppTheme.spacingMD),
                              Row(
                                children: [
                                  Icon(
                                    Icons.cake,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Date of Birth: ${_formatDate(student.dateOfBirth!)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                            FutureBuilder<List<Assignment>>(
                              future: _service.getAssignments(
                                hubId: widget.hubId,
                                studentId: student.id,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                  final assignments = snapshot.data!;
                                  final pending = assignments
                                      .where((a) => a.status == AssignmentStatus.pending)
                                      .length;
                                  final completed = assignments
                                      .where((a) => a.status == AssignmentStatus.completed ||
                                          a.status == AssignmentStatus.graded)
                                      .length;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: AppTheme.spacingMD),
                                      const Divider(),
                                      const SizedBox(height: AppTheme.spacingMD),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildStatChip(
                                              'Pending',
                                              pending.toString(),
                                              Colors.orange,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildStatChip(
                                              'Completed',
                                              completed.toString(),
                                              Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

