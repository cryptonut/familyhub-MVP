import 'app_config.dart';

/// Production environment configuration
class ProdConfig implements AppConfig {
  @override
  String get environmentName => 'Production';

  @override
  String get appId => 'com.example.familyhub_mvp';

  @override
  String get appName => 'FamilyHub';

  @override
  bool get enableLogging => false; // Disabled in production for performance

  @override
  bool get enableCrashReporting => true; // Always enabled in production

  @override
  String get firebaseProjectId => 'family-hub-71ff0';

  @override
  String get firebaseAppId => '1:559662117534:android:a59145c8a69587aee7c18f'; // Current prod app ID

  @override
  String get firebaseApiKey => 'AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4';

  @override
  String get firestorePrefix => ''; // No prefix for production data

  @override
  String? get apiBaseUrl => null; // Add if you have prod API
}

