import 'app_config.dart';

/// Development environment configuration
class DevConfig implements AppConfig {
  @override
  String get environmentName => 'Development';

  @override
  String get appId => 'com.example.familyhub_mvp.dev';

  @override
  String get appName => 'FamilyHub Dev';

  @override
  bool get enableLogging => true; // Always enabled in dev

  @override
  bool get enableCrashReporting => false; // Disabled in dev to avoid noise

  @override
  String get firebaseProjectId => 'family-hub-71ff0';

  @override
  String get firebaseAppId => '1:559662117534:android:7b3b41176f0d550ee7c18f';

  @override
  String get firebaseApiKey => 'AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4'; // Can use same or different

  @override
  String get firestorePrefix => 'dev_'; // Prefix for dev data

  @override
  String? get apiBaseUrl => null; // Add if you have dev API
}

