import '../core/services/logger_service.dart';
import '../models/chat_message.dart';
import '../models/task.dart';
import '../models/calendar_event.dart';
import '../models/family_photo.dart';
import 'chat_service.dart';
import 'task_service.dart';
import 'calendar_service.dart';
import 'photo_service.dart';
import 'auth_service.dart';

/// Search result types
enum SearchResultType {
  message,
  task,
  event,
  photo,
}

/// Individual search result
class SearchResult {
  final SearchResultType type;
  final dynamic item;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? highlightedText;

  SearchResult({
    required this.type,
    required this.item,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.highlightedText,
  });
}

/// Search results container
class SearchResults {
  final List<SearchResult> messages = [];
  final List<SearchResult> tasks = [];
  final List<SearchResult> events = [];
  final List<SearchResult> photos = [];

  List<SearchResult> get all => [...messages, ...tasks, ...events, ...photos];

  int get totalCount => all.length;
}

/// Service for comprehensive search across all content types
class SearchService {
  final ChatService _chatService = ChatService();
  final TaskService _taskService = TaskService();
  final CalendarService _calendarService = CalendarService();
  final PhotoService _photoService = PhotoService();
  final AuthService _authService = AuthService();

  /// Search across all content types
  Future<SearchResults> search({
    required String query,
    required String familyId,
    List<SearchResultType> types = SearchResultType.values,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return SearchResults();

    Logger.info('Starting search for "$query" in family $familyId', tag: 'SearchService');

    final results = SearchResults();
    final searchTerm = query.toLowerCase().trim();

    try {
      // Search messages
      if (types.contains(SearchResultType.message)) {
        results.messages.addAll(await _searchMessages(searchTerm, familyId, limit));
      }

      // Search tasks
      if (types.contains(SearchResultType.task)) {
        results.tasks.addAll(await _searchTasks(searchTerm, familyId, limit));
      }

      // Search events
      if (types.contains(SearchResultType.event)) {
        results.events.addAll(await _searchEvents(searchTerm, familyId, limit));
      }

      // Search photos
      if (types.contains(SearchResultType.photo)) {
        results.photos.addAll(await _searchPhotos(searchTerm, familyId, limit));
      }

      Logger.info(
        'Search completed: ${results.messages.length} messages, ${results.tasks.length} tasks, ${results.events.length} events, ${results.photos.length} photos',
        tag: 'SearchService'
      );

      return results;
    } catch (e, st) {
      Logger.error('Search failed', error: e, stackTrace: st, tag: 'SearchService');
      return SearchResults();
    }
  }

  /// Search messages
  Future<List<SearchResult>> _searchMessages(String query, String familyId, int limit) async {
    try {
      // Get recent messages (using pagination)
      final messages = await _chatService.getMessages(limit: limit * 2); // Get more to filter

      return messages
          .where((message) {
            return message.content.toLowerCase().contains(query) ||
                   (message.senderName?.toLowerCase().contains(query) ?? false);
          })
          .take(limit)
          .map((message) => SearchResult(
            type: SearchResultType.message,
            item: message,
            title: message.senderName ?? 'Unknown User',
            subtitle: message.content,
            timestamp: message.timestamp,
            highlightedText: _highlightMatch(message.content, query),
          ))
          .toList();
    } catch (e) {
      Logger.warning('Message search failed', error: e, tag: 'SearchService');
      return [];
    }
  }

  /// Search tasks
  Future<List<SearchResult>> _searchTasks(String query, String familyId, int limit) async {
    try {
      // Get recent tasks (using pagination)
      final tasks = await _taskService.getTasks(limit: limit * 2); // Get more to filter

      return tasks
          .where((task) {
            return task.title.toLowerCase().contains(query) ||
                   (task.description?.toLowerCase().contains(query) ?? false) ||
                   (task.assignedTo?.toLowerCase().contains(query) ?? false);
          })
          .take(limit)
          .map((task) => SearchResult(
            type: SearchResultType.task,
            item: task,
            title: task.title,
            subtitle: task.assignedTo != null ? 'Assigned to: ${task.assignedTo}' : 'Unassigned',
            timestamp: task.createdAt,
            highlightedText: _highlightMatch(task.title, query),
          ))
          .toList();
    } catch (e) {
      Logger.warning('Task search failed', error: e, tag: 'SearchService');
      return [];
    }
  }

  /// Search events
  Future<List<SearchResult>> _searchEvents(String query, String familyId, int limit) async {
    try {
      // Get recent events (using pagination)
      final events = await _calendarService.getEvents(limit: limit * 2); // Get more to filter

      return events
          .where((event) {
            return event.title.toLowerCase().contains(query) ||
                   (event.description?.toLowerCase().contains(query) ?? false) ||
                   (event.location?.toLowerCase().contains(query) ?? false);
          })
          .take(limit)
          .map((event) => SearchResult(
            type: SearchResultType.event,
            item: event,
            title: event.title,
            subtitle: event.location != null ? '📍 ${event.location}' : 'Calendar Event',
            timestamp: event.startTime,
            highlightedText: _highlightMatch(event.title, query),
          ))
          .toList();
    } catch (e) {
      Logger.warning('Event search failed', error: e, tag: 'SearchService');
      return [];
    }
  }

  /// Search photos
  Future<List<SearchResult>> _searchPhotos(String query, String familyId, int limit) async {
    try {
      // Get recent photos (using pagination)
      final photos = await _photoService.getPhotos(familyId, limit: limit * 2); // Get more to filter

      return photos
          .where((photo) {
            return (photo.caption?.toLowerCase().contains(query) ?? false) ||
                   photo.uploadedByName.toLowerCase().contains(query) ||
                   photo.taggedMemberIds.any((tag) => tag.toLowerCase().contains(query));
          })
          .take(limit)
          .map((photo) => SearchResult(
            type: SearchResultType.photo,
            item: photo,
            title: photo.uploadedByName,
            subtitle: photo.caption ?? 'Photo',
            timestamp: photo.uploadedAt,
            highlightedText: _highlightMatch(photo.caption ?? '', query),
          ))
          .toList();
    } catch (e) {
      Logger.warning('Photo search failed', error: e, tag: 'SearchService');
      return [];
    }
  }

  /// Highlight matching text in search results
  String _highlightMatch(String text, String query) {
    if (query.isEmpty) return text;

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) return text;

    final before = text.substring(0, index);
    final match = text.substring(index, index + query.length);
    final after = text.substring(index + query.length);

    return '$before**$match**$after';
  }

  /// Quick search for recent items only (faster)
  Future<SearchResults> quickSearch({
    required String query,
    required String familyId,
    int quickLimit = 5,
  }) async {
    return search(
      query: query,
      familyId: familyId,
      limit: quickLimit,
    );
  }

  /// Search with filters
  Future<SearchResults> advancedSearch({
    required String query,
    required String familyId,
    List<SearchResultType> types = SearchResultType.values,
    DateTime? startDate,
    DateTime? endDate,
    String? assignedTo, // for tasks
    String? createdBy, // for events/tasks
    int limit = 20,
  }) async {
    final results = await search(
      query: query,
      familyId: familyId,
      types: types,
      limit: limit * 2, // Get more to filter by date/user
    );

    // Apply additional filters
    if (startDate != null || endDate != null || assignedTo != null || createdBy != null) {
      _applyAdvancedFilters(results, startDate, endDate, assignedTo, createdBy);
    }

    // Limit results
    _limitResults(results, limit);

    return results;
  }

  /// Apply advanced filters to search results
  void _applyAdvancedFilters(
    SearchResults results,
    DateTime? startDate,
    DateTime? endDate,
    String? assignedTo,
    String? createdBy,
  ) {
    // Filter tasks by assignment
    if (assignedTo != null) {
      results.tasks.retainWhere((result) {
        final task = result.item as Task;
        return (task.assignedTo?.toLowerCase().contains(assignedTo.toLowerCase()) ?? false);
      });
    }

    // Filter by date range
    if (startDate != null || endDate != null) {
      final filterByDate = (SearchResult result) {
        if (startDate != null && result.timestamp.isBefore(startDate)) return false;
        if (endDate != null && result.timestamp.isAfter(endDate)) return false;
        return true;
      };

      results.messages.retainWhere(filterByDate);
      results.tasks.retainWhere(filterByDate);
      results.events.retainWhere(filterByDate);
      results.photos.retainWhere(filterByDate);
    }

    // Filter by creator
    if (createdBy != null) {
      final lowerCreatedBy = createdBy.toLowerCase();

      results.tasks.retainWhere((result) {
        final task = result.item as Task;
        return (task.createdBy?.toLowerCase().contains(lowerCreatedBy) ?? false);
      });

      results.events.retainWhere((result) {
        final event = result.item as CalendarEvent;
        return (event.createdBy?.toLowerCase().contains(lowerCreatedBy) ?? false);
      });

      results.photos.retainWhere((result) {
        final photo = result.item as FamilyPhoto;
        return photo.uploadedBy.toLowerCase().contains(lowerCreatedBy) ||
               photo.uploadedByName.toLowerCase().contains(lowerCreatedBy);
      });
    }
  }

  /// Limit the number of results per category
  void _limitResults(SearchResults results, int limit) {
    results.messages.take(limit);
    results.tasks.take(limit);
    results.events.take(limit);
    results.photos.take(limit);
  }
}
