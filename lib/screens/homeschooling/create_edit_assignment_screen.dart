import 'package:flutter/material.dart';
import '../../models/assignment.dart' show Assignment, AssignmentStatus;
import '../../models/student_profile.dart';
import '../../services/homeschooling_service.dart';
import '../../utils/app_theme.dart';

/// Screen for creating or editing an assignment
class CreateEditAssignmentScreen extends StatefulWidget {
  final String hubId;
  final List<StudentProfile> students;
  final Assignment? assignment;

  const CreateEditAssignmentScreen({
    super.key,
    required this.hubId,
    required this.students,
    this.assignment,
  });

  @override
  State<CreateEditAssignmentScreen> createState() => _CreateEditAssignmentScreenState();
}

class _CreateEditAssignmentScreenState extends State<CreateEditAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final HomeschoolingService _service = HomeschoolingService();
  String? _selectedStudentId;
  String? _selectedSubject;
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.assignment != null) {
      final assignment = widget.assignment!;
      _titleController.text = assignment.title;
      _descriptionController.text = assignment.description ?? '';
      _selectedSubject = assignment.subject;
      _selectedStudentId = assignment.studentId;
      _dueDate = assignment.dueDate;
    } else if (widget.students.isNotEmpty) {
      _selectedStudentId = widget.students.first.id;
      // Set first subject as default if student has subjects
      final firstStudent = widget.students.first;
      if (firstStudent.subjects.isNotEmpty) {
        _selectedSubject = firstStudent.subjects.first;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Get the selected student's enrolled subjects
  List<String> _getAvailableSubjects() {
    if (_selectedStudentId == null) return [];
    final student = widget.students.firstWhere(
      (s) => s.id == _selectedStudentId,
      orElse: () => widget.students.first,
    );
    return student.subjects;
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _saveAssignment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }

    if (_selectedSubject == null || _selectedSubject!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject')),
      );
      return;
    }

    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.assignment == null) {
        await _service.createAssignment(
          hubId: widget.hubId,
          studentId: _selectedStudentId!,
          subject: _selectedSubject!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          dueDate: _dueDate!,
        );
      } else {
        // Update assignment
        await _service.updateAssignment(
          hubId: widget.hubId,
          assignmentId: widget.assignment!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          subject: _selectedSubject!,
          studentId: _selectedStudentId ?? widget.assignment!.studentId,
          dueDate: _dueDate ?? widget.assignment!.dueDate,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving assignment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment == null ? 'Create Assignment' : 'Edit Assignment'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              if (widget.students.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedStudentId,
                  decoration: const InputDecoration(
                    labelText: 'Student *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.students.map((student) {
                    return DropdownMenuItem<String>(
                      value: student.id,
                      child: Text(student.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStudentId = value;
                      // Reset subject if current subject is not in new student's subjects
                      final availableSubjects = _getAvailableSubjects();
                      if (_selectedSubject != null && !availableSubjects.contains(_selectedSubject)) {
                        _selectedSubject = availableSubjects.isNotEmpty ? availableSubjects.first : null;
                      } else if (_selectedSubject == null && availableSubjects.isNotEmpty) {
                        _selectedSubject = availableSubjects.first;
                      }
                    });
                  },
                ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Enter assignment title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter assignment title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),
              if (_selectedStudentId != null && _getAvailableSubjects().isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    border: OutlineInputBorder(),
                  ),
                  items: _getAvailableSubjects().map((subject) {
                    return DropdownMenuItem<String>(
                      value: subject,
                      child: Text(subject),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSubject = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a subject';
                    }
                    return null;
                  },
                )
              else if (_selectedStudentId != null)
                TextFormField(
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    hintText: 'No subjects enrolled for this student',
                    border: OutlineInputBorder(),
                    helperText: 'Please add subjects to the student profile first',
                  ),
                )
              else
                TextFormField(
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    hintText: 'Select a student first',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter assignment description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              InkWell(
                onTap: _selectDueDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due Date *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _dueDate != null
                        ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                        : 'Select due date',
                    style: TextStyle(
                      color: _dueDate != null
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
                  ],
                ),
              ),
            ),
            // Large green Done button at bottom
            Container(
              padding: EdgeInsets.only(
                left: AppTheme.spacingMD,
                right: AppTheme.spacingMD,
                top: AppTheme.spacingMD,
                bottom: AppTheme.spacingMD + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : () {
                    if (_formKey.currentState!.validate()) {
                      _saveAssignment();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill in all required fields'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : widget.assignment == null
                            ? 'Create Assignment'
                            : 'Save Changes',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

