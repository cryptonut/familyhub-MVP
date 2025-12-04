import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import '../../services/auth_service.dart';

class DeleteUserScreen extends StatefulWidget {
  const DeleteUserScreen({super.key});

  @override
  State<DeleteUserScreen> createState() => _DeleteUserScreenState();
}

class _DeleteUserScreenState extends State<DeleteUserScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _userIdController = TextEditingController(
    text: 'WkCr1tJzvXSl3mAMPjOCD5v9oZ42', // Pre-fill with duplicate user ID
  );
  final List<String> _logs = [];
  bool _isDeleting = false;

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _logs.add('${DateTime.now().toIso8601String()} - $message');
      });
    }
    Logger.info('DeleteUser: $message', tag: 'DeleteUserScreen');
  }

  Future<void> _deleteUser() async {
    final userId = _userIdController.text.trim();
    
    if (userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a user ID'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('⚠️ Confirm Deletion ⚠️'),
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
              const Text('• User document from Firestore'),
              const Text('• All notifications for this user'),
              const Text('• Old user-specific collections'),
              const SizedBox(height: 16),
              Text(
                'User ID: $userId',
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Text(
                '⚠️ This action CANNOT be undone! ⚠️',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete User'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
      _logs.clear();
    });

    try {
      _addLog('Starting deletion for user: $userId');
      
      // Delete user data
      await _authService.deleteUserById(userId);
      
      _addLog('✅ User deleted successfully!');
      _addLog('Note: Firebase Auth account (if exists) must be deleted manually from Firebase Console');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Clear the input field
        _userIdController.clear();
      }
    } catch (e, stackTrace) {
      final errorMessage = e.toString();
      _addLog('❌ Error deleting user: $errorMessage');
      _addLog('Stack trace: $stackTrace');
      
      // Check for common error types
      String userFriendlyMessage = errorMessage;
      if (errorMessage.contains('permission-denied') || errorMessage.contains('PERMISSION_DENIED')) {
        userFriendlyMessage = 'Permission denied. You may need admin privileges or updated Firestore rules to delete users.';
      } else if (errorMessage.contains('not-found') || errorMessage.contains('NOT_FOUND')) {
        userFriendlyMessage = 'User not found. The user may have already been deleted.';
      } else if (errorMessage.contains('unavailable') || errorMessage.contains('UNAVAILABLE')) {
        userFriendlyMessage = 'Service unavailable. Please check your internet connection and try again.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete User'),
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
                            'DELETE USER',
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
                      'This will permanently delete user data from Firestore:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• User document'),
                    const Text('• All notifications'),
                    const Text('• Old user-specific collections'),
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
            TextField(
              controller: _userIdController,
              decoration: InputDecoration(
                labelText: 'User ID',
                hintText: 'Enter user ID to delete',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
                suffixIcon: _userIdController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _userIdController.clear();
                          });
                        },
                      )
                    : null,
              ),
              enabled: !_isDeleting,
              onChanged: (value) {
                setState(() {}); // Rebuild to show/hide clear button
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDeleting ? null : _deleteUser,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.delete_forever),
                label: Text(_isDeleting ? 'Deleting User...' : 'Delete User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  disabledBackgroundColor: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_logs.isNotEmpty) ...[
              const Text(
                'Deletion Log:',
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

