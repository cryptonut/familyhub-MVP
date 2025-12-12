import 'package:flutter/material.dart';
import '../core/services/logger_service.dart';

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
        default:
          Logger.warning('Unknown deep link route: $route', tag: 'DeepLinkService');
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
    if (context.mounted) {
      // TODO: Implement navigation to hub screen
      // For now, navigate to home and pass hubId as parameter
      // This will be updated when hub navigation is implemented
      Logger.debug('Navigating to hub: $hubId, screen: $screenName', tag: 'DeepLinkService');
      
      // Example navigation (will be updated with actual routes):
      // GoRouter.of(context).go('/hubs/$hubId${screenName != null ? '/$screenName' : ''}');
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

    if (context.mounted) {
      // TODO: Implement navigation to event detail screen
      Logger.debug('Navigating to event: $eventId', tag: 'DeepLinkService');
      // GoRouter.of(context).go('/calendar/events/$eventId');
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

    if (context.mounted) {
      // TODO: Implement navigation to task detail screen
      Logger.debug('Navigating to task: $taskId', tag: 'DeepLinkService');
      // GoRouter.of(context).go('/tasks/$taskId');
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

    if (context.mounted) {
      // TODO: Implement navigation to message/chat screen
      Logger.debug('Navigating to message: $messageId', tag: 'DeepLinkService');
      // GoRouter.of(context).go('/chat?messageId=$messageId');
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

