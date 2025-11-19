import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/app_state.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    if (kIsWeb) {
      // For web, we need explicit Firebase options
      // If web config is not available, show a helpful error
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        if (e.toString().contains('UnsupportedError') || 
            e.toString().contains('web')) {
          throw Exception(
            'Firebase web configuration is required. '
            'Please add your web Firebase config to firebase_options.dart. '
            'Get it from Firebase Console > Project Settings > Your apps > Web app'
          );
        }
        rethrow;
      }
    } else {
      // For Android/iOS, try with options first, fallback to auto-detection
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // Fallback for Android if options fail
        await Firebase.initializeApp();
      }
    }
  } catch (e) {
    // If initialization fails completely, show error
    debugPrint('Firebase initialization error: $e');
    rethrow;
  }
  
  // Initialize notification service
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    debugPrint('Notification service initialized');
  } catch (e) {
    debugPrint('Notification service initialization error: $e');
    // Don't fail app startup if notifications fail
  }
  
  runApp(const FamilyHubApp());
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
      child: MaterialApp(
        title: 'Family Hub',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
      ),
    );
  }
}
