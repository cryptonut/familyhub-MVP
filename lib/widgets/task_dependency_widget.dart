import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/task_dependency.dart';
import '../services/task_dependency_service.dart';
import '../services/task_service.dart';
import '../utils/app_theme.dart';
import '../widgets/toast_notification.dart';

/// Widget to display and manage task dependencies
class TaskDependencyWidget extends StatefulWidget {
  final String taskId;
  final String familyId;
  final Task currentTask;

  const TaskDependencyWidget({
    super.key,
    required this.taskId,
    required this.familyId,
    required this.currentTask,
  });

  @override
  State<TaskDependencyWidget> createState() => _TaskDependencyWidgetState();
}

class _TaskDependencyWidgetState extends State<TaskDependencyWidget> {
  final TaskDependencyService _dependencyService = TaskDependencyService();
  final TaskService _taskService = TaskService();
  List<TaskDependency> _dependencies = [];
  Map<String, Task> _dependencyTasks = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDependencies();
  }

  Future<void> _loadDependencies() async {
    setState(() => _isLoading = true);
    try {
      final dependencies = await _dependencyService.getDependencies(
        widget.taskId,
        widget.familyId,
      );

      // Load task details for each dependency
      final taskMap = <String, Task>{};
      for (var dep in dependencies) {
        try {
          final task = await _taskService.getTask(dep.dependsOnTaskId, widget.familyId);
          if (task != null) {
            taskMap[dep.dependsOnTaskId] = task;
          }
        } catch (e) {
          // Task might not exist anymore
        }
      }

      if (mounted) {
        setState(() {
          _dependencies = dependencies;
          _dependencyTasks = taskMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastNotification.error(context, 'Error loading dependencies: $e');
      }
    }
  }

  Future<void> _addDependency() async {
    // Show dialog to select a task
    final tasks = await _taskService.getTasks(widget.familyId);
    final availableTasks = tasks
        .where((t) => t.id != widget.taskId && !_dependencies.any((d) => d.dependsOnTaskId == t.id))
        .toList();

    if (availableTasks.isEmpty) {
      ToastNotification.info(context, 'No available tasks to add as dependency');
      return;
    }

    final selected = await showDialog<Task>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Dependency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableTasks.length,
            itemBuilder: (context, index) {
              final task = availableTasks[index];
              return ListTile(
                title: Text(task.title),
                subtitle: Text(task.description),
                trailing: task.isCompleted
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.radio_button_unchecked),
                onTap: () => Navigator.pop(context, task),
              );
            },
          ),
        ),
      ),
    );

    if (selected != null) {
      try {
        await _dependencyService.addDependency(
          widget.taskId,
          selected.id,
          DependencyType.hard,
          widget.familyId,
        );
        ToastNotification.success(context, 'Dependency added');
        _loadDependencies();
      } catch (e) {
        ToastNotification.error(context, 'Error adding dependency: $e');
      }
    }
  }

  Future<void> _removeDependency(TaskDependency dependency) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Dependency?'),
        content: const Text('Are you sure you want to remove this dependency?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dependencyService.removeDependency(
          widget.taskId,
          dependency.id,
          widget.familyId,
        );
        ToastNotification.success(context, 'Dependency removed');
        _loadDependencies();
      } catch (e) {
        ToastNotification.error(context, 'Error removing dependency: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isBlocked = widget.currentTask.status == TaskStatus.blocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Dependencies',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (isBlocked) ...[
                  const SizedBox(width: AppTheme.spacingSM),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Text(
                      'BLOCKED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addDependency,
              tooltip: 'Add Dependency',
            ),
          ],
        ),
        if (_dependencies.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Text(
              'No dependencies. This task can be started immediately.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          )
        else
          ..._dependencies.map((dep) {
            final depTask = _dependencyTasks[dep.dependsOnTaskId];
            return Card(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
              child: ListTile(
                leading: Icon(
                  depTask?.isCompleted == true
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: depTask?.isCompleted == true ? Colors.green : Colors.grey,
                ),
                title: Text(depTask?.title ?? 'Unknown Task'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (depTask != null)
                      Text(
                        depTask.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            dep.type.name.toUpperCase(),
                            style: const TextStyle(fontSize: 10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        if (depTask?.isCompleted == true) ...[
                          const SizedBox(width: 4),
                          Chip(
                            label: const Text(
                              'COMPLETE',
                              style: TextStyle(fontSize: 10, color: Colors.green),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removeDependency(dep),
                  tooltip: 'Remove Dependency',
                ),
              ),
            );
          }),
      ],
    );
  }
}

