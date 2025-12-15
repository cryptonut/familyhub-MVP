import 'package:flutter/material.dart';
import '../../models/coparenting_message_template.dart';
import '../../services/coparenting_service.dart';
import '../../utils/app_theme.dart';

class CreateEditTemplateScreen extends StatefulWidget {
  final String hubId;
  final CoparentingMessageTemplate? template;

  const CreateEditTemplateScreen({
    super.key,
    required this.hubId,
    this.template,
  });

  @override
  State<CreateEditTemplateScreen> createState() =>
      _CreateEditTemplateScreenState();
}

class _CreateEditTemplateScreenState extends State<CreateEditTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final CoparentingService _service = CoparentingService();
  MessageCategory _selectedCategory = MessageCategory.general;

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _titleController.text = widget.template!.title;
      _contentController.text = widget.template!.content;
      _selectedCategory = widget.template!.category;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _service.createMessageTemplate(
        hubId: widget.hubId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _selectedCategory,
      );

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
        title: Text(widget.template == null ? 'Create Template' : 'Edit Template'),
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
              DropdownButtonFormField<MessageCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                items: MessageCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Message Content *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter the template message...',
                ),
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Content is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: ElevatedButton.icon(
            onPressed: _saveTemplate,
            icon: const Icon(Icons.check),
            label: Text(widget.template == null ? 'Create Template' : 'Save Changes'),
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

