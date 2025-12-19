import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/services/logger_service.dart';
import '../../services/recurring_payment_service.dart';
import '../../services/auth_service.dart';
import '../../models/recurring_payment.dart';
import '../../models/user_model.dart';

class RecurringPaymentsScreen extends StatefulWidget {
  const RecurringPaymentsScreen({super.key});

  @override
  State<RecurringPaymentsScreen> createState() => _RecurringPaymentsScreenState();
}

class _RecurringPaymentsScreenState extends State<RecurringPaymentsScreen> {
  final RecurringPaymentService _recurringPaymentService = RecurringPaymentService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<RecurringPayment> _recurringPayments = [];
  List<UserModel> _familyMembers = [];
  Map<String, String> _userNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _recurringPayments = await _recurringPaymentService.getCreatedRecurringPayments();
      _familyMembers = await _authService.getFamilyMembers();
      
      // Build user names map
      for (var member in _familyMembers) {
        _userNames[member.uid] = member.displayName.isNotEmpty 
            ? member.displayName 
            : member.email;
      }
    } catch (e) {
      Logger.error('Error loading recurring payments', error: e, tag: 'RecurringPaymentsScreen');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createRecurringPayment() async {
    final result = await showDialog(
      context: context,
      builder: (context) => CreateRecurringPaymentDialog(familyMembers: _familyMembers),
    );
    if (result == true && mounted) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createRecurringPayment,
            tooltip: 'Set Up Pocket Money',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _recurringPayments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recurring payments set up',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _createRecurringPayment,
                            icon: const Icon(Icons.add),
                            label: const Text('Set Up Pocket Money'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _recurringPayments.length,
                      itemBuilder: (context, index) {
                        final payment = _recurringPayments[index];
                        return _buildRecurringPaymentCard(payment);
                      },
                    ),
            ),
    );
  }

  Widget _buildRecurringPaymentCard(RecurringPayment payment) {
    final recipientName = _userNames[payment.toUserId] ?? 'Unknown';
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '\$${payment.amount.toStringAsFixed(2)} AUD ${payment.frequency}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (payment.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Inactive',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (payment.nextPaymentDate != null) ...[
              Text(
                'Next payment: ${dateFormat.format(payment.nextPaymentDate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (payment.lastPaymentDate != null)
              Text(
                'Last payment: ${dateFormat.format(payment.lastPaymentDate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            if (payment.notes != null && payment.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${payment.notes}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (payment.isActive) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Deactivate Recurring Payment?'),
                          content: Text('This will stop future payments to $recipientName.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                              child: const Text('Deactivate'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        try {
                          await _recurringPaymentService.deactivateRecurringPayment(payment.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Recurring payment deactivated'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadData();
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
                    },
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Deactivate'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CreateRecurringPaymentDialog extends StatefulWidget {
  final List<UserModel> familyMembers;

  const CreateRecurringPaymentDialog({super.key, required this.familyMembers});

  @override
  State<CreateRecurringPaymentDialog> createState() => _CreateRecurringPaymentDialogState();
}

class _CreateRecurringPaymentDialogState extends State<CreateRecurringPaymentDialog> {
  final RecurringPaymentService _recurringPaymentService = RecurringPaymentService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _selectedUserId;
  String _selectedFrequency = 'weekly';
  bool _isProcessing = false;

  final List<String> _frequencies = ['weekly', 'monthly'];

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createPayment() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a recipient'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _recurringPaymentService.createRecurringPayment(
        toUserId: _selectedUserId!,
        amount: amount,
        frequency: _selectedFrequency,
        notes: _notesController.text.trim().isNotEmpty 
            ? _notesController.text.trim() 
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recurring payment set up successfully'),
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
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show all family members as recipients (no filtering)
    // Note: Age-based filtering can be added later if needed (e.g., only show children)
    final recipients = widget.familyMembers.toList();
    
    // Log if recipients list is empty for debugging
    if (recipients.isEmpty) {
      Logger.warning('CreateRecurringPaymentDialog: No family members available for recipients', tag: 'RecurringPaymentsScreen');
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Colors.green.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Set Up Pocket Money'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recipient:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedUserId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select recipient',
              ),
              items: recipients.map((member) {
                final name = member.displayName.isNotEmpty 
                    ? member.displayName 
                    : member.email;
                return DropdownMenuItem(
                  value: member.uid,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedUserId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (AUD)',
                hintText: '0.00',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            const Text(
              'Frequency:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
                ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ],
              selected: {_selectedFrequency},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedFrequency = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Enter any notes...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payments will be automatically added to the recipient\'s wallet. As a Banker, you can go into negative balance to ensure payments continue.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _createPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                  ),
                )
              : const Text('Set Up'),
        ),
      ],
    );
  }
}

