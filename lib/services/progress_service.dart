import 'package:flutter/material.dart';
import '../core/services/logger_service.dart';

class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;
  ProgressService._internal();

  final Map<String, ProgressInfo> _activeProgress = {};

  void showProgress(
    BuildContext context, {
    required String taskId,
    required String message,
    double progress = 0.0,
    bool canCancel = false,
    VoidCallback? onCancel,
  }) {
    if (_activeProgress.containsKey(taskId)) {
      updateProgress(taskId, progress);
      return;
    }

    _activeProgress[taskId] = ProgressInfo(
      message: message,
      progress: progress,
      canCancel: canCancel,
      onCancel: onCancel,
    );

    _showProgressDialog(context, taskId);
  }

  void updateProgress(String taskId, double progress) {
    final info = _activeProgress[taskId];
    if (info != null) {
      _activeProgress[taskId] = info.copyWith(progress: progress);
      // Update dialog if shown
      Logger.debug('Progress updated: $taskId - ${(progress * 100).toStringAsFixed(1)}%', tag: 'ProgressService');
    }
  }

  void hideProgress(String taskId) {
    _activeProgress.remove(taskId);
    Logger.debug('Progress hidden: $taskId', tag: 'ProgressService');
  }

  void _showProgressDialog(BuildContext context, String taskId) {
    final info = _activeProgress[taskId];
    if (info == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProgressDialog(
        taskId: taskId,
        message: info.message,
        progress: info.progress,
        canCancel: info.canCancel,
        onCancel: () {
          info.onCancel?.call();
          hideProgress(taskId);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class ProgressInfo {
  final String message;
  final double progress;
  final bool canCancel;
  final VoidCallback? onCancel;

  ProgressInfo({
    required this.message,
    required this.progress,
    this.canCancel = false,
    this.onCancel,
  });

  ProgressInfo copyWith({
    String? message,
    double? progress,
    bool? canCancel,
    VoidCallback? onCancel,
  }) {
    return ProgressInfo(
      message: message ?? this.message,
      progress: progress ?? this.progress,
      canCancel: canCancel ?? this.canCancel,
      onCancel: onCancel ?? this.onCancel,
    );
  }
}

class _ProgressDialog extends StatefulWidget {
  final String taskId;
  final String message;
  final double progress;
  final bool canCancel;
  final VoidCallback? onCancel;

  const _ProgressDialog({
    required this.taskId,
    required this.message,
    required this.progress,
    required this.canCancel,
    this.onCancel,
  });

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.message,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: widget.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            '${(widget.progress * 100).toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall,
          ),
          if (widget.canCancel) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }
}

