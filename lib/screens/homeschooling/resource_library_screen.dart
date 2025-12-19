import 'package:flutter/material.dart';
import '../../models/educational_resource.dart';
import '../../services/homeschooling_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'create_edit_resource_screen.dart';
import 'resource_viewer_screen.dart';

class ResourceLibraryScreen extends StatefulWidget {
  final String hubId;

  const ResourceLibraryScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<ResourceLibraryScreen> createState() => _ResourceLibraryScreenState();
}

class _ResourceLibraryScreenState extends State<ResourceLibraryScreen> {
  final HomeschoolingService _service = HomeschoolingService();
  List<EducationalResource> _resources = [];
  bool _isLoading = true;
  String? _selectedSubject;
  ResourceType? _selectedType;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    setState(() => _isLoading = true);
    try {
      final resources = await _service.getEducationalResources(
        hubId: widget.hubId,
        subject: _selectedSubject,
        type: _selectedType,
      );
      setState(() {
        _resources = resources;
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
        title: const Text('Resource Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadResources,
              child: _resources.isEmpty
                  ? EmptyState(
                      icon: Icons.library_books,
                      title: 'No Resources',
                      message: _getEmptyStateMessage(),
                      action: (_selectedSubject == null && _selectedType == null)
                          ? FloatingActionButton.extended(
                              onPressed: () => _createResource(),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Resource'),
                            )
                          : null,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      itemCount: _resources.length,
                      itemBuilder: (context, index) {
                        final resource = _resources[index];
                        return ModernCard(
                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getResourceIcon(resource.type),
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppTheme.spacingSM),
                                  Expanded(
                                    child: Text(
                                      resource.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (resource.description != null) ...[
                                const SizedBox(height: AppTheme.spacingSM),
                                Text(
                                  resource.description!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              if (resource.subjects.isNotEmpty) ...[
                                const SizedBox(height: AppTheme.spacingSM),
                                Wrap(
                                  spacing: AppTheme.spacingXS,
                                  children: resource.subjects
                                      .map((subject) => Chip(
                                            label: Text(subject),
                                            padding: EdgeInsets.zero,
                                            materialTapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ))
                                      .toList(),
                                ),
                              ],
                              if (resource.url != null || resource.fileUrl != null) ...[
                                const SizedBox(height: AppTheme.spacingSM),
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ResourceViewerScreen(
                                              resource: resource,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.open_in_new, size: 16),
                                      label: const Text('Open'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createResource(),
        icon: const Icon(Icons.add),
        label: const Text('Add Resource'),
      ),
    );
  }

  String _getEmptyStateMessage() {
    // Provide context-aware empty state messages based on active filters
    if (_selectedSubject != null && _selectedType != null) {
      return 'No ${_getResourceTypeLabel(_selectedType!)} resources found for ${_selectedSubject}';
    } else if (_selectedSubject != null) {
      return 'No resources found for ${_selectedSubject}';
    } else if (_selectedType != null) {
      return 'No ${_getResourceTypeLabel(_selectedType!)} resources found';
    } else {
      return 'Add educational resources to share with students';
    }
  }

  String _getResourceTypeLabel(ResourceType type) {
    switch (type) {
      case ResourceType.link:
        return 'link';
      case ResourceType.document:
        return 'document';
      case ResourceType.video:
        return 'video';
      case ResourceType.image:
        return 'image';
      case ResourceType.other:
        return '';
    }
  }

  IconData _getResourceIcon(ResourceType type) {
    switch (type) {
      case ResourceType.link:
        return Icons.link;
      case ResourceType.document:
        return Icons.description;
      case ResourceType.video:
        return Icons.video_library;
      case ResourceType.image:
        return Icons.image;
      case ResourceType.other:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _createResource() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditResourceScreen(hubId: widget.hubId),
      ),
    );

    if (result == true) {
      _loadResources();
    }
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Resources'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subject filter would go here
            // Type filter would go here
            const Text('Filter options coming soon'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedSubject = null;
                _selectedType = null;
              });
              Navigator.pop(context);
              _loadResources();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

