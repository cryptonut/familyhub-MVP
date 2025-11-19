import 'package:flutter/material.dart';
import '../../services/task_service.dart';
import '../../models/task.dart';
import 'add_edit_task_screen.dart';

class RefundNotificationDialog extends StatefulWidget {
  final String jobId;

  const RefundNotificationDialog({super.key, required this.jobId});

  @override
  State<RefundNotificationDialog> createState() => _RefundNotificationDialogState();
}

class _RefundNotificationDialogState extends State<RefundNotificationDialog> {
  final TaskService _taskService = TaskService();
  Task? _task;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    try {
      final tasks = await _taskService.getTasks();
      _task = tasks.firstWhere(
        (t) => t.id == widget.jobId,
        orElse: () => throw Exception('Job not found'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelJob() async {
    if (_task == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Job?'),
        content: Text('Are you sure you want to permanently cancel "${_task!.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm == true && _task != null) {
      try {
        await _taskService.deleteTask(_task!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error cancelling job: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _relistJob() async {
    if (_task == null) return;

    try {
      // Create a new job with the same details (but reset completion status)
      final newTask = Task(
        id: _task!.id, // Use same ID to replace the old one
        title: _task!.title,
        description: _task!.description,
        dueDate: _task!.dueDate,
        priority: _task!.priority,
        createdAt: DateTime.now(), // New creation date
        isCompleted: false,
        reward: _task!.reward,
        needsApproval: _task!.needsApproval,
        requiresClaim: _task!.requiresClaim,
        createdBy: _task!.createdBy,
        // Reset refund status
        isRefunded: false,
        refundReason: null,
        refundNote: null,
        refundedAt: null,
        // Reset completion/approval fields
        completedAt: null,
        approvedBy: null,
        approvedAt: null,
        claimedBy: null,
        claimStatus: null,
      );

      await _taskService.updateTask(newTask);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job relisted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error relisting job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editAndRelistJob() async {
    if (_task == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTaskScreen(task: _task),
      ),
    );

    if (result == true && mounted) {
      // After editing, also reset the refund status
      try {
        final updatedTask = await _taskService.getTasks();
        final task = updatedTask.firstWhere((t) => t.id == widget.jobId);
        final resetTask = task.copyWith(
          isRefunded: false,
          refundReason: null,
          refundNote: null,
          refundedAt: null,
          isCompleted: false,
          completedAt: null,
          approvedBy: null,
          approvedAt: null,
        );
        await _taskService.updateTask(resetTask);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job edited and relisted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_task == null) {
      return AlertDialog(
        title: const Text('Error'),
        content: const Text('Job not found'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.undo, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Job Refunded'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job: ${_task!.title}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (_task!.reward != null && _task!.reward! > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Refund Amount: \$${_task!.reward!.toStringAsFixed(2)} AUD',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'What would you like to do?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cancelJob,
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _relistJob,
                icon: const Icon(Icons.refresh),
                label: const Text('Relist Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _editAndRelistJob,
                icon: const Icon(Icons.edit),
                label: const Text('Edit & Relist Job'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

