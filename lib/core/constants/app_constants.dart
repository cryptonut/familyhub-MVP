/// Application-wide constants to avoid magic strings and numbers
abstract class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ============================================
  // Timeouts
  // ============================================
  static const Duration authOperationTimeout = Duration(seconds: 30);
  static const Duration firestoreQueryTimeout = Duration(seconds: 20);
  static const Duration backgroundTaskTimeout = Duration(seconds: 5);
  static const Duration networkRequestTimeout = Duration(seconds: 15);
  static const Duration gRPCChannelInitDelay = Duration(milliseconds: 1000);
  
  // Legacy aliases for backward compatibility
  static const Duration authOperation = authOperationTimeout;
  static const Duration firestoreQuery = firestoreQueryTimeout;
  static const Duration backgroundTask = backgroundTaskTimeout;

  // ============================================
  // Limits
  // ============================================
  static const int usersQueryLimit = 50;
  static const int firestoreBatchSize = 500;
  static const int maxRetries = 3;
  static const int maxRetryDelaySeconds = 3;

  // ============================================
  // User Roles
  // ============================================
  static const String roleAdmin = 'admin';
  static const String roleBanker = 'banker';
  static const String roleApprover = 'approver';
  static const String roleTester = 'tester';

  // ============================================
  // Task/Job Status
  // ============================================
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusCompleted = 'completed';

  // ============================================
  // API Key Display
  // ============================================
  /// Number of characters to show when logging API keys (for security)
  static const int apiKeyDisplayLength = 10;
}

