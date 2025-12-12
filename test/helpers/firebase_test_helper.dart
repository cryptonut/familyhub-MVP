import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper class to initialize Firebase for testing with emulator
class FirebaseTestHelper {
  static bool _initialized = false;

  /// Initialize Firebase with emulator settings
  /// Call this in setUpAll() of your test groups
  static Future<void> initializeFirebaseEmulator() async {
    if (_initialized) return;

    try {
      // Check if we should use emulator (set via environment variable or default to true in tests)
      const useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: true);

      if (useEmulator) {
        // Check if Firebase is already initialized
        try {
          Firebase.app();
          // Already initialized, just connect to emulators
        } catch (e) {
          // Initialize Firebase with test options for emulator
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: 'test-api-key',
              appId: 'test-app-id',
              messagingSenderId: 'test-sender-id',
              projectId: 'test-project',
            ),
          );
        }

        // Connect to emulators (safe to call multiple times)
        try {
          await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
          FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
          _initialized = true;
        } catch (e) {
          // Emulator already connected or not available
          print('Note: Emulator connection: $e');
          _initialized = true; // Mark as initialized anyway
        }
      }
    } catch (e) {
      // If emulator isn't running, tests will fail - that's expected
      // In CI/CD, emulator should be started before tests
      print('Warning: Firebase emulator not available: $e');
      print('Start emulator with: firebase emulators:start');
    }
  }

  /// Clean up Firebase after tests
  /// Call this in tearDownAll() of your test groups
  static Future<void> cleanup() async {
    try {
      // Clear auth state
      await FirebaseAuth.instance.signOut();
      
      // Note: Firestore emulator data is automatically cleared when emulator restarts
      // For individual test cleanup, delete collections manually
    } catch (e) {
      print('Warning: Error during Firebase cleanup: $e');
    }
  }

  /// Clear all Firestore collections (useful for test cleanup)
  static Future<void> clearFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get all collections (this is a simplified approach)
      // In a real scenario, you'd track which collections were created during tests
      // For now, we'll rely on emulator auto-cleanup on restart
      
      // Alternative: Delete specific test collections
      // await firestore.collection('test_users').get().then((snapshot) {
      //   for (var doc in snapshot.docs) {
      //     doc.reference.delete();
      //   }
      // });
    } catch (e) {
      print('Warning: Error clearing Firestore: $e');
    }
  }
}

