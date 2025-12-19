import 'package:flutter/material.dart';
import '../../services/subscription_service.dart';
import '../../services/auth_service.dart';
import '../../core/services/logger_service.dart';

/// Test screen for granting premium access to users
/// Only accessible in dev/test builds
class GrantPremiumTestScreen extends StatefulWidget {
  const GrantPremiumTestScreen({super.key});

  @override
  State<GrantPremiumTestScreen> createState() => _GrantPremiumTestScreenState();
}

class _GrantPremiumTestScreenState extends State<GrantPremiumTestScreen> {
  final _emailController = TextEditingController();
  final _userIdController = TextEditingController();
  final _subscriptionService = SubscriptionService();
  bool _isLoading = false;
  String? _lastResult;

  @override
  void dispose() {
    _emailController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _grantPremiumAccess() async {
    if (_emailController.text.trim().isEmpty && _userIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter either an email or user ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      await _subscriptionService.grantPremiumAccessForTesting(
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        userId: _userIdController.text.trim().isNotEmpty ? _userIdController.text.trim() : null,
      );

      setState(() {
        _isLoading = false;
        _lastResult = 'Success! Premium access granted. User model cache cleared.';
      });

      // Clear user model cache to ensure changes are visible immediately
      AuthService.clearUserModelCache();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Premium access granted successfully! Please close and reopen the create hub dialog to see changes.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      Logger.error('Error granting premium access', error: e, tag: 'GrantPremiumTestScreen');
      setState(() {
        _isLoading = false;
        _lastResult = 'Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grant Premium Access (Test)'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Grant Premium Access for Testing',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This tool grants premium subscription access for testing purposes. Enter either an email address or user ID.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'user@example.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            const Text(
              'OR',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                hintText: 'Firebase Auth UID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _grantPremiumAccess,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.workspace_premium),
              label: Text(_isLoading ? 'Granting...' : 'Grant Premium Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _lastResult!.startsWith('Error')
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _lastResult!.startsWith('Error')
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                child: Text(
                  _lastResult!,
                  style: TextStyle(
                    color: _lastResult!.startsWith('Error')
                        ? Colors.red.shade900
                        : Colors.green.shade900,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Quick Grant (Current User)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : () async {
                _emailController.clear();
                _userIdController.clear();
                await _grantPremiumAccess();
              },
              icon: const Icon(Icons.person),
              label: const Text('Grant Premium to Current User'),
            ),
          ],
        ),
      ),
    );
  }
}

