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

  @override
  String? get agoraAppId => null; // Disabled - see VideoCallService for implementation details
  
  @override
  String? get agoraAppCertificate => null; // Disabled - see VideoCallService for implementation details
  
  @override
  bool get enableVideoCalls => false; // Video calls disabled - code preserved for future use
  
  @override
  String? get chessWebSocketUrl => null; // WebSocket URL for real-time chess tournaments (to be configured when tournament server is set up)
  
  @override
  bool get enablePremiumHubs => true; // Enable premium features in dev for testing
  
  @override
  bool get enableExtendedFamilyHub => true;
  
  @override
  bool get enableHomeschoolingHub => true;
  
  @override
  bool get enableCoparentingHub => true;
  
  @override
  bool get enableEncryptedChat => true; // Enable encrypted chat in dev for testing
  
  @override
  bool get enableSmsFeature => true; // Enable SMS feature in dev for testing
  
  @override
  int get smsRateLimitPerMinute => 10; // Rate limit for SMS sending
}

