import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/app_state.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';
import 'widgets/auth_wrapper.dart';
import 'widgets/error_handler.dart';
import 'utils/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tz;

void main() async {
  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('=== FLUTTER ERROR ===');
      debugPrint('Error: ${details.exception}');
      debugPrint('Stack: ${details.stack}');
    }
  };

  // Set up error widget builder for better error display
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('An error occurred'),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SelectableText(
                    details.exception.toString(),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  };

  // Handle async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('=== ASYNC ERROR ===');
      debugPrint('Error: $error');
      debugPrint('Stack: $stack');
    }
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone data for device_calendar
  try {
    tz.initializeTimeZones();
  } catch (e) {
    debugPrint('Timezone initialization error: $e');
    // Continue - timezone errors shouldn't block app startup
  }
  
  // Initialize Firebase with comprehensive error handling
  bool firebaseInitialized = false;
  try {
    if (kIsWeb) {
      // For web, we need explicit Firebase options
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Firebase initialization timed out');
          },
        );
        firebaseInitialized = true;
      } catch (e) {
        if (e.toString().contains('UnsupportedError') || 
            e.toString().contains('web')) {
          debugPrint('Firebase web configuration error: $e');
          // Continue - app can still run with limited functionality
        } else {
          rethrow;
        }
      }
    } else {
      // For Android/iOS, try with options first, fallback to auto-detection
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('Firebase initialization timed out');
          },
        );
        firebaseInitialized = true;
      } catch (e) {
        debugPrint('Firebase initialization with options failed: $e');
        debugPrint('Attempting fallback initialization...');
        try {
          await Firebase.initializeApp().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Firebase fallback initialization timed out');
            },
          );
          firebaseInitialized = true;
        } catch (fallbackError) {
          debugPrint('Firebase fallback initialization also failed: $fallbackError');
          // Continue - app can still run with limited functionality
        }
      }
    }
  } catch (e, stackTrace) {
    debugPrint('=== FIREBASE INITIALIZATION ERROR ===');
    debugPrint('Error: $e');
    debugPrint('Stack: $stackTrace');
    // Don't crash the app - allow it to start and show error in UI
  }

  if (firebaseInitialized) {
    debugPrint('✓ Firebase initialized successfully');
    
    // Configure Firestore settings for Android to prevent gRPC channel issues
    if (!kIsWeb) {
      try {
        final firestore = FirebaseFirestore.instance;
        // Configure settings to help with initial connection and prevent channel resets
        firestore.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint('✓ Firestore settings configured');
      } catch (e) {
        debugPrint('⚠ Firestore settings error: $e');
      }
    }
    
    // TEMPORARILY DISABLED - App Check is unregistered and may be causing Android auth timeouts
    // Since Chrome works but Android doesn't, disabling App Check to test if it's the issue
    // TODO: Re-enable once Android auth is working, or register App Check properly
    debugPrint('⚠ App Check temporarily disabled for Android auth testing');
    /*
    try {
      if (kIsWeb) {
        debugPrint('⚠ App Check skipped for web');
      } else {
        debugPrint('Initializing Firebase App Check (debug mode)...');
        // Android/iOS App Check with debug provider for development
        // Using timeout to prevent blocking
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        ).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('⚠ App Check init timeout - skipping');
            return; // Return early on timeout
          },
        );
        debugPrint('✓ Firebase App Check initialized');
      }
    } catch (e) {
      debugPrint('⚠ App Check error (non-critical): $e');
      // Continue - App Check warnings won't block auth
    }
    */
  } else {
    debugPrint('⚠ Firebase initialization failed - app will run with limited functionality');
  }
  
  // Initialize notification service (non-blocking)
  _initializeNotificationService();
  
  // Initialize background sync service (non-blocking)
  _initializeBackgroundSync();
  
  runApp(const FamilyHubApp());
}

/// Initialize notification service asynchronously without blocking startup
void _initializeNotificationService() {
  Future.microtask(() async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Notification service initialization timed out');
        },
      );
      debugPrint('✓ Notification service initialized');
    } catch (e) {
      debugPrint('⚠ Notification service initialization error: $e');
      // Don't fail app startup if notifications fail
    }
  });
}

/// Initialize background sync service asynchronously without blocking startup
void _initializeBackgroundSync() {
  Future.microtask(() async {
    try {
      await BackgroundSyncService.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Background sync initialization timed out');
        },
      );
      debugPrint('✓ Background sync service initialized');
    } catch (e) {
      debugPrint('⚠ Background sync service initialization error: $e');
      // Don't fail app startup if background sync fails
    }
  });
}

class FamilyHubApp extends StatelessWidget {
  const FamilyHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        Provider(create: (_) => AuthService()),
      ],
      child: ErrorHandler(
        child: MaterialApp(
          title: 'Family Hub',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}
