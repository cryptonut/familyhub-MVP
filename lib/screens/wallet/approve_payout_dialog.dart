import 'package:flutter/material.dart';
import '../../models/payout_request.dart';
import '../../services/payout_service.dart';

class ApprovePayoutDialog extends StatefulWidget {
  final PayoutRequest payoutRequest;

  const ApprovePayoutDialog({super.key, required this.payoutRequest});

  @override
  State<ApprovePayoutDialog> createState() => _ApprovePayoutDialogState();
}

class _ApprovePayoutDialogState extends State<ApprovePayoutDialog> {
  final PayoutService _payoutService = PayoutService();
  final TextEditingController _notesController = TextEditingController();
  String _selectedPaymentMethod = 'Cash';
  bool _isProcessing = false;

  final List<String> _paymentMethods = ['Cash', 'Bank', 'Other'];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _approvePayout() async {
    setState(() => _isProcessing = true);

    try {
      await _payoutService.approvePayoutRequest(
        widget.payoutRequest.id,
        _selectedPaymentMethod,
        notes: _notesController.text.trim().isNotEmpty 
            ? _notesController.text.trim() 
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payout approved successfully. Amount deducted from user balance.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving payout: $e'),
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
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Approve Payout'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Amount: \$${widget.payoutRequest.amount.toStringAsFixed(2)} AUD',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How was payment made?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ..._paymentMethods.map((method) {
              return RadioListTile<String>(
                title: Text(method),
                value: method,
                groupValue: _selectedPaymentMethod,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentMethod = value!;
                  });
                },
              );
            }),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes (Optional)',
                hintText: 'Enter any notes about the payment...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
                      'The amount will be deducted from the user\'s wallet balance.',
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
          onPressed: _isProcessing ? null : _approvePayout,
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
              : const Text('Approve Payout'),
        ),
      ],
    );
  }
}

