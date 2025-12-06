import 'package:flutter/material.dart';
import 'calendar_event.dart';

class EventTemplate {
  final String id;
  final String name;
  final String title;
  final String? description;
  final String? location;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final Color? color;
  final String? recurrenceRule; // Simple format: "daily", "weekly", "monthly", "yearly" or RRULE format
  final List<String> defaultInvitees;
  final String createdBy;
  final DateTime createdAt;

  EventTemplate({
    required this.id,
    required this.name,
    required this.title,
    this.description,
    this.location,
    this.startTime,
    this.endTime,
    this.color,
    this.recurrenceRule,
    this.defaultInvitees = const [],
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'description': description,
      'location': location,
      'startTime': startTime != null
          ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'endTime': endTime != null
          ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'color': color != null ? '#${color!.value.toRadixString(16).padLeft(8, '0')}' : null,
      'recurrenceRule': recurrenceRule,
      'defaultInvitees': defaultInvitees,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory EventTemplate.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? timeStr) {
      if (timeStr == null) return null;
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    Color? parseColor(String? colorStr) {
      if (colorStr == null) return null;
      try {
        return Color(int.parse(colorStr.replaceFirst('#', '0x')));
      } catch (e) {
        return null;
      }
    }

    return EventTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startTime: parseTime(json['startTime'] as String?),
      endTime: parseTime(json['endTime'] as String?),
      color: parseColor(json['color'] as String?),
      recurrenceRule: json['recurrenceRule'] != null
          ? json['recurrenceRule'] as String
          : null,
      defaultInvitees: (json['defaultInvitees'] as List<dynamic>?)?.cast<String>() ?? [],
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  EventTemplate copyWith({
    String? id,
    String? name,
    String? title,
    String? description,
    String? location,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    Color? color,
    String? recurrenceRule,
    List<String>? defaultInvitees,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return EventTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      color: color ?? this.color,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      defaultInvitees: defaultInvitees ?? this.defaultInvitees,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

