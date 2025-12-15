import 'package:flutter/material.dart';
import '../../models/educational_resource.dart';
import '../../services/homeschooling_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

class CreateEditResourceScreen extends StatefulWidget {
  final String hubId;
  final EducationalResource? resource;

  const CreateEditResourceScreen({
    super.key,
    required this.hubId,
    this.resource,
  });

  @override
  State<CreateEditResourceScreen> createState() =>
      _CreateEditResourceScreenState();
}

class _CreateEditResourceScreenState extends State<CreateEditResourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final HomeschoolingService _service = HomeschoolingService();

  ResourceType _selectedType = ResourceType.link;
  String? _selectedGradeLevel;
  final List<String> _selectedSubjects = [];
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.resource != null) {
      _titleController.text = widget.resource!.title;
      _descriptionController.text = widget.resource!.description ?? '';
      _urlController.text = widget.resource!.url ?? '';
      _selectedType = widget.resource!.type;
      _selectedGradeLevel = widget.resource!.gradeLevel;
      _selectedSubjects.addAll(widget.resource!.subjects);
      _tags.addAll(widget.resource!.tags);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveResource() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (widget.resource == null) {
        await _service.createEducationalResource(
          hubId: widget.hubId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          type: _selectedType,
          url: _urlController.text.trim().isEmpty
              ? null
              : _urlController.text.trim(),
          subjects: _selectedSubjects,
          gradeLevel: _selectedGradeLevel,
          tags: _tags,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resource == null ? 'Add Resource' : 'Edit Resource'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              DropdownButtonFormField<ResourceType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Resource Type *',
                  border: OutlineInputBorder(),
                ),
                items: ResourceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              if (_selectedType == ResourceType.link) ...[
                const SizedBox(height: AppTheme.spacingMD),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL *',
                    border: OutlineInputBorder(),
                    hintText: 'https://example.com',
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (_selectedType == ResourceType.link &&
                        (value == null || value.trim().isEmpty)) {
                      return 'URL is required for links';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Grade Level (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Grade 5',
                ),
                onChanged: (value) => _selectedGradeLevel =
                    value.trim().isEmpty ? null : value.trim(),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              const Text(
                'Subjects (tap to add)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Wrap(
                spacing: AppTheme.spacingXS,
                children: ['Math', 'Science', 'English', 'History', 'Art']
                    .map((subject) => FilterChip(
                          label: Text(subject),
                          selected: _selectedSubjects.contains(subject),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSubjects.add(subject);
                              } else {
                                _selectedSubjects.remove(subject);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: ElevatedButton.icon(
            onPressed: _saveResource,
            icon: const Icon(Icons.check),
            label: Text(widget.resource == null ? 'Create Resource' : 'Save Changes'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

