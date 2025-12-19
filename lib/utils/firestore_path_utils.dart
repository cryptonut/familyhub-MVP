import '../config/config.dart';

/// Utility class for constructing Firestore collection paths with environment prefix
/// 
/// This ensures data isolation between dev, qa, and prod environments by prepending
/// the `firestorePrefix` from the current flavor configuration to collection paths.
/// 
/// Example:
/// - Dev: `dev_families/$familyId/tasks`
/// - QA: `test_families/$familyId/tasks`
/// - Prod: `families/$familyId/tasks` (no prefix)
class FirestorePathUtils {
  /// Get a collection path with the appropriate environment prefix
  /// 
  /// Handles both simple paths (e.g., 'users') and complex paths (e.g., 'families/$familyId/tasks')
  /// 
  /// [basePath] - The base collection path without prefix
  /// Returns the path with prefix prepended if configured
  static String getCollectionPath(String basePath) {
    final prefix = Config.current.firestorePrefix;
    
    // If no prefix configured, return path as-is (production)
    if (prefix.isEmpty) {
      return basePath;
    }
    
    // Handle paths with slashes (e.g., 'families/$familyId/messages')
    if (basePath.contains('/')) {
      final parts = basePath.split('/');
      // Only prefix the first part (collection name), not variables or subcollections
      // e.g., 'families/$familyId/messages' -> 'dev_families/$familyId/messages'
      if (parts.isNotEmpty) {
        parts[0] = '$prefix${parts[0]}';
      }
      return parts.join('/');
    }
    
    // Simple path (e.g., 'users')
    return '$prefix$basePath';
  }
  
  /// Get a user document path with prefix
  /// 
  /// [userId] - The user ID
  /// Returns: 'dev_users/$userId' or 'users/$userId' (prod)
  static String getUserPath(String userId) {
    return getCollectionPath('users/$userId');
  }
  
  /// Get a user collection path with prefix
  /// 
  /// Returns: 'dev_users' or 'users' (prod)
  static String getUsersCollection() {
    return getCollectionPath('users');
  }
  
  /// Get a family document path with prefix
  /// 
  /// [familyId] - The family ID
  /// Returns: 'dev_families/$familyId' or 'families/$familyId' (prod)
  static String getFamilyPath(String familyId) {
    return getCollectionPath('families/$familyId');
  }
  
  /// Get a family collection path with prefix
  /// 
  /// Returns: 'dev_families' or 'families' (prod)
  static String getFamiliesCollection() {
    return getCollectionPath('families');
  }
  
  /// Get a family subcollection path with prefix
  /// 
  /// [familyId] - The family ID
  /// [subcollection] - The subcollection name (e.g., 'tasks', 'messages', 'events')
  /// Returns: 'dev_families/$familyId/tasks' or 'families/$familyId/tasks' (prod)
  static String getFamilySubcollectionPath(String familyId, String subcollection) {
    return getCollectionPath('families/$familyId/$subcollection');
  }
  
  /// Get a user subcollection path with prefix
  /// 
  /// [userId] - The user ID
  /// [subcollection] - The subcollection name (e.g., 'navigationOrder', 'ignoredConflicts')
  /// Returns: 'dev_users/$userId/navigationOrder' or 'users/$userId/navigationOrder' (prod)
  static String getUserSubcollectionPath(String userId, String subcollection) {
    return getCollectionPath('users/$userId/$subcollection');
  }
  
  /// Get a hub subcollection path with prefix
  /// 
  /// [hubId] - The hub ID
  /// [subcollection] - The subcollection name (e.g., 'messages', 'assignments', 'expenses')
  /// Returns: 'dev_hubs/$hubId/messages' or 'hubs/$hubId/messages' (prod)
  static String getHubSubcollectionPath(String hubId, String subcollection) {
    return getCollectionPath('hubs/$hubId/$subcollection');
  }
  
  /// Get a budget subcollection path with prefix
  /// 
  /// [familyId] - The family ID
  /// [budgetId] - The budget ID
  /// [subcollection] - The subcollection name (e.g., 'transactions', 'categories', 'recurringTransactions')
  /// Returns: 'dev_families/$familyId/budgets/$budgetId/transactions' or 'families/$familyId/budgets/$budgetId/transactions' (prod)
  static String getBudgetSubcollectionPath(String familyId, String budgetId, String subcollection) {
    return getCollectionPath('families/$familyId/budgets/$budgetId/$subcollection');
  }
}

