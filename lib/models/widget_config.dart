import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration model for Family Hub widgets
class WidgetConfig {
  final String widgetId;
  final String userId;
  final String hubId;
  final String hubName;
  final String hubType; // 'family', 'extended_family', 'homeschooling', 'coparenting'
  final String widgetSize; // 'small', 'medium', 'large'
  final Map<String, bool> displayOptions; // 'events', 'messages', 'tasks', 'photos'
  final int updateFrequency; // minutes
  final DateTime createdAt;
  final DateTime? updatedAt;

  WidgetConfig({
    required this.widgetId,
    required this.userId,
    required this.hubId,
    required this.hubName,
    required this.hubType,
    this.widgetSize = 'medium',
    Map<String, bool>? displayOptions,
    this.updateFrequency = 30,
    required this.createdAt,
    this.updatedAt,
  }) : displayOptions = displayOptions ?? {
          'events': true,
          'messages': true,
          'tasks': false,
          'photos': false,
        };

  Map<String, dynamic> toJson() {
    return {
      'widgetId': widgetId,
      'userId': userId,
      'hubId': hubId,
      'hubName': hubName,
      'hubType': hubType,
      'widgetSize': widgetSize,
      'displayOptions': displayOptions,
      'updateFrequency': updateFrequency,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory WidgetConfig.fromJson(Map<String, dynamic> json) {
    return WidgetConfig(
      widgetId: json['widgetId'] as String,
      userId: json['userId'] as String,
      hubId: json['hubId'] as String,
      hubName: json['hubName'] as String,
      hubType: json['hubType'] as String,
      widgetSize: json['widgetSize'] as String? ?? 'medium',
      displayOptions: json['displayOptions'] != null
          ? Map<String, bool>.from(json['displayOptions'] as Map)
          : null,
      updateFrequency: json['updateFrequency'] as int? ?? 30,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  WidgetConfig copyWith({
    String? widgetId,
    String? userId,
    String? hubId,
    String? hubName,
    String? hubType,
    String? widgetSize,
    Map<String, bool>? displayOptions,
    int? updateFrequency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WidgetConfig(
      widgetId: widgetId ?? this.widgetId,
      userId: userId ?? this.userId,
      hubId: hubId ?? this.hubId,
      hubName: hubName ?? this.hubName,
      hubType: hubType ?? this.hubType,
      widgetSize: widgetSize ?? this.widgetSize,
      displayOptions: displayOptions ?? this.displayOptions,
      updateFrequency: updateFrequency ?? this.updateFrequency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

