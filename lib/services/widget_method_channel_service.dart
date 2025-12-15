import 'package:flutter/services.dart';
import '../core/services/logger_service.dart';
import 'widget_data_service.dart';
import '../models/widget_config.dart';

/// Service for handling method channel calls from Android/iOS widgets
class WidgetMethodChannelService {
  static const MethodChannel _channel = MethodChannel('com.example.familyhub_mvp/widget');

  /// Initialize method channel handlers
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
    Logger.info('Widget method channel initialized', tag: 'WidgetMethodChannelService');
  }

  /// Handle method calls from native widgets
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    try {
      Logger.debug('Widget method call: ${call.method}', tag: 'WidgetMethodChannelService');

      switch (call.method) {
        case 'getWidgetData':
          return await _handleGetWidgetData(call.arguments);
        case 'getWidgetConfig':
          return await _handleGetWidgetConfig(call.arguments);
        default:
          Logger.warning('Unknown widget method: ${call.method}', tag: 'WidgetMethodChannelService');
          throw PlatformException(
            code: 'UNKNOWN_METHOD',
            message: 'Unknown method: ${call.method}',
          );
      }
    } catch (e, st) {
      Logger.error('Error handling widget method call', error: e, stackTrace: st, tag: 'WidgetMethodChannelService');
      throw PlatformException(
        code: 'ERROR',
        message: e.toString(),
      );
    }
  }

  /// Handle getWidgetData method call
  static Future<Map<String, dynamic>> _handleGetWidgetData(dynamic arguments) async {
    try {
      final args = arguments as Map<dynamic, dynamic>;
      final widgetId = args['widgetId'] as String;
      final hubId = args['hubId'] as String?;
      final hubName = args['hubName'] as String? ?? 'Family Hub';
      final hubType = args['hubType'] as String? ?? 'family';

      if (hubId == null) {
        throw PlatformException(
          code: 'INVALID_ARGUMENTS',
          message: 'hubId is required',
        );
      }

      // Create widget config from arguments
      final displayOptionsMap = args['displayOptions'] as Map<dynamic, dynamic>? ?? {};
      final displayOptions = <String, bool>{
        'events': displayOptionsMap['events'] as bool? ?? true,
        'messages': displayOptionsMap['messages'] as bool? ?? true,
        'tasks': displayOptionsMap['tasks'] as bool? ?? false,
        'photos': displayOptionsMap['photos'] as bool? ?? false,
      };

      final config = WidgetConfig(
        widgetId: widgetId,
        userId: args['userId'] as String? ?? '',
        hubId: hubId,
        hubName: hubName,
        hubType: hubType,
        widgetSize: args['widgetSize'] as String? ?? 'medium',
        displayOptions: displayOptions,
        updateFrequency: args['updateFrequency'] as int? ?? 30,
        createdAt: DateTime.now(),
      );

      // Get widget data
      final widgetDataService = WidgetDataService();
      final data = await widgetDataService.getWidgetData(hubId, config);

      // Convert to Map for native code
      return {
        'hubId': data.hubId,
        'hubName': data.hubName,
        'upcomingEvents': data.upcomingEvents.map((e) => {
              'id': e.id,
              'title': e.title,
              'startTime': e.startTime.toIso8601String(),
              'location': e.location,
            }).toList(),
        'unreadMessageCount': data.unreadMessageCount,
        'pendingTasksCount': data.pendingTasksCount,
        'lastUpdated': data.lastUpdated.toIso8601String(),
      };
    } catch (e, st) {
      Logger.error('Error getting widget data', error: e, stackTrace: st, tag: 'WidgetMethodChannelService');
      rethrow;
    }
  }

  /// Handle getWidgetConfig method call
  static Future<Map<String, dynamic>?> _handleGetWidgetConfig(dynamic arguments) async {
    try {
      // For now, return null - config should be stored in SharedPreferences by native code
      // This can be enhanced later to fetch from Firestore
      // widgetId is available but not used yet
      return null;
    } catch (e, st) {
      Logger.error('Error getting widget config', error: e, stackTrace: st, tag: 'WidgetMethodChannelService');
      return null;
    }
  }

  /// Update widget data (called from Flutter to trigger native widget update)
  static Future<void> updateWidget(String widgetId) async {
    try {
      await _channel.invokeMethod('updateWidget', {'widgetId': widgetId});
      Logger.debug('Widget update triggered: $widgetId', tag: 'WidgetMethodChannelService');
    } catch (e, st) {
      Logger.error('Error updating widget', error: e, stackTrace: st, tag: 'WidgetMethodChannelService');
    }
  }
}


