import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/logger_service.dart';
import '../models/hub.dart';

/// Configuration for home screen widgets
class WidgetConfig {
  final String widgetId;
  final String hubId;
  final String hubName;
  final HubType hubType;
  final WidgetSize size;
  final List<WidgetDisplayOption> displayOptions;
  final DateTime createdAt;
  final DateTime? updatedAt;

  WidgetConfig({
    required this.widgetId,
    required this.hubId,
    required this.hubName,
    required this.hubType,
    required this.size,
    this.displayOptions = const [],
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'widgetId': widgetId,
        'hubId': hubId,
        'hubName': hubName,
        'hubType': hubType.value,
        'size': size.name,
        'displayOptions': displayOptions.map((o) => o.name).toList(),
        'createdAt': createdAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory WidgetConfig.fromJson(Map<String, dynamic> json) => WidgetConfig(
        widgetId: json['widgetId'] as String,
        hubId: json['hubId'] as String,
        hubName: json['hubName'] as String,
        hubType: HubTypeExtension.fromString(json['hubType'] as String),
        size: WidgetSize.values.firstWhere(
          (e) => e.name == json['size'],
          orElse: () => WidgetSize.medium,
        ),
        displayOptions: (json['displayOptions'] as List<dynamic>?)
                ?.map((o) => WidgetDisplayOption.values.firstWhere(
                      (e) => e.name == o,
                      orElse: () => WidgetDisplayOption.events,
                    ))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );
}

enum WidgetSize {
  small,   // 1x1 (Android), small (iOS)
  medium,  // 2x1 or 2x2 (Android), medium (iOS)
  large,   // 4x2 or 4x4 (Android), large (iOS)
}

enum WidgetDisplayOption {
  events,      // Show upcoming events
  messages,    // Show unread message count
  photos,      // Show recent photos
  tasks,       // Show pending tasks
  location,    // Show family member locations
}

/// Service for managing widget configurations
class WidgetConfigService {
  static const String _prefsKey = 'widget_configs';
  final SharedPreferences _prefs;

  WidgetConfigService(this._prefs);

  /// Save widget configuration
  Future<void> saveConfig(WidgetConfig config) async {
    try {
      final configs = await getConfigs();
      final index = configs.indexWhere((c) => c.widgetId == config.widgetId);
      
      if (index >= 0) {
        configs[index] = config.copyWith(updatedAt: DateTime.now());
      } else {
        configs.add(config);
      }

      final jsonList = configs.map((c) => c.toJson()).toList();
      await _prefs.setString(_prefsKey, json.encode(jsonList));
      
      Logger.info('Widget config saved: ${config.widgetId}', tag: 'WidgetConfigService');
    } catch (e) {
      Logger.error('Error saving widget config', error: e, tag: 'WidgetConfigService');
      rethrow;
    }
  }

  /// Get all widget configurations
  Future<List<WidgetConfig>> getConfigs() async {
    try {
      final jsonString = _prefs.getString(_prefsKey);
      if (jsonString == null) return [];

      final jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => WidgetConfig.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error loading widget configs', error: e, tag: 'WidgetConfigService');
      return [];
    }
  }

  /// Get configuration for a specific widget
  Future<WidgetConfig?> getConfig(String widgetId) async {
    final configs = await getConfigs();
    try {
      return configs.firstWhere((c) => c.widgetId == widgetId);
    } catch (e) {
      return null;
    }
  }

  /// Delete widget configuration
  Future<void> deleteConfig(String widgetId) async {
    try {
      final configs = await getConfigs();
      configs.removeWhere((c) => c.widgetId == widgetId);
      
      final jsonList = configs.map((c) => c.toJson()).toList();
      await _prefs.setString(_prefsKey, json.encode(jsonList));
      
      Logger.info('Widget config deleted: $widgetId', tag: 'WidgetConfigService');
    } catch (e) {
      Logger.error('Error deleting widget config', error: e, tag: 'WidgetConfigService');
      rethrow;
    }
  }
}

extension WidgetConfigCopyWith on WidgetConfig {
  WidgetConfig copyWith({
    String? widgetId,
    String? hubId,
    String? hubName,
    HubType? hubType,
    WidgetSize? size,
    List<WidgetDisplayOption>? displayOptions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      WidgetConfig(
        widgetId: widgetId ?? this.widgetId,
        hubId: hubId ?? this.hubId,
        hubName: hubName ?? this.hubName,
        hubType: hubType ?? this.hubType,
        size: size ?? this.size,
        displayOptions: displayOptions ?? this.displayOptions,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

