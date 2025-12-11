import '../config/config.dart';

class FirestorePath {
  /// Returns the collection path with the environment-specific prefix.
  /// Example: 'families' -> 'dev_families' (in dev environment)
  static String getCollection(String collectionName) {
    final prefix = Config.current.firestorePrefix;
    return '$prefix$collectionName';
  }

  /// Helper to construct family sub-collection paths
  /// Example: getFamilyCollection('123', 'tasks') -> 'dev_families/123/tasks'
  static String getFamilyCollection(String familyId, String subCollection) {
    return '${getCollection('families')}/$familyId/$subCollection';
  }
}
