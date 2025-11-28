import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/logger_service.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../services/calendar_service.dart';
import '../../services/chat_service.dart';
import '../../services/family_wallet_service.dart';

class DatabaseResetScreen extends StatefulWidget {
  const DatabaseResetScreen({super.key});

  @override
  State<DatabaseResetScreen> createState() => _DatabaseResetScreenState();
}

class _DatabaseResetScreenState extends State<DatabaseResetScreen> {
  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<String> _logs = [];
  bool _isResetting = false;
  int _itemsDeleted = 0;

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _logs.add('${DateTime.now().toIso8601String()} - $message');
      });
    }
    Logger.info('DatabaseReset: $message', tag: 'DatabaseResetScreen');
  }

  Future<void> _resetDatabase() async {
    // Show confirmation dialog with text input
    final confirmationText = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 28),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('⚠️ DANGER ZONE ⚠️'),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This will PERMANENTLY DELETE:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Your user account'),
                    const Text('• All your tasks/jobs'),
                    const Text('• All your calendar events'),
                    const Text('• All your chat messages'),
                    const Text('• All your wallet transactions'),
                    const Text('• All family data'),
                    const SizedBox(height: 16),
                    Text(
                      '⚠️ This action CANNOT be undone! ⚠️',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Type "DELETE" to confirm:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Type DELETE here',
                        border: OutlineInputBorder(),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      autofocus: true,
                      onChanged: (value) {
                        setDialogState(() {}); // Rebuild to update button state
                      },
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: controller.text.toUpperCase() == 'DELETE'
                      ? () => Navigator.pop(context, controller.text)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: const Text('Delete Forever'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmationText?.toUpperCase() != 'DELETE') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deletion cancelled - confirmation text did not match'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Now ask for password for re-authentication
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final passwordController = TextEditingController();
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Re-authentication Required'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'For security, please enter your password to confirm account deletion:',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(context, passwordController.text);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, passwordController.text);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (password == null || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deletion cancelled - password required'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isResetting = true;
      _logs.clear();
      _itemsDeleted = 0;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _addLog('Error: No user logged in');
        return;
      }

      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      final userId = user.uid;
      final userEmail = user.email ?? 'Unknown';

      _addLog('Starting database reset for user: $userEmail');
      _addLog('User ID: $userId');
      _addLog('Family ID: ${familyId ?? "None"}');

      // Step 1: Re-authenticate user (required for Auth account deletion)
      _addLog('Step 1: Re-authenticating user...');
      try {
        await _authService.reauthenticateUser(password);
        _addLog('✓ Re-authentication successful');
      } catch (e) {
        _addLog('❌ Re-authentication failed: $e');
        throw Exception('Re-authentication failed: $e');
      }

      // Step 2: Clear service caches
      _addLog('Step 2: Clearing service caches...');
      _taskService.clearFamilyIdCache();
      _itemsDeleted++;

      // Step 3: Delete all user data from Firestore
      _addLog('Step 3: Deleting user data from Firestore...');
      await _authService.deleteUserData(userId, familyId);
      _itemsDeleted += 10; // Approximate

      // Step 4: Delete notifications
      _addLog('Step 4: Deleting notifications...');
      await _authService.deleteUserNotifications();
      _itemsDeleted += 5; // Approximate

      // Step 5: Delete Firebase Auth account (will succeed because we re-authenticated)
      _addLog('Step 5: Deleting Firebase Auth account...');
      // Skip Firestore deletion since we already did it in Step 3
      await _authService.deleteCurrentUserAccount(password: password, skipFirestoreDeletion: true);
      _itemsDeleted++;

      _addLog('✅ Database reset completed successfully!');
      _addLog('Total items deleted: ~$_itemsDeleted');
      _addLog('You will now be signed out.');

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database reset complete! You will be signed out.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );

        // Wait a moment, then navigate to login
        await Future.delayed(const Duration(seconds: 2));
        
        // Sign out (user is already deleted, but this ensures clean state)
        await _authService.signOut();
        
        // The AuthWrapper will handle navigation to login screen
      }
    } catch (e, stackTrace) {
      _addLog('❌ Error during reset: $e');
      _addLog('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during reset: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Reset'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red.shade700, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'DANGER ZONE',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This will PERMANENTLY delete:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Your user account'),
                    const Text('• All your tasks/jobs'),
                    const Text('• All your calendar events'),
                    const Text('• All your chat messages'),
                    const Text('• All your wallet transactions'),
                    const Text('• All family data'),
                    const SizedBox(height: 16),
                    Text(
                      '⚠️ This action CANNOT be undone! ⚠️',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isResetting ? null : _resetDatabase,
              icon: _isResetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(_isResetting ? 'Resetting Database...' : 'Reset Database'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                disabledBackgroundColor: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            if (_logs.isNotEmpty) ...[
              const Text(
                'Reset Log:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _logs[index],
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

