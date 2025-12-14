import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

/// Screen for managing custody schedules
class CustodySchedulesScreen extends StatefulWidget {
  final String hubId;

  const CustodySchedulesScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<CustodySchedulesScreen> createState() => _CustodySchedulesScreenState();
}

class _CustodySchedulesScreenState extends State<CustodySchedulesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custody Schedules'),
      ),
      body: Center(
        child: EmptyState(
          icon: Icons.calendar_today_outlined,
          title: 'Custody Schedules',
          message: 'Manage custody schedules and exceptions',
          action: ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement create custody schedule
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Create custody schedule - Coming soon'),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Schedule'),
          ),
        ),
      ),
    );
  }
}

