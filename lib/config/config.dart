import 'package:flutter/foundation.dart';
import 'dev_config.dart';
import 'qa_config.dart';
import 'prod_config.dart';
import 'app_config.dart';

/// Global app configuration based on build flavor
class Config {
  static AppConfig? _config;

  /// Initialize configuration based on flavor
  /// This is called from main.dart
  /// Flavor is passed via --dart-define=FLAVOR=xxx during build
  static void initialize() {
    // Determine flavor from compile-time constants
    // Default to prod if not specified (for backward compatibility)
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
    
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
      print('   Flavor: $flavor');
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

