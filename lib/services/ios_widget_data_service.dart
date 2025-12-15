import 'dart:convert';
import 'package:flutter/services.dart';
import '../core/services/logger_service.dart';
import 'widget_data_service.dart';
import '../models/widget_config.dart';

/// Service for sharing widget data with iOS Widget Extension via App Group
class IOSWidgetDataService {
  static const MethodChannel _channel = MethodChannel('com.example.familyhub_mvp/app_group');
  static const String _appGroupIdentifier = 'group.com.example.familyhubMvp';

  /// Write widget data to App Group UserDefaults for iOS widgets
  static Future<void> writeWidgetDataToAppGroup(
    String hubId,
    WidgetData data,
  ) async {
    try {
      // Convert WidgetData to JSON
      final jsonData = {
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

      // Write to App Group via method channel
      await _channel.invokeMethod('writeWidgetData', {
        'hubId': hubId,
        'data': jsonData,
      });

      Logger.debug('Widget data written to App Group for hub: $hubId', tag: 'IOSWidgetDataService');
    } catch (e, st) {
      Logger.error('Error writing widget data to App Group', error: e, stackTrace: st, tag: 'IOSWidgetDataService');
      // Don't throw - widget data writing is non-critical
    }
  }

  /// Write available hubs list to App Group (for widget configuration)
  static Future<void> writeAvailableHubsToAppGroup(List<Map<String, String>> hubs) async {
    try {
      await _channel.invokeMethod('writeAvailableHubs', {
        'hubs': hubs,
      });

      Logger.debug('Available hubs written to App Group: ${hubs.length} hubs', tag: 'IOSWidgetDataService');
    } catch (e, st) {
      Logger.error('Error writing available hubs to App Group', error: e, stackTrace: st, tag: 'IOSWidgetDataService');
      // Don't throw - hub list writing is non-critical
    }
  }

  /// Update widget timeline (triggers widget refresh on iOS)
  static Future<void> updateWidgetTimeline(String hubId) async {
    try {
      await _channel.invokeMethod('updateWidgetTimeline', {
        'hubId': hubId,
      });

      Logger.debug('Widget timeline update requested for hub: $hubId', tag: 'IOSWidgetDataService');
    } catch (e, st) {
      Logger.error('Error updating widget timeline', error: e, stackTrace: st, tag: 'IOSWidgetDataService');
      // Don't throw - timeline update is non-critical
    }
  }
}

