import 'package:flutter/material.dart';
import '../../models/event_template.dart';
import '../../services/event_template_service.dart';
import '../../widgets/toast_notification.dart';
import '../../utils/app_theme.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Screen for creating or editing event templates
class CreateEditTemplateScreen extends StatefulWidget {
  final EventTemplate? template;

  const CreateEditTemplateScreen({
    super.key,
    this.template,
  });

  @override
  State<CreateEditTemplateScreen> createState() => _CreateEditTemplateScreenState();
}

class _CreateEditTemplateScreenState extends State<CreateEditTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final EventTemplateService _templateService = EventTemplateService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  Color? _selectedColor;
  String? _recurrenceRule;
  List<String> _selectedInvitees = [];
  bool _isSaving = false;

  final List<Color> _colors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.cyan,
  ];

  final List<String> _recurrenceOptions = [
    'daily',
    'weekly',
    'monthly',
    'yearly',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!.name;
      _titleController.text = widget.template!.title;
      _descriptionController.text = widget.template!.description ?? '';
      _locationController.text = widget.template!.location ?? '';
      _startTime = widget.template!.startTime;
      _endTime = widget.template!.endTime;
      _selectedColor = widget.template!.color;
      _recurrenceRule = widget.template!.recurrenceRule;
      _selectedInvitees = List<String>.from(widget.template!.defaultInvitees);
    } else {
      _selectedColor = _colors[0];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final template = EventTemplate(
        id: widget.template?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        color: _selectedColor,
        recurrenceRule: _recurrenceRule,
        defaultInvitees: _selectedInvitees,
        createdBy: userId,
        createdAt: widget.template?.createdAt ?? DateTime.now(),
      );

      if (widget.template != null) {
        await _templateService.updateTemplate(template);
        ToastNotification.success(context, 'Template updated');
      } else {
        await _templateService.createTemplate(template);
        ToastNotification.success(context, 'Template created');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ToastNotification.error(context, 'Error saving template: $e');
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
    );

    if (selected != null) {
      setState(() {
        if (isStart) {
          _startTime = selected;
        } else {
          _endTime = selected;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.template != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Template' : 'Create Template'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveTemplate,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Template Name *',
                  hintText: 'e.g., Weekly Family Meeting',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a template name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title *',
                  hintText: 'e.g., Family Meeting',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an event title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Optional location',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              
              // Time Selection
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTime(true),
                      icon: const Icon(Icons.access_time),
                      label: Text(_startTime != null
                          ? 'Start: ${_startTime!.format(context)}'
                          : 'Set Start Time'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTime(false),
                      icon: const Icon(Icons.access_time),
                      label: Text(_endTime != null
                          ? 'End: ${_endTime!.format(context)}'
                          : 'Set End Time'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),

              // Color Selection
              Text(
                'Color',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Wrap(
                spacing: AppTheme.spacingSM,
                children: _colors.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 24)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacingMD),

              // Recurrence
              DropdownButtonFormField<String>(
                value: _recurrenceRule,
                decoration: const InputDecoration(
                  labelText: 'Recurrence (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ..._recurrenceOptions.map((option) => DropdownMenuItem(
                        value: option,
                        child: Text(option.toUpperCase()),
                      )),
                ],
                onChanged: (value) => setState(() => _recurrenceRule = value),
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTemplate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'Update Template' : 'Create Template'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

