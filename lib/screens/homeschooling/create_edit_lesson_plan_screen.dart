import 'package:flutter/material.dart';
import '../../models/lesson_plan.dart';
import '../../models/educational_resource.dart';
import '../../services/homeschooling_service.dart';
import '../../utils/app_theme.dart';

/// Screen for creating or editing a lesson plan
class CreateEditLessonPlanScreen extends StatefulWidget {
  final String hubId;
  final List<String> availableSubjects;
  final LessonPlan? lessonPlan;

  const CreateEditLessonPlanScreen({
    super.key,
    required this.hubId,
    required this.availableSubjects,
    this.lessonPlan,
  });

  @override
  State<CreateEditLessonPlanScreen> createState() => _CreateEditLessonPlanScreenState();
}

class _CreateEditLessonPlanScreenState extends State<CreateEditLessonPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final List<String> _learningObjectives = [];
  final List<String> _selectedResourceIds = []; // Store resource IDs
  final TextEditingController _objectiveController = TextEditingController();
  final HomeschoolingService _service = HomeschoolingService();
  List<EducationalResource> _availableResources = []; // Cache of all resources for display
  String? _selectedSubject;
  DateTime? _scheduledDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.lessonPlan != null) {
      _titleController.text = widget.lessonPlan!.title;
      _descriptionController.text = widget.lessonPlan!.description ?? '';
      _selectedSubject = widget.lessonPlan!.subject;
      _scheduledDate = widget.lessonPlan!.scheduledDate;
      _durationController.text = widget.lessonPlan!.estimatedDurationMinutes.toString();
      _learningObjectives.addAll(widget.lessonPlan!.learningObjectives);
      _selectedResourceIds.addAll(widget.lessonPlan!.resources); // Resources are stored as IDs
    } else if (widget.availableSubjects.isNotEmpty) {
      _selectedSubject = widget.availableSubjects.first;
    }
    _durationController.text = '60';
    _loadResources(); // Load available resources for selection
  }

  Future<void> _loadResources() async {
    try {
      final resources = await _service.getEducationalResources(hubId: widget.hubId);
      if (mounted) {
        setState(() {
          _availableResources = resources;
        });
      }
    } catch (e) {
      // Silently fail - resources will just be empty
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _objectiveController.dispose();
    super.dispose();
  }

  Future<void> _selectScheduledDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDate ?? DateTime.now()),
    );
    if (pickedTime == null || !mounted) return;

    final dateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (mounted) {
      setState(() {
        _scheduledDate = dateTime;
      });
    }
  }

  void _addObjective() {
    if (_objectiveController.text.trim().isNotEmpty) {
      setState(() {
        _learningObjectives.add(_objectiveController.text.trim());
        _objectiveController.clear();
      });
    }
  }

  void _removeObjective(int index) {
    setState(() {
      _learningObjectives.removeAt(index);
    });
  }

  Future<void> _showResourceSelectionDialog() async {
    // Create a copy of selected IDs for the dialog state
    final Set<String> tempSelectedIds = Set<String>.from(_selectedResourceIds);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Select Resources from Library'),
            content: SizedBox(
              width: double.maxFinite,
              child: _availableResources.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No resources available. Add resources to the Resource Library first.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _availableResources.length,
                      itemBuilder: (context, index) {
                        final resource = _availableResources[index];
                        final isSelected = tempSelectedIds.contains(resource.id);
                        return CheckboxListTile(
                          title: Text(resource.title),
                          subtitle: resource.description != null
                              ? Text(
                                  resource.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          value: isSelected,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                tempSelectedIds.add(resource.id);
                              } else {
                                tempSelectedIds.remove(resource.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedResourceIds.clear();
                    _selectedResourceIds.addAll(tempSelectedIds);
                  });
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeResource(String resourceId) {
    setState(() {
      _selectedResourceIds.remove(resourceId);
    });
  }

  String _getResourceTitle(String resourceId) {
    try {
      return _availableResources.firstWhere((r) => r.id == resourceId).title;
    } catch (e) {
      return resourceId; // Fallback to ID if not found
    }
  }

  Future<void> _saveLessonPlan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final duration = int.tryParse(_durationController.text) ?? 60;

      if (widget.lessonPlan == null) {
        await _service.createLessonPlan(
          hubId: widget.hubId,
          subject: _selectedSubject!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          learningObjectives: _learningObjectives,
          resources: _selectedResourceIds,
          scheduledDate: _scheduledDate,
          estimatedDurationMinutes: duration,
        );
      } else {
        // Update lesson plan
        await _service.updateLessonPlan(
          hubId: widget.hubId,
          lessonPlanId: widget.lessonPlan!.id,
          subject: _selectedSubject,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          learningObjectives: _learningObjectives,
          resources: _selectedResourceIds,
          scheduledDate: _scheduledDate,
          estimatedDurationMinutes: duration,
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
          SnackBar(content: Text('Error saving lesson plan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonPlan == null ? 'Create Lesson Plan' : 'Edit Lesson Plan'),
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
              DropdownButtonFormField<String>(
                value: _selectedSubject,
                decoration: const InputDecoration(
                  labelText: 'Subject *',
                  border: OutlineInputBorder(),
                ),
                items: widget.availableSubjects.map((subject) {
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
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Enter lesson plan title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter lesson plan title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter lesson plan description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              InkWell(
                onTap: _selectScheduledDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Scheduled Date & Time',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(
                    _scheduledDate != null
                        ? '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year} '
                            '${_scheduledDate!.hour.toString().padLeft(2, '0')}:${_scheduledDate!.minute.toString().padLeft(2, '0')}'
                        : 'Select date and time (optional)',
                    style: TextStyle(
                      color: _scheduledDate != null
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                  hintText: '60',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              Text(
                'Learning Objectives',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _objectiveController,
                      decoration: const InputDecoration(
                        hintText: 'Add learning objective',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onFieldSubmitted: (_) => _addObjective(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addObjective,
                  ),
                ],
              ),
              if (_learningObjectives.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingMD),
                ..._learningObjectives.asMap().entries.map((entry) {
                  return ListTile(
                    title: Text(entry.value),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeObjective(entry.key),
                    ),
                  );
                }),
              ],
              const SizedBox(height: AppTheme.spacingLG),
              Row(
                children: [
                  Text(
                    'Resources',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showResourceSelectionDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Select from Library'),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              if (_selectedResourceIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'No resources selected. Resources must be added to the Resource Library first.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                )
              else
                ..._selectedResourceIds.map((resourceId) {
                  return ListTile(
                    leading: const Icon(Icons.library_books),
                    title: Text(_getResourceTitle(resourceId)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeResource(resourceId),
                    ),
                  );
                }),
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
                      _saveLessonPlan();
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : widget.lessonPlan == null
                            ? 'Create Lesson Plan'
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

