import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/logger_service.dart';
import '../models/widget_config.dart';
import '../models/hub.dart';
import '../models/calendar_event.dart';
import '../utils/firestore_path_utils.dart';
import 'calendar_service.dart';
import 'chat_service.dart';
import 'task_service.dart';
import 'hub_service.dart';

/// Data model for widget display
class WidgetData {
  final String hubId;
  final String hubName;
  final List<WidgetEvent> upcomingEvents;
  final int unreadMessageCount;
  final int pendingTasksCount;
  final DateTime lastUpdated;

  WidgetData({
    required this.hubId,
    required this.hubName,
    this.upcomingEvents = const [],
    this.unreadMessageCount = 0,
    this.pendingTasksCount = 0,
    required this.lastUpdated,
  });
}

class WidgetEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final String? location;

  WidgetEvent({
    required this.id,
    required this.title,
    required this.startTime,
    this.location,
  });
}

/// Service for fetching and formatting data for widgets
class WidgetDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CalendarService _calendarService = CalendarService();
  final ChatService _chatService = ChatService();
  final TaskService _taskService = TaskService();
  final HubService _hubService = HubService();

  /// Get widget data for a specific hub
  Future<WidgetData> getWidgetData(String hubId, WidgetConfig config) async {
    try {
      // Get hub to determine if it's extended family hub
      final hub = await _hubService.getHub(hubId);
      final hubName = hub?.name ?? config.hubName;

      // Fetch data based on display options
      final upcomingEvents = config.displayOptions['events'] == true
          ? await _getUpcomingEvents(hubId, config.hubType, hub: hub, limit: 3)
          : <WidgetEvent>[];

      final unreadMessageCount = config.displayOptions['messages'] == true
          ? await _getUnreadMessageCount(hubId, config.hubType, hub: hub)
          : 0;

      final pendingTasksCount = config.displayOptions['tasks'] == true
          ? await _getPendingTasksCount(hubId, config.hubType, hub: hub)
          : 0;

      return WidgetData(
        hubId: hubId,
        hubName: hubName,
        upcomingEvents: upcomingEvents,
        unreadMessageCount: unreadMessageCount,
        pendingTasksCount: pendingTasksCount,
        lastUpdated: DateTime.now(),
      );
    } catch (e, st) {
      Logger.error('Error getting widget data', error: e, stackTrace: st, tag: 'WidgetDataService');
      // Return empty data on error
      return WidgetData(
        hubId: hubId,
        hubName: config.hubName,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Get upcoming events for widget
  Future<List<WidgetEvent>> _getUpcomingEvents(
    String hubId,
    String hubType, {
    Hub? hub,
    int limit = 3,
  }) async {
    try {
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30));

      // Get events - if hub is extended family, we need to filter by hubId
      List<CalendarEvent> events;
      if (hub != null && hub.isExtendedFamilyHub) {
        // For extended family hubs, get all family events and filter by hubId
        final allEvents = await _calendarService.getEvents(limit: 100);
        events = allEvents
            .where((event) =>
                (event.hubId == hubId || event.hubIds.contains(hubId)) &&
                event.startTime.isAfter(now) &&
                event.startTime.isBefore(endDate))
            .toList();
      } else {
        // For family hubs, get all events and filter by date range
        final allEvents = await _calendarService.getEvents(limit: 100);
        events = allEvents
            .where((event) => event.startTime.isAfter(now) && event.startTime.isBefore(endDate))
            .toList();
      }

      return events
          .where((event) => event.startTime.isAfter(now))
          .take(limit)
          .map((event) => WidgetEvent(
                id: event.id,
                title: event.title,
                startTime: event.startTime,
                location: event.location,
              ))
          .toList();
    } catch (e, st) {
      Logger.error('Error getting upcoming events for widget', error: e, stackTrace: st, tag: 'WidgetDataService');
      return [];
    }
  }

  /// Get unread message count
  Future<int> _getUnreadMessageCount(
    String hubId,
    String hubType, {
    Hub? hub,
  }) async {
    try {
      if (hub != null && hub.isExtendedFamilyHub) {
        // For extended family hubs, get hub messages from stream
        final messagesStream = _chatService.getHubMessagesStream(hubId);
        final messagesSnapshot = await messagesStream.first;
        // TODO: Implement proper unread tracking
        return 0;
      } else {
        // For family hubs, get family messages
        final messages = await _chatService.getMessages(limit: 100);
        // TODO: Implement proper unread tracking
        return 0;
      }
    } catch (e, st) {
      Logger.error('Error getting unread message count', error: e, stackTrace: st, tag: 'WidgetDataService');
      return 0;
    }
  }

  /// Get pending tasks count
  Future<int> _getPendingTasksCount(
    String hubId,
    String hubType, {
    Hub? hub,
  }) async {
    try {
      // Tasks are currently family-level, not hub-specific
      // In the future, we might add hubId to tasks
      final tasks = await _taskService.getTasks(limit: 100);
      
      return tasks.where((task) => !task.isCompleted).length;
    } catch (e, st) {
      Logger.error('Error getting pending tasks count', error: e, stackTrace: st, tag: 'WidgetDataService');
      return 0;
    }
  }
}

