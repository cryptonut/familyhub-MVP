import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Global error handler widget that catches and displays errors gracefully
class ErrorHandler extends StatelessWidget {
  const ErrorHandler({
    super.key,
    required this.child,
    this.showErrorDetails = kDebugMode,
  });

  final Widget child;
  final bool showErrorDetails;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Widget to display errors in a user-friendly way
class ErrorDisplayWidget extends StatelessWidget {
  const ErrorDisplayWidget({
    super.key,
    required this.error,
    this.showDetails = false,
    this.stackTrace,
  });

  final Object error;
  final bool showDetails;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    final errorMessage = _getUserFriendlyMessage(error);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (showDetails) ...[
                  const SizedBox(height: 24),
                  ExpansionTile(
                    title: const Text('Technical Details'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          error.toString(),
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    // Try to recover by restarting the app
                    // In a real app, you might want to navigate to a safe state
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getUserFriendlyMessage(Object error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('developer_error') || 
        errorStr.contains('connectionresult')) {
      return 'Firebase configuration issue detected.\n\n'
          'Please ensure:\n'
          '1. SHA-1 fingerprint is added to Firebase Console\n'
          '2. Wait 2-3 minutes after adding\n'
          '3. Restart the app completely';
    }

    if (errorStr.contains('network') || errorStr.contains('unavailable')) {
      return 'Network connection issue.\n\n'
          'Please check your internet connection and try again.';
    }

    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Permission denied.\n\n'
          'Please check Firestore security rules in Firebase Console.';
    }

    if (errorStr.contains('firebase') || errorStr.contains('initialization')) {
      return 'Firebase initialization failed.\n\n'
          'Please check your Firebase configuration and try again.';
    }

    return 'An unexpected error occurred.\n\n'
        'Please try again or contact support if the problem persists.';
  }
}

/// Error boundary for async operations
class AsyncErrorHandler {
  static void handleError(Object error, StackTrace stackTrace, {String? context}) {
    if (kDebugMode) {
      debugPrint('=== ERROR ${context != null ? "in $context" : ""} ===');
      debugPrint('Error: $error');
      debugPrint('Stack trace: $stackTrace');
    }

    // In production, you might want to send this to a crash reporting service
    // e.g., Firebase Crashlytics, Sentry, etc.
  }

  static String getUserFriendlyMessage(Object error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('developer_error')) {
      return 'Firebase configuration issue. Please add SHA-1 fingerprint to Firebase Console.';
    }

    if (errorStr.contains('network') || errorStr.contains('unavailable')) {
      return 'Network error. Please check your connection.';
    }

    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Permission denied. Please check Firestore security rules.';
    }

    if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    return 'An error occurred. Please try again.';
  }
}

