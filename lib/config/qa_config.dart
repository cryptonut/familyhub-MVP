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
  String? get agoraAppId => null; // Disabled - see VideoCallService for implementation details
  
  @override
  String? get agoraAppCertificate => null; // Disabled - see VideoCallService for implementation details
  
  @override
  bool get enableVideoCalls => false; // Video calls disabled - code preserved for future use
  
  @override
  String? get chessWebSocketUrl => null; // WebSocket URL for real-time chess tournaments (to be configured when tournament server is set up)
}
