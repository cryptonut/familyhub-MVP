import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../services/auth_service.dart';
import '../../services/family_wallet_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import 'package:uuid/uuid.dart';

class AddEditTaskScreen extends StatefulWidget {
  final Task? task;

  const AddEditTaskScreen({super.key, this.task});

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController();
  final _taskService = TaskService();
  final _authService = AuthService();
  final _familyWalletService = FamilyWalletService();
  final _auth = FirebaseAuth.instance;
  
  // Cache tasks for balance checking
  List<Task>? _cachedTasks;
  
  DateTime? _dueDate;
  String _priority = 'medium';
  final List<String> _priorities = ['low', 'medium', 'high'];
  double? _reward;
  bool _needsApproval = false;
  bool _requiresClaim = false;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _dueDate = widget.task!.dueDate;
      _priority = widget.task!.priority;
      _reward = widget.task!.reward;
      _needsApproval = widget.task!.needsApproval;
      _requiresClaim = widget.task!.requiresClaim;
      if (_reward != null) {
        _rewardController.text = _reward!.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Ensure we have a valid ID - if editing, use the existing task's ID
      final taskId = widget.task?.id;
      if (taskId == null && widget.task != null) {
        throw Exception('Cannot update: Task ID is missing');
      }
      
      // Parse reward
      double? reward;
      if (_rewardController.text.trim().isNotEmpty) {
        final rewardValue = double.tryParse(_rewardController.text.trim());
        if (rewardValue != null && rewardValue > 0) {
          reward = rewardValue;
          
          // Get all tasks to pass to canCreateJobWithReward (to avoid circular dependency)
          if (_cachedTasks == null) {
            _cachedTasks = await _taskService.getTasks();
          }
          
          // Check if user can create job with this reward (checks role and balance)
          final canCreate = await _familyWalletService.canCreateJobWithReward(rewardValue, _cachedTasks!);
          
          if (!canCreate['canCreate'] as bool) {
            throw Exception(canCreate['reason'] as String);
          }
          
          // Show info if Banker will go negative
          if (canCreate['willGoNegative'] == true) {
            final negativeAmount = canCreate['negativeAmount'] as double? ?? 0.0;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Creating this job will mint \$${rewardValue.toStringAsFixed(2)} into family wallet. '
                    'Your balance will go to -\$${negativeAmount.toStringAsFixed(2)}',
                  ),
                  duration: const Duration(seconds: 4),
                  backgroundColor: Colors.blue,
                ),
              );
            }
          }
          
          // Auto-set needsApproval to true if reward is set
          if (!_needsApproval) {
            _needsApproval = true;
          }
        }
      }
      
      final currentUserId = _auth.currentUser?.uid;
      
      final task = Task(
        id: taskId ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        isCompleted: widget.task?.isCompleted ?? false,
        completedAt: widget.task?.completedAt,
        reward: reward,
        needsApproval: _needsApproval,
        requiresClaim: _requiresClaim,
        createdBy: widget.task?.createdBy ?? currentUserId,
        claimedBy: widget.task?.claimedBy,
        claimStatus: widget.task?.claimStatus,
        approvedBy: widget.task?.approvedBy,
        approvedAt: widget.task?.approvedAt,
      );

      debugPrint('AddEditTaskScreen._saveTask: widget.task is ${widget.task != null ? "not null" : "null"}');
      debugPrint('AddEditTaskScreen._saveTask: Task ID is ${task.id}');
      
      if (widget.task != null) {
        debugPrint('AddEditTaskScreen._saveTask: Calling updateTask');
        await _taskService.updateTask(task);
      } else {
        debugPrint('AddEditTaskScreen._saveTask: Calling addTask');
        await _taskService.addTask(task);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        String detailedError = 'Error: $errorMessage';
        
        // Check for specific Firestore errors
        if (errorMessage.contains('permission-denied') || 
            errorMessage.contains('PERMISSION_DENIED')) {
          detailedError = 'Permission denied.\n\n'
              'Please check Firestore security rules:\n'
              '1. Go to Firebase Console > Firestore Database > Rules\n'
              '2. Make sure rules allow authenticated users\n'
              '3. Click "Publish" to save rules';
        } else if (errorMessage.contains('not-found') || 
                   errorMessage.contains('NOT_FOUND') ||
                   errorMessage.contains('UNAVAILABLE')) {
          detailedError = 'Firestore database not accessible.\n\n'
              'Please verify:\n'
              '1. Firestore Database is created in Firebase Console\n'
              '2. Security rules are published (not just saved)\n'
              '3. You are logged in\n'
              '4. Check browser console (F12) for details';
        } else if (errorMessage.contains('unavailable') || 
                   errorMessage.contains('UNAVAILABLE')) {
          detailedError = 'Firestore is unavailable.\n\n'
              'This might be a network issue or the database is not set up.\n'
              'Check Firebase Console to verify Firestore exists.';
        }
        
        // Show both detailed message and original error for debugging
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detailedError),
                const SizedBox(height: 8),
                Text(
                  'Original error: ${e.toString()}',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task != null ? 'Edit Job' : 'New Job'),
        actions: [
          TextButton(
            onPressed: _saveTask,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Due Date'),
              subtitle: Text(
                _dueDate != null
                    ? app_date_utils.AppDateUtils.formatDate(_dueDate!)
                    : 'No due date',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _selectDueDate,
              ),
              onTap: _selectDueDate,
            ),
            const SizedBox(height: 8),
            const Text(
              'Priority',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: _priorities.map((priority) {
                return ButtonSegment<String>(
                  value: priority,
                  label: Text(priority.toUpperCase()),
                );
              }).toList(),
              selected: {_priority},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _priority = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _rewardController,
              decoration: const InputDecoration(
                labelText: 'Reward (AUD)',
                hintText: '0.00',
                prefixText: '\$',
                border: OutlineInputBorder(),
                helperText: 'Optional reward amount in Australian Dollars',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                setState(() {
                  final rewardValue = double.tryParse(value);
                  if (rewardValue != null && rewardValue > 0) {
                    _reward = rewardValue;
                    // Auto-check needsApproval if reward is set
                    if (!_needsApproval) {
                      _needsApproval = true;
                    }
                  } else {
                    _reward = null;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Needs Approval'),
              subtitle: Text(
                _reward != null && _reward! > 0
                    ? 'Paid jobs require approval by default'
                    : 'Job completion requires approval from creator',
              ),
              value: _needsApproval,
              onChanged: _reward != null && _reward! > 0
                  ? null // Disabled if reward is set (always needs approval)
                  : (value) {
                      setState(() {
                        _needsApproval = value ?? false;
                      });
                    },
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Requires Claim'),
              subtitle: const Text(
                'Job must be claimed before it can be completed',
              ),
              value: _requiresClaim,
              onChanged: (value) {
                setState(() {
                  _requiresClaim = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

