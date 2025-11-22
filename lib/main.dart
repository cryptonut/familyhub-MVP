import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  // CRITICAL FIX: Return false to let errors propagate properly
  // Returning true swallows errors and can prevent Firebase Auth errors from being handled correctly
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('=== ASYNC ERROR ===');
      debugPrint('Error: $error');
      debugPrint('Stack: $stack');
    }
    // Return false to let errors propagate - don't swallow Firebase Auth errors
    return false;
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
  // CRITICAL: Fail fast if Firebase initialization fails to prevent "core/no-app" errors
  bool firebaseInitialized = false;
  String? firebaseInitError;
  
  try {
    if (kIsWeb) {
      // For web, we need explicit Firebase options
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('Firebase initialization timed out (web)');
          },
        );
        firebaseInitialized = true;
        debugPrint('✓ Firebase initialized for web platform');
      } catch (e) {
        if (e.toString().contains('UnsupportedError') || 
            e.toString().contains('web')) {
          firebaseInitError = 'Firebase web configuration error: $e';
          debugPrint('Firebase web configuration error: $e');
        } else {
          firebaseInitError = 'Firebase initialization failed: $e';
          rethrow;
        }
      }
    } else {
      // For Android/iOS, try with options first, fallback to auto-detection
      // Increased timeout for Android to account for potential google-services.json processing
      try {
        debugPrint('Initializing Firebase for Android/iOS...');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('Firebase initialization timed out (Android/iOS)');
          },
        );
        firebaseInitialized = true;
        debugPrint('✓ Firebase initialized for Android/iOS platform');
        
        // Verify Firebase Auth is accessible
        try {
          final auth = FirebaseAuth.instance;
          debugPrint('✓ Firebase Auth instance accessible');
          debugPrint('  - App: ${auth.app.name}');
          debugPrint('  - Project ID: ${auth.app.options.projectId}');
          final apiKey = auth.app.options.apiKey;
          if (apiKey != null && apiKey.isNotEmpty) {
            debugPrint('  - API Key: ${apiKey.substring(0, 10)}...');
            debugPrint('  - Full API Key: $apiKey');
          } else {
            debugPrint('  - ⚠️ API Key: NULL (critical issue!)');
          }
        } catch (e) {
          debugPrint('⚠ Could not verify Firebase Auth instance: $e');
        }
      } catch (e) {
        debugPrint('Firebase initialization with options failed: $e');
        debugPrint('Attempting fallback initialization...');
        try {
          await Firebase.initializeApp().timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Firebase fallback initialization timed out');
            },
          );
          firebaseInitialized = true;
          debugPrint('✓ Firebase initialized via fallback');
        } catch (fallbackError) {
          firebaseInitError = 'Firebase initialization failed with options and fallback: $e (fallback: $fallbackError)';
          debugPrint('Firebase fallback initialization also failed: $fallbackError');
          // Don't continue - Firebase is required for the app to function
        }
      }
    }
  } catch (e, stackTrace) {
    firebaseInitError = 'Firebase initialization error: $e';
    debugPrint('=== FIREBASE INITIALIZATION ERROR ===');
    debugPrint('Error: $e');
    debugPrint('Stack: $stackTrace');
    debugPrint('Common causes:');
    debugPrint('  - Missing google-services.json in android/app/');
    debugPrint('  - DEVELOPER_ERROR - OAuth client or SHA-1 fingerprint mismatch');
    debugPrint('  - Incorrect API key restrictions in Google Cloud Console');
    debugPrint('  - Missing or invalid firebase_options.dart');
    debugPrint('  - Network connectivity issues');
  }

  if (firebaseInitialized) {
    debugPrint('✓ Firebase initialized successfully');
    
    // Configure Firestore settings for Android
    // CRITICAL FIX: Remove custom settings to prevent gRPC channel reset loops
    // The channel reset loop (initChannel -> shutdownNow -> initChannel) was caused by
    // forcing settings before the channel was ready. Let Firestore use defaults.
    if (!kIsWeb) {
      try {
        final firestore = FirebaseFirestore.instance;
        // Don't configure settings immediately - let Firestore initialize naturally
        // This prevents the "Channel shutdownNow invoked" -> "unavailable" error cycle
        debugPrint('✓ Firestore instance available');
        debugPrint('  - App: ${firestore.app.name}');
        debugPrint('  - Project ID: ${firestore.app.options.projectId}');
        final apiKey = firestore.app.options.apiKey;
        if (apiKey != null) {
          debugPrint('  - API Key: ${apiKey.substring(0, 10)}... (Android key)');
        } else {
          debugPrint('  - ⚠️ API Key: NULL (critical issue!)');
        }
        debugPrint('  - Using default Firestore settings to prevent gRPC channel issues');
      } catch (e) {
        debugPrint('⚠ Firestore instance error: $e');
      }
    }
    
    // App Check is disabled to prevent potential Android auth timeouts
    // App Check enforcement can block requests if not properly configured
    // This is a platform-agnostic decision, not a Chrome workaround
    // TODO: Re-enable App Check once properly registered in Firebase Console
    debugPrint('⚠ App Check disabled to prevent authentication timeouts');
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
    // FAIL FAST: Don't proceed if Firebase initialization failed
    // This prevents "FirebaseException: [core/no-app]" errors during login
    debugPrint('=== CRITICAL: Firebase initialization failed ===');
    debugPrint('Error: $firebaseInitError');
    debugPrint('The app cannot function without Firebase.');
    debugPrint('Please check:');
    debugPrint('  1. google-services.json exists and is valid (Android)');
    debugPrint('  2. API key restrictions in Google Cloud Console');
    debugPrint('  3. Network connectivity');
    debugPrint('  4. firebase_options.dart configuration');
    
    // Run app with error screen instead of proceeding to broken login flow
    runApp(FirebaseInitErrorApp(error: firebaseInitError ?? 'Unknown error'));
    return;
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

/// Error screen shown when Firebase initialization fails
/// This prevents the app from proceeding to a broken login flow
class FirebaseInitErrorApp extends StatelessWidget {
  final String? error;
  
  const FirebaseInitErrorApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Hub - Initialization Error',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Firebase Initialization Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'The app cannot start without Firebase. Please check:',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• google-services.json exists and is valid (Android)'),
                      Text('• API key restrictions in Google Cloud Console'),
                      Text('• Network connectivity'),
                      Text('• firebase_options.dart configuration'),
                    ],
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Error details:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      error!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
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
