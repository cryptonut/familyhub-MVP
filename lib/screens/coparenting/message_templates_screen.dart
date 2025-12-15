import 'package:flutter/material.dart';
import '../../models/coparenting_message_template.dart';
import '../../services/coparenting_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'create_edit_template_screen.dart';

class MessageTemplatesScreen extends StatefulWidget {
  final String hubId;

  const MessageTemplatesScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<MessageTemplatesScreen> createState() => _MessageTemplatesScreenState();
}

class _MessageTemplatesScreenState extends State<MessageTemplatesScreen> {
  final CoparentingService _service = CoparentingService();
  List<CoparentingMessageTemplate> _templates = [];
  bool _isLoading = true;
  MessageCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final templates = await _service.getMessageTemplates(
        hubId: widget.hubId,
        category: _selectedCategory,
      );
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Templates'),
        actions: [
          if (_selectedCategory != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() => _selectedCategory = null);
                _loadTemplates();
              },
            ),
          PopupMenuButton<MessageCategory>(
            icon: const Icon(Icons.filter_list),
            onSelected: (category) {
              setState(() => _selectedCategory = category);
              _loadTemplates();
            },
            itemBuilder: (context) => MessageCategory.values.map((category) {
              return PopupMenuItem(
                value: category,
                child: Text(category.displayName),
              );
            }).toList(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTemplates,
              child: _templates.isEmpty
                  ? EmptyState(
                      icon: Icons.message,
                      title: 'No Templates Yet',
                      message: 'Create message templates for common communications',
                      action: FloatingActionButton.extended(
                        onPressed: () => _createTemplate(),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Template'),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final template = _templates[index];
                        return ModernCard(
                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      template.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(template.category.displayName),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingSM),
                              Text(
                                template.content,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: AppTheme.spacingSM),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _useTemplate(template),
                                    icon: const Icon(Icons.send, size: 16),
                                    label: const Text('Use'),
                                  ),
                                  if (!template.isDefault)
                                    TextButton.icon(
                                      onPressed: () => _deleteTemplate(template),
                                      icon: const Icon(Icons.delete, size: 16),
                                      label: const Text('Delete'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTemplate(),
        icon: const Icon(Icons.add),
        label: const Text('Create Template'),
      ),
    );
  }

  Future<void> _createTemplate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditTemplateScreen(hubId: widget.hubId),
      ),
    );

    if (result == true) {
      _loadTemplates();
    }
  }

  Future<void> _useTemplate(CoparentingMessageTemplate template) async {
    Navigator.pop(context, template.content);
  }

  Future<void> _deleteTemplate(CoparentingMessageTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteMessageTemplate(
          hubId: widget.hubId,
          templateId: template.id,
        );
        _loadTemplates();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

