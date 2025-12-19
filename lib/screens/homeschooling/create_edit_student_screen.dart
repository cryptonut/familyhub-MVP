import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../models/student_profile.dart';
import '../../models/user_model.dart';
import '../../services/homeschooling_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

/// Screen for creating or editing a student profile
class CreateEditStudentScreen extends StatefulWidget {
  final String hubId;
  final StudentProfile? student;

  const CreateEditStudentScreen({
    super.key,
    required this.hubId,
    this.student,
  });

  @override
  State<CreateEditStudentScreen> createState() => _CreateEditStudentScreenState();
}

class _CreateEditStudentScreenState extends State<CreateEditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gradeLevelController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final List<String> _selectedSubjects = [];
  final HomeschoolingService _homeschoolingService = HomeschoolingService();
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();
  List<UserModel> _familyMembers = [];
  String? _selectedUserId;
  bool _isLoadingMembers = false;
  final List<String> _availableSubjects = [
    'Math',
    'Science',
    'English',
    'History',
    'Geography',
    'Art',
    'Music',
    'Physical Education',
    'Foreign Language',
    'Computer Science',
  ];
  DateTime? _dateOfBirth;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _nameController.text = widget.student!.name;
      _gradeLevelController.text = widget.student!.gradeLevel ?? '';
      _dateOfBirth = widget.student!.dateOfBirth;
      _selectedSubjects.addAll(widget.student!.subjects);
      _selectedUserId = widget.student!.userId;
      if (_dateOfBirth != null) {
        _dateOfBirthController.text = _formatDate(_dateOfBirth!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeLevelController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 5)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _dateOfBirthController.text = _formatDate(picked);
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.student == null) {
        // Create new student
        // Use selected user ID or generate a placeholder if no user selected
        // (for students who don't have accounts yet)
        final userId = _selectedUserId ?? 'student_${_uuid.v4()}';
        
        await _homeschoolingService.createStudentProfile(
          hubId: widget.hubId,
          userId: userId,
          name: _nameController.text.trim(),
          dateOfBirth: _dateOfBirth,
          gradeLevel: _gradeLevelController.text.trim().isEmpty
              ? null
              : _gradeLevelController.text.trim(),
          subjects: _selectedSubjects,
        );
      } else {
        // Update existing student
        await _homeschoolingService.updateStudentProfile(
          widget.hubId,
          widget.student!.id,
          name: _nameController.text.trim(),
          dateOfBirth: _dateOfBirth,
          gradeLevel: _gradeLevelController.text.trim().isEmpty
              ? null
              : _gradeLevelController.text.trim(),
          subjects: _selectedSubjects,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.student == null
                ? 'Student created successfully'
                : 'Student updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving student: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student == null ? 'Add Student' : 'Edit Student'),
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
              if (widget.student == null && !_isLoadingMembers) ...[
                const SizedBox(height: 16),
                const Text(
                  'Link to Family Member (Optional):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedUserId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Family Member',
                    border: OutlineInputBorder(),
                    hintText: 'Or leave blank for student without account',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                  menuMaxHeight: 300,
                  selectedItemBuilder: (BuildContext context) {
                    final items = <Widget>[
                      const Text(
                        'No account (create placeholder)',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ];
                    items.addAll(_familyMembers.map((member) {
                      return Text(
                        member.displayName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      );
                    }));
                    return items;
                  },
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'No account (create placeholder)',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    ..._familyMembers.map((member) {
                      return DropdownMenuItem<String>(
                        value: member.uid,
                        child: Text(
                          member.displayName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedUserId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Name *',
                  hintText: 'Enter student name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter student name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _gradeLevelController,
                decoration: const InputDecoration(
                  labelText: 'Grade Level',
                  hintText: 'e.g., Grade 5, Kindergarten',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _dateOfBirthController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  hintText: 'Select date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: _selectDateOfBirth,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              Text(
                'Subjects',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSubjects.map((subject) {
                  final isSelected = _selectedSubjects.contains(subject);
                  return FilterChip(
                    label: Text(subject),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSubjects.add(subject);
                        } else {
                          _selectedSubjects.remove(subject);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (_selectedSubjects.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  'Selected: ${_selectedSubjects.join(", ")}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
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
                      _saveStudent();
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
                      ? SizedBox(
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
                        : widget.student == null
                            ? 'Create Student'
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

