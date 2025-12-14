import 'package:flutter/material.dart';
import '../../models/event_template.dart';
import '../../services/event_template_service.dart';
import '../../widgets/toast_notification.dart';
import '../../widgets/ui_components.dart';
import '../../utils/app_theme.dart';
import 'create_edit_template_screen.dart';

/// Screen for managing event templates
class EventTemplatesScreen extends StatefulWidget {
  const EventTemplatesScreen({super.key});

  @override
  State<EventTemplatesScreen> createState() => _EventTemplatesScreenState();
}

class _EventTemplatesScreenState extends State<EventTemplatesScreen> {
  final EventTemplateService _templateService = EventTemplateService();
  List<EventTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final templates = await _templateService.getTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastNotification.error(context, 'Error loading templates: $e');
      }
    }
  }

  Future<void> _deleteTemplate(EventTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template?'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
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
        await _templateService.deleteTemplate(template.id);
        ToastNotification.success(context, 'Template deleted');
        _loadTemplates();
      } catch (e) {
        ToastNotification.error(context, 'Error deleting template: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateEditTemplateScreen(),
                ),
              );
              if (result == true) {
                _loadTemplates();
              }
            },
            tooltip: 'Create Template',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTemplates,
              child: _templates.isEmpty
                  ? EmptyState(
                      icon: Icons.bookmark_border,
                      title: 'No Templates Yet',
                      message: 'Create templates to quickly add recurring events',
                      action: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Create Template'),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateEditTemplateScreen(),
                            ),
                          );
                          if (result == true) {
                            _loadTemplates();
                          }
                        },
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final template = _templates[index];
                        return ModernCard(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: template.color ?? Colors.blue,
                              child: const Icon(Icons.event, color: Colors.white),
                            ),
                            title: Text(template.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(template.title),
                                if (template.location != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        template.location!,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                                if (template.startTime != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${template.startTime!.hour.toString().padLeft(2, '0')}:${template.startTime!.minute.toString().padLeft(2, '0')}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                  onTap: () {
                                    Future.delayed(const Duration(milliseconds: 100), () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CreateEditTemplateScreen(template: template),
                                        ),
                                      );
                                      if (result == true) {
                                        _loadTemplates();
                                      }
                                    });
                                  },
                                ),
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete, size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                  onTap: () {
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      _deleteTemplate(template);
                                    });
                                  },
                                ),
                              ],
                            ),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateEditTemplateScreen(template: template),
                                ),
                              );
                              if (result == true) {
                                _loadTemplates();
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

