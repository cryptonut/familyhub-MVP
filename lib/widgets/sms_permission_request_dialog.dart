import 'package:flutter/material.dart';
import 'dart:io';

/// Dialog for requesting SMS permissions with explanation
class SmsPermissionRequestDialog extends StatelessWidget {
  final VoidCallback? onRequest;
  final VoidCallback? onCancel;

  const SmsPermissionRequestDialog({
    super.key,
    this.onRequest,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.sms, color: Colors.blue),
          SizedBox(width: 12),
          Text('SMS Permissions Required'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To send and receive SMS messages, we need the following permissions:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _PermissionItem(
            icon: Icons.send,
            title: 'Send SMS',
            description: 'Allows you to send SMS messages from within the app',
          ),
          SizedBox(height: 12),
          _PermissionItem(
            icon: Icons.inbox,
            title: 'Read SMS',
            description: 'Allows you to view SMS conversations in the app',
          ),
          SizedBox(height: 12),
          _PermissionItem(
            icon: Icons.contacts,
            title: 'Read Contacts',
            description: 'Helps match phone numbers to your contacts',
          ),
          SizedBox(height: 16),
          Text(
            'Your SMS content is stored only on your device. Only conversation metadata is synced to your account for cross-device access.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancel?.call();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onRequest?.call();
          },
          child: const Text('Grant Permissions'),
        ),
      ],
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

