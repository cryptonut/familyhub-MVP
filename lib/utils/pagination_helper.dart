import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/logger_service.dart';

/// Helper class for implementing pagination with Firestore queries
class PaginationHelper {
  /// Default page size for pagination
  static const int defaultPageSize = 50;
  
  /// Maximum page size allowed
  static const int maxPageSize = 500;

  /// Get paginated documents from a Firestore query
  /// 
  /// [query] - The base Firestore query (must have orderBy)
  /// [limit] - Number of documents per page (default: 50, max: 500)
  /// [lastDocument] - The last document from previous page (null for first page)
  /// 
  /// Returns: PaginatedResult containing documents and lastDocument for next page
  static Future<PaginatedResult<T>> getPaginated<T>({
    required Query<T> query,
    int limit = defaultPageSize,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      // Validate and clamp limit
      final pageSize = limit.clamp(1, maxPageSize);
      
      // Build query with pagination
      Query<T> paginatedQuery = query.limit(pageSize);
      
      // Add startAfter for pagination (not first page)
      if (lastDocument != null) {
        paginatedQuery = paginatedQuery.startAfterDocument(lastDocument);
      }
      
      // Execute query
      final snapshot = await paginatedQuery.get();
      
      final documents = snapshot.docs;
      final lastDoc = documents.isNotEmpty ? documents.last : null;
      final hasMore = documents.length == pageSize;
      
      Logger.debug(
        'PaginationHelper: Retrieved ${documents.length} documents, hasMore: $hasMore',
        tag: 'PaginationHelper',
      );
      
      return PaginatedResult<T>(
        items: documents,
        lastDocument: lastDoc,
        hasMore: hasMore,
        pageSize: pageSize,
      );
    } catch (e, st) {
      Logger.error(
        'PaginationHelper: Error getting paginated results',
        error: e,
        stackTrace: st,
        tag: 'PaginationHelper',
      );
      rethrow;
    }
  }

  /// Get paginated stream from Firestore (for real-time updates)
  /// 
  /// Returns initial page as stream, subsequent pages need to be loaded manually
  /// 
  /// [query] - The base Firestore query (must have orderBy)
  /// [limit] - Number of documents per page (default: 50, max: 500)
  static Stream<PaginatedResult<T>> getPaginatedStream<T>({
    required Query<T> query,
    int limit = defaultPageSize,
  }) {
    final pageSize = limit.clamp(1, maxPageSize);
    
    return query
        .limit(pageSize)
        .snapshots()
        .map((snapshot) {
          final documents = snapshot.docs;
          final lastDoc = documents.isNotEmpty ? documents.last : null;
          final hasMore = documents.length == pageSize;
          
          return PaginatedResult<T>(
            items: documents,
            lastDocument: lastDoc,
            hasMore: hasMore,
            pageSize: pageSize,
          );
        });
  }
}

/// Result object for paginated queries
class PaginatedResult<T> {
  final List<QueryDocumentSnapshot<T>> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final int pageSize;

  PaginatedResult({
    required this.items,
    this.lastDocument,
    required this.hasMore,
    required this.pageSize,
  });

  bool get isEmpty => items.isEmpty;
  int get count => items.length;

  /// Check if this is the first page
  bool get isFirstPage => lastDocument == null && items.isNotEmpty;

  /// Create empty result
  factory PaginatedResult.empty({int pageSize = PaginationHelper.defaultPageSize}) {
    return PaginatedResult<T>(
      items: [],
      lastDocument: null,
      hasMore: false,
      pageSize: pageSize,
    );
  }
}

