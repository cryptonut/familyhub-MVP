import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/task.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../services/auth_service.dart';
import '../../widgets/task_dependency_widget.dart';
import 'refund_job_dialog.dart';
import 'package:intl/intl.dart';

class ViewTaskScreen extends StatefulWidget {
  final Task task;

  const ViewTaskScreen({super.key, required this.task});

  @override
  State<ViewTaskScreen> createState() => _ViewTaskScreenState();
}

class _ViewTaskScreenState extends State<ViewTaskScreen> {
  final AuthService _authService = AuthService();
  String? _familyId;

  @override
  void initState() {
    super.initState();
    _loadFamilyId();
  }

  Future<void> _loadFamilyId() async {
    final userModel = await _authService.getCurrentUserModel();
    if (mounted) {
      setState(() {
        _familyId = userModel?.familyId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Description
            if (task.description.isNotEmpty) ...[
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                task.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Status
            _buildInfoRow(
              'Status',
              task.isCompleted
                  ? (task.isAwaitingApproval
                      ? 'Completed - Awaiting Approval'
                      : 'Completed')
                  : 'Active',
              task.isCompleted && !task.isAwaitingApproval
                  ? Colors.green
                  : task.isAwaitingApproval
                      ? Colors.orange
                      : Colors.blue,
            ),
            
            // Priority
            _buildInfoRow(
              'Priority',
              task.priority.toUpperCase(),
              _getPriorityColor(task.priority),
            ),
            
            // Due Date
            if (task.dueDate != null)
              _buildInfoRow(
                'Due Date',
                dateFormat.format(task.dueDate!),
                task.dueDate!.isBefore(DateTime.now()) && !task.isCompleted
                    ? Colors.red
                    : Colors.grey[700]!,
              ),
            
            // Created Date
            _buildInfoRow(
              'Created',
              '${dateFormat.format(task.createdAt)} at ${timeFormat.format(task.createdAt)}',
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            
            // Completed Date
            if (task.completedAt != null)
              _buildInfoRow(
                'Completed',
                '${dateFormat.format(task.completedAt!)} at ${timeFormat.format(task.completedAt!)}',
                Colors.green,
              ),
            
            // Reward
            if (task.reward != null && task.reward! > 0)
              _buildInfoRow(
                'Reward',
                '\$${task.reward!.toStringAsFixed(2)} AUD',
                Colors.green,
              ),
            
            // Claim Status
            if (task.requiresClaim) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Requires Claim',
                'Yes',
                Colors.orange,
              ),
            ],
            
            if (task.claimedBy != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Claimed By',
                task.claimStatus == 'approved'
                    ? 'User ID: ${task.claimedBy}'
                    : task.claimStatus == 'pending'
                        ? 'User ID: ${task.claimedBy} (Pending)'
                        : 'User ID: ${task.claimedBy}',
                task.claimStatus == 'approved'
                    ? Colors.green
                    : task.claimStatus == 'pending'
                        ? Colors.orange
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ],
            
            // Approval Status
            if (task.needsApproval) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Approval Status',
                task.isAwaitingApproval
                    ? 'Awaiting Approval'
                    : task.approvedBy != null
                        ? 'Approved'
                        : 'Not Approved',
                task.isAwaitingApproval
                    ? Colors.orange
                    : task.approvedBy != null
                        ? Colors.green
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ],
            
            if (task.approvedBy != null && task.approvedAt != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Approved By',
                'User ID: ${task.approvedBy}',
                Colors.green,
              ),
              _buildInfoRow(
                'Approved At',
                '${dateFormat.format(task.approvedAt!)} at ${timeFormat.format(task.approvedAt!)}',
                Colors.green,
              ),
            ],
            
            // Refund Status
            if (task.isRefunded == true) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.undo, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Refunded',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    if (task.refundReason != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Reason',
                        task.refundReason!,
                        Colors.orange.shade700,
                      ),
                    ],
                    if (task.refundNote != null && task.refundNote!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Note',
                        task.refundNote!,
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ],
                    if (task.refundedAt != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Refunded At',
                        '${dateFormat.format(task.refundedAt!)} at ${timeFormat.format(task.refundedAt!)}',
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            
            // Dependencies
            if (_familyId != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              TaskDependencyWidget(
                taskId: task.id,
                familyId: _familyId!,
                currentTask: task,
              ),
            ],
            
            // Refund Button (for completed, non-refunded jobs with rewards)
            if (task.isCompleted && 
                !task.isAwaitingApproval && 
                task.isRefunded != true &&
                task.reward != null && 
                task.reward! > 0) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await showDialog(
                      context: context,
                      builder: (context) => RefundJobDialog(task: task),
                    );
                    if (result == true && context.mounted) {
                      // Refresh or navigate back
                      Navigator.pop(context, true);
                    }
                  },
                  icon: const Icon(Icons.undo),
                  label: const Text('Refund Job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor,
                fontWeight: valueColor == Colors.green || valueColor == Colors.red
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    }
  }
}

