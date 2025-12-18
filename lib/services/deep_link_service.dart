import 'package:flutter/material.dart';
import '../core/services/logger_service.dart';
import '../services/hub_service.dart';
import '../models/hub.dart';
import '../screens/hubs/my_hubs_screen.dart';
import '../screens/homeschooling/homeschooling_hub_screen.dart';
import '../screens/extended_family/extended_family_hub_screen.dart';
import '../screens/coparenting/coparenting_hub_screen.dart';
import '../screens/library/library_hub_screen.dart';
import '../screens/hubs/my_friends_hub_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/tasks/tasks_screen.dart';
import '../screens/chat/chat_tabs_screen.dart';

/// Service for handling deep links from widgets and other sources
class DeepLinkService {
  /// Handle deep link URI
  /// 
  /// Supported formats:
  /// - familyhub://hub/{hubId}
  /// - familyhub://hub/{hubId}/screen/{screenName}
  /// - familyhub://event/{eventId}
  /// - familyhub://task/{taskId}
  /// - familyhub://message/{messageId}
  Future<void> handleDeepLink(BuildContext context, Uri uri) async {
    try {
      Logger.debug('Handling deep link: $uri', tag: 'DeepLinkService');

      if (uri.scheme != 'familyhub') {
        Logger.warning('Unknown deep link scheme: ${uri.scheme}', tag: 'DeepLinkService');
        return;
      }

      final pathSegments = uri.pathSegments;
      if (pathSegments.isEmpty) {
        Logger.warning('Empty deep link path', tag: 'DeepLinkService');
        return;
      }

      final route = pathSegments[0]; // 'hub', 'event', 'task', 'message'

      switch (route) {
        case 'hub':
          await _handleHubDeepLink(context, pathSegments);
          break;
        case 'event':
          await _handleEventDeepLink(context, pathSegments);
          break;
        case 'task':
          await _handleTaskDeepLink(context, pathSegments);
          break;
        case 'message':
          await _handleMessageDeepLink(context, pathSegments);
          break;
        case 'widget':
          // Widget deep links handled separately
          Logger.warning('Widget deep links should use hub route', tag: 'DeepLinkService');
          break;
      }
    } catch (e, st) {
      Logger.error('Error handling deep link', error: e, stackTrace: st, tag: 'DeepLinkService');
    }
  }

  /// Handle hub deep link
  /// Format: familyhub://hub/{hubId} or familyhub://hub/{hubId}/screen/{screenName}
  Future<void> _handleHubDeepLink(BuildContext context, List<String> pathSegments) async {
    if (pathSegments.length < 2) {
      Logger.warning('Invalid hub deep link: missing hubId', tag: 'DeepLinkService');
      return;
    }

    final hubId = pathSegments[1];
    String? screenName;

    // Check for screen parameter
    if (pathSegments.length >= 4 && pathSegments[2] == 'screen') {
      screenName = pathSegments[3];
    }

    // Navigate to hub
    if (!context.mounted) return;

    try {
      final hubService = HubService();
      final hub = await hubService.getHub(hubId);
      
      if (hub == null) {
        Logger.warning('Hub not found: $hubId', tag: 'DeepLinkService');
        // Navigate to My Hubs screen as fallback
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const MyHubsScreen()),
        );
        return;
      }

      Logger.debug('Navigating to hub: $hubId (${hub.hubType.value}), screen: $screenName', tag: 'DeepLinkService');

      // Navigate to appropriate hub screen based on hub type
      Widget? targetScreen;
      switch (hub.hubType) {
        case HubType.homeschooling:
          targetScreen = HomeschoolingHubScreen(hubId: hubId);
          break;
        case HubType.extendedFamily:
          targetScreen = ExtendedFamilyHubScreen(hubId: hubId);
          break;
        case HubType.coparenting:
          targetScreen = CoparentingHubScreen(hubId: hubId);
          break;
        case HubType.library:
          targetScreen = LibraryHubScreen(hub: hub);
          break;
        case HubType.family:
        default:
          targetScreen = MyFriendsHubScreen(hub: hub);
          break;
      }

      if (targetScreen != null && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => targetScreen!),
        );
      }
    } catch (e, st) {
      Logger.error('Error navigating to hub', error: e, stackTrace: st, tag: 'DeepLinkService');
      // Fallback to My Hubs screen
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const MyHubsScreen()),
        );
      }
    }
  }

  /// Handle event deep link
  /// Format: familyhub://event/{eventId}
  Future<void> _handleEventDeepLink(BuildContext context, List<String> pathSegments) async {
    if (pathSegments.length < 2) {
      Logger.warning('Invalid event deep link: missing eventId', tag: 'DeepLinkService');
      return;
    }

    final eventId = pathSegments[1];

    if (!context.mounted) return;

    Logger.debug('Navigating to event: $eventId', tag: 'DeepLinkService');
    
    // Navigate to calendar screen - event detail can be shown via a dialog or parameter
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CalendarScreen(),
          settings: RouteSettings(arguments: {'eventId': eventId}),
        ),
      );
    }
  }

  /// Handle task deep link
  /// Format: familyhub://task/{taskId}
  Future<void> _handleTaskDeepLink(BuildContext context, List<String> pathSegments) async {
    if (pathSegments.length < 2) {
      Logger.warning('Invalid task deep link: missing taskId', tag: 'DeepLinkService');
      return;
    }

    final taskId = pathSegments[1];

    if (!context.mounted) return;

    Logger.debug('Navigating to task: $taskId', tag: 'DeepLinkService');
    
    // Navigate to tasks screen - task detail can be shown via a dialog or parameter
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const TasksScreen(),
          settings: RouteSettings(arguments: {'taskId': taskId}),
        ),
      );
    }
  }

  /// Handle message deep link
  /// Format: familyhub://message/{messageId}
  Future<void> _handleMessageDeepLink(BuildContext context, List<String> pathSegments) async {
    if (pathSegments.length < 2) {
      Logger.warning('Invalid message deep link: missing messageId', tag: 'DeepLinkService');
      return;
    }

    final messageId = pathSegments[1];

    if (!context.mounted) return;

    Logger.debug('Navigating to message: $messageId', tag: 'DeepLinkService');
    
    // Navigate to chat screen - message can be highlighted via parameter
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ChatTabsScreen(),
          settings: RouteSettings(arguments: {'messageId': messageId}),
        ),
      );
    }
  }

  /// Generate deep link URI for a hub
  static Uri generateHubDeepLink(String hubId, {String? screen}) {
    if (screen != null) {
      return Uri.parse('familyhub://hub/$hubId/screen/$screen');
    }
    return Uri.parse('familyhub://hub/$hubId');
  }

  /// Generate deep link URI for an event
  static Uri generateEventDeepLink(String eventId) {
    return Uri.parse('familyhub://event/$eventId');
  }

  /// Generate deep link URI for a task
  static Uri generateTaskDeepLink(String taskId) {
    return Uri.parse('familyhub://task/$taskId');
  }

  /// Generate deep link URI for a message
  static Uri generateMessageDeepLink(String messageId) {
    return Uri.parse('familyhub://message/$messageId');
  }
}


