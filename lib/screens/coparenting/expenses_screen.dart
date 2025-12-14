import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

/// Screen for managing co-parenting expenses
class ExpensesScreen extends StatefulWidget {
  final String hubId;

  const ExpensesScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Implement create expense
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Create expense - Coming soon'),
                ),
              );
            },
            tooltip: 'Add Expense',
          ),
        ],
      ),
      body: Center(
        child: EmptyState(
          icon: Icons.attach_money_outlined,
          title: 'Shared Expenses',
          message: 'Track and split expenses with your co-parent',
          action: ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement create expense
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Create expense - Coming soon'),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
          ),
        ),
      ),
    );
  }
}

