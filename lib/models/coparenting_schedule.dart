import 'package:cloud_firestore/cloud_firestore.dart';

/// Custody schedule for co-parenting hub
class CustodySchedule {
  final String id;
  final String hubId;
  final String childId; // User ID of the child
  final ScheduleType type;
  final Map<String, String> weeklySchedule; // dayOfWeek -> parentId
  final DateTime? startDate;
  final DateTime? endDate;
  final List<ScheduleException> exceptions; // Holidays, special dates
  final DateTime createdAt;
  final String createdBy;

  CustodySchedule({
    required this.id,
    required this.hubId,
    required this.childId,
    required this.type,
    this.weeklySchedule = const {},
    this.startDate,
    this.endDate,
    this.exceptions = const [],
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'childId': childId,
        'type': type.name,
        'weeklySchedule': weeklySchedule,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'exceptions': exceptions.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

  factory CustodySchedule.fromJson(Map<String, dynamic> json) => CustodySchedule(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        childId: json['childId'] as String,
        type: ScheduleType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ScheduleType.weekOnWeekOff,
        ),
        weeklySchedule: Map<String, String>.from(json['weeklySchedule'] as Map? ?? {}),
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : null,
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        exceptions: (json['exceptions'] as List<dynamic>?)
                ?.map((e) => ScheduleException.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
      );
}

enum ScheduleType {
  weekOnWeekOff,    // Alternating weeks
  twoTwoThree,      // 2-2-3 schedule
  everyOtherWeekend, // Every other weekend
  custom,           // Custom schedule
}

/// Schedule exception (holidays, special dates)
class ScheduleException {
  final DateTime date;
  final String parentId; // Who has custody on this date
  final String? reason; // e.g., "Holiday", "Special event"
  final bool isApproved;

  ScheduleException({
    required this.date,
    required this.parentId,
    this.reason,
    this.isApproved = false,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'parentId': parentId,
        if (reason != null) 'reason': reason,
        'isApproved': isApproved,
      };

  factory ScheduleException.fromJson(Map<String, dynamic> json) => ScheduleException(
        date: DateTime.parse(json['date'] as String),
        parentId: json['parentId'] as String,
        reason: json['reason'] as String?,
        isApproved: json['isApproved'] as bool? ?? false,
      );
}

