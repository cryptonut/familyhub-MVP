import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dev_config.dart';
import 'qa_config.dart';
import 'prod_config.dart';
import 'app_config.dart';

/// Global app configuration based on build flavor
class Config {
  static AppConfig? _config;

  /// Initialize configuration based on flavor
  /// Detects flavor from package name at runtime for accurate detection
  /// For web, requires --dart-define=FLAVOR=dev to be passed explicitly
  static Future<void> initialize() async {
    String flavor = 'prod'; // Default fallback
    
    try {
      // First, try to get flavor from compile-time constant (if passed via --dart-define)
      // CRITICAL: For web, this MUST be passed: flutter run -d chrome --dart-define=FLAVOR=dev
      const dartDefineFlavor = String.fromEnvironment('FLAVOR', defaultValue: '');
      if (dartDefineFlavor.isNotEmpty) {
        flavor = dartDefineFlavor.toLowerCase();
        if (kDebugMode) {
          print('🔧 Flavor detected from dart-define: $flavor');
        }
      } else {
        // If not provided via dart-define, detect from package name at runtime (Android/iOS only)
        try {
          final packageInfo = await PackageInfo.fromPlatform();
          final packageName = packageInfo.packageName;
          
          // Determine flavor from package name
          // dev: com.example.familyhub_mvp.dev
          // qa: com.example.familyhub_mvp.test
          // prod: com.example.familyhub_mvp
          if (packageName.endsWith('.dev')) {
            flavor = 'dev';
          } else if (packageName.endsWith('.test')) {
            flavor = 'qa';
          } else {
            flavor = 'prod';
          }
          
          if (kDebugMode) {
            print('🔧 Flavor detected from package name: $flavor (package: $packageName)');
          }
        } catch (e) {
          // Package info might not work on web - default to prod
          if (kDebugMode) {
            print('⚠️ Could not detect flavor from package name, defaulting to prod. For web, use --dart-define=FLAVOR=dev');
          }
          flavor = 'prod';
        }
      }
    } catch (e) {
      // If everything fails, fall back to dart-define or default to prod
      const dartDefineFlavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
      flavor = dartDefineFlavor.isNotEmpty ? dartDefineFlavor.toLowerCase() : 'prod';
      if (kDebugMode) {
        print('⚠️ Error detecting flavor, using: $flavor');
      }
    }
    
    switch (flavor.toLowerCase()) {
      case 'dev':
        _config = DevConfig();
        break;
      case 'qa':
        _config = QaConfig();
        break;
      case 'prod':
      default:
        _config = ProdConfig();
        break;
    }
    
    if (kDebugMode) {
      print('🔧 App Config: ${_config!.environmentName}');
      print('   App ID: ${_config!.appId}');
      print('   Firestore Prefix: ${_config!.firestorePrefix}');
      print('   Detected Flavor: $flavor');
    }
  }

  /// Get current configuration
  static AppConfig get current {
    if (_config == null) {
      throw Exception('Config not initialized. Call Config.initialize() first.');
    }
    return _config!;
  }

  /// Check if running in development
  static bool get isDev => _config is DevConfig;

  /// Check if running in QA
  static bool get isQa => _config is QaConfig;

  /// Check if running in production
  static bool get isProd => _config is ProdConfig;
}

