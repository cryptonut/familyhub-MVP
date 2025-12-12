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

  @override
  String? get agoraAppId => null; // Disabled - see VideoCallService for implementation details
  
  @override
  String? get agoraAppCertificate => null; // Disabled - see VideoCallService for implementation details
  
  @override
  bool get enableVideoCalls => false; // Video calls disabled - code preserved for future use
  
  @override
  String? get chessWebSocketUrl => null; // WebSocket URL for real-time chess tournaments (to be configured when tournament server is set up)
  
  @override
  bool get enablePremiumHubs => false; // Disable premium features in prod until ready for launch
  
  @override
  bool get enableExtendedFamilyHub => false;
  
  @override
  bool get enableHomeschoolingHub => false;
  
  @override
  bool get enableCoparentingHub => false;
  
  @override
  bool get enableEncryptedChat => false; // Disable encrypted chat in prod until ready for launch
}

