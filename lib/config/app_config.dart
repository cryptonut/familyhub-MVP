/// Base app configuration interface
abstract class AppConfig {
  String get environmentName;
  String get appId;
  String get appName;
  bool get enableLogging;
  bool get enableCrashReporting;
  String get firebaseProjectId;
  String get firebaseAppId;
  String get firebaseApiKey;
  
  // Firestore collection prefixes (for data separation)
  String get firestorePrefix;
  
  // API endpoints (if you have backend APIs)
  String? get apiBaseUrl;
  
  // Agora video call configuration
  String? get agoraAppId;
  String? get agoraAppCertificate;
  bool get enableVideoCalls; // Feature flag to enable/disable video calls UI
  
  // WebSocket endpoints
  String? get chessWebSocketUrl;
}

