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
  
  // Premium Feature Flags
  /// Enable premium hub features (Extended Family, Home Schooling, Co-Parenting)
  bool get enablePremiumHubs;
  
  /// Enable Extended Family Hub feature
  bool get enableExtendedFamilyHub;
  
  /// Enable Home Schooling Hub feature
  bool get enableHomeschoolingHub;
  
  /// Enable Co-Parenting Hub feature
  bool get enableCoparentingHub;
  
  /// Enable encrypted chat feature (premium)
  bool get enableEncryptedChat;
}

