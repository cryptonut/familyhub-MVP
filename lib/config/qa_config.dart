import 'app_config.dart';

/// QA/Test environment configuration
class QaConfig implements AppConfig {
  @override
  String get environmentName => 'QA';

  @override
  String get appId => 'com.example.familyhub_mvp.test';

  @override
  String get appName => 'FamilyHub Test';

  @override
  bool get enableLogging => true; // Enabled for debugging test issues

  @override
  bool get enableCrashReporting => true; // Enabled to catch test issues

  @override
  String get firebaseProjectId => 'family-hub-71ff0';

  @override
  String get firebaseAppId => '1:559662117534:android:3c73d6ef5d0ddf6ee7c18f';

  @override
  String get firebaseApiKey => 'AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4'; // Can use same or different

  @override
  String get firestorePrefix => 'test_'; // Prefix for test data

  @override
  String? get apiBaseUrl => null; // Add if you have test API

  @override
  String? get agoraAppId => null; // TODO: Add Agora App ID for QA environment
  
  @override
  String? get agoraAppCertificate => null; // TODO: Add Agora App Certificate for QA environment
  
  @override
  String? get chessWebSocketUrl => null; // TODO: Add WebSocket URL for real-time chess if needed
}
