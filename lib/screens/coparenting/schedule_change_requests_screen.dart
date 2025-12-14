import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

/// Screen for managing schedule change requests
class ScheduleChangeRequestsScreen extends StatefulWidget {
  final String hubId;

  const ScheduleChangeRequestsScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<ScheduleChangeRequestsScreen> createState() => _ScheduleChangeRequestsScreenState();
}

class _ScheduleChangeRequestsScreenState extends State<ScheduleChangeRequestsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Change Requests'),
      ),
      body: Center(
        child: EmptyState(
          icon: Icons.swap_horiz_outlined,
          title: 'Schedule Change Requests',
          message: 'Request and manage schedule changes',
          action: ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement create schedule change request
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Create schedule change request - Coming soon'),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Request Change'),
          ),
        ),
      ),
    );
  }
}

