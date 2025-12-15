import 'package:flutter/material.dart';
import '../../services/coparenting_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'communication_log_screen.dart';

class MediationSupportScreen extends StatefulWidget {
  final String hubId;

  const MediationSupportScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<MediationSupportScreen> createState() => _MediationSupportScreenState();
}

class _MediationSupportScreenState extends State<MediationSupportScreen> {
  final CoparentingService _service = CoparentingService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mediation Support'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documentation & Records',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              'Export communication logs, expense history, and schedule changes for legal or mediation purposes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingLG),
            ModernCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunicationLogScreen(
                      hubId: widget.hubId,
                    ),
                  ),
                );
              },
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Row(
                children: [
                  Icon(
                    Icons.message,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Communication Log',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View and export all messages',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            ModernCard(
              onTap: () => _exportExpenses(),
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expense History',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Export expense records',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.download,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            ModernCard(
              onTap: () => _exportScheduleChanges(),
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule Change History',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Export schedule change requests',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.download,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              'Note',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'All exported records are read-only and timestamped. This documentation can be used for legal or mediation purposes.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportExpenses() async {
    // Export expense history
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality coming soon'),
      ),
    );
  }

  Future<void> _exportScheduleChanges() async {
    // Export schedule change history
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality coming soon'),
      ),
    );
  }
}

