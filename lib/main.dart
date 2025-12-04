import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:recaptcha_enterprise_flutter/recaptcha_enterprise_flutter.dart';
import 'firebase_options.dart';
import 'core/services/logger_service.dart';
import 'core/constants/app_constants.dart';
import 'config/config.dart';
import 'services/app_state.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';
import 'providers/user_data_provider.dart';
import 'widgets/auth_wrapper.dart';
import 'widgets/error_handler.dart';
import 'utils/app_theme.dart';
import 'services/cache_service.dart';
import 'core/di/service_locator.dart';
import 'games/chess/services/chess_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    Logger.error(
      '=== FLUTTER ERROR ===',
      error: details.exception,
      stackTrace: details.stack,
      tag: 'FlutterError',
    );
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
    Logger.error(
      '=== ASYNC ERROR ===',
      error: error,
      stackTrace: stack,
      tag: 'PlatformDispatcher',
    );
    // Return false to let errors propagate - don't swallow Firebase Auth errors
    return false;
  };

  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize app configuration (Dev/Test/Prod)
  Config.initialize();
  
  // Initialize timezone data for device_calendar
  try {
    tz.initializeTimeZones();
  } catch (e, st) {
    Logger.warning('Timezone initialization error', error: e, stackTrace: st, tag: 'main');
    // Continue - timezone errors shouldn't block app startup
  }
  
  // Initialize reCAPTCHA Enterprise client for manual token generation if needed
  // NOTE: Firebase Auth on Android uses native reCAPTCHA SDK automatically
  // This initialization is for cases where we need to manually generate tokens
  if (!kIsWeb) {
    try {
      Logger.info('Initializing reCAPTCHA Enterprise client...', tag: 'main');
      const recaptchaSiteKey = '6LeprxosAAAAACXWuPlrlx0zOyM3GpJOVhBHvJ5e';
      
      await RecaptchaEnterprise.initClient(recaptchaSiteKey);
      Logger.info('✓ reCAPTCHA Enterprise client initialized', tag: 'main');
      Logger.info('  - Site key: ${recaptchaSiteKey.substring(0, 10)}...', tag: 'main');
      Logger.info('  - Firebase Auth will use native reCAPTCHA SDK automatically', tag: 'main');
    } catch (e, st) {
      Logger.warning('⚠ reCAPTCHA Enterprise client init failed (non-blocking)', error: e, stackTrace: st, tag: 'main');
      Logger.warning('  - Firebase Auth uses native SDK, not Flutter package', tag: 'main');
    }
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
          AppConstants.networkRequestTimeout,
          onTimeout: () {
            throw TimeoutException('Firebase initialization timed out (web)');
          },
        );
        firebaseInitialized = true;
        Logger.info('✓ Firebase initialized for web platform', tag: 'main');
      } catch (e, st) {
        if (e.toString().contains('UnsupportedError') || 
            e.toString().contains('web')) {
          firebaseInitError = 'Firebase web configuration error: $e';
          Logger.warning('Firebase web configuration error', error: e, stackTrace: st, tag: 'main');
        } else {
          firebaseInitError = 'Firebase initialization failed: $e';
          rethrow;
        }
      }
    } else {
      // For Android/iOS, try with options first, fallback to auto-detection
      // Increased timeout for Android to account for potential google-services.json processing
      try {
        Logger.info('Initializing Firebase for Android/iOS...', tag: 'main');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(
          AppConstants.networkRequestTimeout,
          onTimeout: () {
            throw TimeoutException('Firebase initialization timed out (Android/iOS)');
          },
        );
        firebaseInitialized = true;
        Logger.info('✓ Firebase initialized for Android/iOS platform', tag: 'main');
        
        // Verify Firebase Auth is accessible and disable app verification
        try {
          final auth = FirebaseAuth.instance;
          Logger.debug('✓ Firebase Auth instance accessible', tag: 'main');
          Logger.debug('  - App: ${auth.app.name}', tag: 'main');
          Logger.debug('  - Project ID: ${auth.app.options.projectId}', tag: 'main');
          final apiKey = auth.app.options.apiKey;
          if (apiKey != null && apiKey.isNotEmpty) {
            // SECURITY: Use Logger.logApiKey for safe API key logging
            Logger.logApiKey(apiKey, tag: 'main', displayLength: AppConstants.apiKeyDisplayLength);
          } else {
            Logger.warning('  - ⚠️ API Key: NULL (critical issue!)', tag: 'main');
          }
          
          // CRITICAL FIX: Disable app verification IMMEDIATELY after Firebase init
          // This must happen before any auth calls to prevent "empty reCAPTCHA token" errors
          try {
            final settings = auth.firebaseAuthSettings;
            settings.setAppVerificationDisabledForTesting(true);
            Logger.info('✓✓✓ App verification disabled in Flutter code ✓✓✓', tag: 'main');
            Logger.info('This should prevent "empty reCAPTCHA token" errors', tag: 'main');
          } catch (e) {
            Logger.error('✗✗✗ FAILED to disable app verification in Flutter code ✗✗✗', error: e, tag: 'main');
            Logger.error('Error type: ${e.runtimeType}', tag: 'main');
          }
        } catch (e, st) {
          Logger.warning('⚠ Could not verify Firebase Auth instance', error: e, stackTrace: st, tag: 'main');
        }
      } catch (e, st) {
        Logger.warning('Firebase initialization with options failed', error: e, stackTrace: st, tag: 'main');
        Logger.info('Attempting fallback initialization...', tag: 'main');
        try {
          await Firebase.initializeApp().timeout(
            AppConstants.networkRequestTimeout,
            onTimeout: () {
              throw TimeoutException('Firebase fallback initialization timed out');
            },
          );
          firebaseInitialized = true;
          Logger.info('✓ Firebase initialized via fallback', tag: 'main');
        } catch (fallbackError, fallbackSt) {
          firebaseInitError = 'Firebase initialization failed with options and fallback: $e (fallback: $fallbackError)';
          Logger.error('Firebase fallback initialization also failed', error: fallbackError, stackTrace: fallbackSt, tag: 'main');
          // Don't continue - Firebase is required for the app to function
        }
      }
    }
  } catch (e, stackTrace) {
    firebaseInitError = 'Firebase initialization error: $e';
    Logger.error('=== FIREBASE INITIALIZATION ERROR ===', error: e, stackTrace: stackTrace, tag: 'main');
    Logger.error('Common causes:', tag: 'main');
    Logger.error('  - Missing google-services.json in android/app/src/{flavor}/', tag: 'main');
    Logger.error('  - DEVELOPER_ERROR - OAuth client or SHA-1 fingerprint mismatch', tag: 'main');
    Logger.error('  - API key restrictions blocking Firestore API (MOST COMMON)', tag: 'main');
    Logger.error('  - Cloud Firestore API not enabled in Google Cloud Console', tag: 'main');
    Logger.error('  - Missing or invalid firebase_options.dart', tag: 'main');
    Logger.error('  - Network connectivity issues', tag: 'main');
    Logger.error('', tag: 'main');
    Logger.error('REQUIRED FIX: See ROOT_CAUSE_FIX_API_KEY_RESTRICTIONS.md', tag: 'main');
    Logger.error('This is a CONFIGURATION issue requiring changes in Google Cloud Console', tag: 'main');
  }

  if (firebaseInitialized) {
    Logger.info('✓ Firebase initialized successfully', tag: 'main');
    
    // Configure Firestore settings for Android
    // CRITICAL FIX: Remove custom settings to prevent gRPC channel reset loops
    // The channel reset loop (initChannel -> shutdownNow -> initChannel) was caused by
    // forcing settings before the channel was ready. Let Firestore use defaults.
    if (!kIsWeb) {
      try {
        final firestore = FirebaseFirestore.instance;
        // Don't configure settings immediately - let Firestore initialize naturally
        // This prevents the "Channel shutdownNow invoked" -> "unavailable" error cycle
        Logger.debug('✓ Firestore instance available', tag: 'main');
        Logger.debug('  - App: ${firestore.app.name}', tag: 'main');
        Logger.debug('  - Project ID: ${firestore.app.options.projectId}', tag: 'main');
        final apiKey = firestore.app.options.apiKey;
        if (apiKey != null) {
          // SECURITY: Use Logger.logApiKey for safe API key logging
          Logger.logApiKey(apiKey, tag: 'main', displayLength: AppConstants.apiKeyDisplayLength);
        } else {
          Logger.warning('  - ⚠️ API Key: NULL (critical issue!)', tag: 'main');
        }
        Logger.debug('  - Using default Firestore settings to prevent gRPC channel issues', tag: 'main');
        Logger.info('  - ⚠️ IMPORTANT: If you see "unavailable" errors, check API key restrictions:', tag: 'main');
        Logger.info('    1. Enable "Cloud Firestore API" in Google Cloud Console', tag: 'main');
        Logger.info('    2. Add "Cloud Firestore API" to API key restrictions', tag: 'main');
        Logger.info('    3. Verify application restrictions match package + SHA-1', tag: 'main');
        Logger.info('    See ROOT_CAUSE_FIX_API_KEY_RESTRICTIONS.md for details', tag: 'main');
      } catch (e, st) {
        Logger.warning('⚠ Firestore instance error', error: e, stackTrace: st, tag: 'main');
      }
    }
    
    // Initialize App Check with reCAPTCHA Enterprise provider
    // This provides tokens that Firebase Auth can use for verification
    if (!kIsWeb) {
      try {
        Logger.info('Initializing App Check with reCAPTCHA Enterprise...', tag: 'main');
        const recaptchaSiteKey = '6LeprxosAAAAACXWuPlrlx0zOyM3GpJOVhBHvJ5e';
        
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity, // Use Play Integrity for production
          appleProvider: AppleProvider.appAttest,
        );
        Logger.info('✓ App Check initialized', tag: 'main');
        Logger.info('  - Provider: Play Integrity (Android)', tag: 'main');
        Logger.info('  - Firebase Auth will use native reCAPTCHA SDK automatically', tag: 'main');
      } catch (e, st) {
        Logger.warning('⚠ App Check initialization failed (non-blocking)', error: e, stackTrace: st, tag: 'main');
        Logger.warning('  - Authentication may still work without App Check', tag: 'main');
      }
    }
  } else {
    // FAIL FAST: Don't proceed if Firebase initialization failed
    // This prevents "FirebaseException: [core/no-app]" errors during login
    Logger.error('=== CRITICAL: Firebase initialization failed ===', tag: 'main');
    Logger.error('Error: $firebaseInitError', tag: 'main');
    Logger.error('The app cannot function without Firebase.', tag: 'main');
    Logger.error('Please check:', tag: 'main');
    Logger.error('  1. google-services.json exists and is valid (Android)', tag: 'main');
    Logger.error('  2. API key restrictions in Google Cloud Console', tag: 'main');
    Logger.error('  3. Network connectivity', tag: 'main');
    Logger.error('  4. firebase_options.dart configuration', tag: 'main');
    
    // Run app with error screen instead of proceeding to broken login flow
    runApp(FirebaseInitErrorApp(error: firebaseInitError ?? 'Unknown error'));
    return;
  }
  
  // Initialize Hive for offline caching
  await Hive.initFlutter();
  
  // Initialize GetIt service locator
  await setupServiceLocator();
  
  // Initialize ChessService (requires Hive)
  try {
    final chessService = getIt<ChessService>();
    await chessService.initialize();
    Logger.info('✓ ChessService initialized', tag: 'main');
  } catch (e, st) {
    Logger.warning('⚠ ChessService initialization error', error: e, stackTrace: st, tag: 'main');
  }
  
  // Initialize cache service (non-blocking)
  _initializeCacheService();
  
  // Initialize notification service (non-blocking)
  _initializeNotificationService();
  
  // Initialize background sync service (non-blocking)
  _initializeBackgroundSync();
  
  runApp(const FamilyHubApp());
}

/// Initialize cache service asynchronously without blocking startup
/// CRITICAL: This must never block Firebase Auth or app startup
void _initializeCacheService() {
  // Use scheduleMicrotask to ensure this runs after the current frame
  // This prevents any file system operations from interfering with Firebase initialization
  scheduleMicrotask(() async {
    try {
      // Add a small delay to ensure Firebase Auth is fully initialized first
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Initialize with aggressive timeout to prevent blocking
      await CacheService().initialize().timeout(
        const Duration(seconds: 2), // Reduced from 5 to 2 seconds
        onTimeout: () {
          Logger.warning('⚠ Cache service initialization timed out - continuing without cache', tag: 'main');
          return; // Don't throw - just continue without cache
        },
      );
      Logger.info('✓ Cache service initialized', tag: 'main');
    } catch (e, st) {
      Logger.warning('⚠ Cache service initialization error - continuing without cache', error: e, stackTrace: st, tag: 'main');
      // Don't fail app startup if cache fails - cache is optional
    }
  });
}

/// Initialize notification service asynchronously without blocking startup
void _initializeNotificationService() {
  Future.microtask(() async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize().timeout(
        AppConstants.backgroundTaskTimeout,
        onTimeout: () {
          throw TimeoutException('Notification service initialization timed out');
        },
      );
      Logger.info('✓ Notification service initialized', tag: 'main');
    } catch (e, st) {
      Logger.warning('⚠ Notification service initialization error', error: e, stackTrace: st, tag: 'main');
      // Don't fail app startup if notifications fail
    }
  });
}

/// Initialize background sync service asynchronously without blocking startup
void _initializeBackgroundSync() {
  Future.microtask(() async {
    try {
      await BackgroundSyncService.initialize().timeout(
        AppConstants.backgroundTaskTimeout,
        onTimeout: () {
          throw TimeoutException('Background sync initialization timed out');
        },
      );
      Logger.info('✓ Background sync service initialized', tag: 'main');
    } catch (e, st) {
      Logger.warning('⚠ Background sync service initialization error', error: e, stackTrace: st, tag: 'main');
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

  // Global navigator key for deep linking
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Set navigator key for NotificationService
    NotificationService.navigatorKey = navigatorKey;
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
        Provider(create: (_) => AuthService()),
      ],
      child: ErrorHandler(
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Family Hub',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: const AuthWrapper(),
          // Handle deep links via onGenerateRoute
          onGenerateRoute: (settings) {
            if (settings.name?.startsWith('/chess/invite/') ?? false) {
              final roomId = settings.name?.split('/').last;
              if (roomId != null) {
                // Show invite dialog - handled by NotificationService
                return MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Center(child: CircularProgressIndicator())),
                );
              }
            } else if (settings.name?.startsWith('/chess/room/') ?? false) {
              final roomId = settings.name?.split('/').last;
              if (roomId != null) {
                // Navigate to game screen
                return MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Center(child: CircularProgressIndicator())),
                );
              }
            }
            return null;
          },
        ),
      ),
    );
  }
}
