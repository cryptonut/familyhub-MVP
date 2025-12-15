import 'package:uuid/uuid.dart';

enum ScheduleChangeStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

class ScheduleChangeRequest {
  final String id;
  final String hubId;
  final String childId;
  final DateTime requestedDate;
  final String requestedBy;
  final String? swapWithDate;
  final String? reason;
  final ScheduleChangeStatus status;
  final DateTime createdAt;
  final String? respondedBy;
  final DateTime? respondedAt;

  ScheduleChangeRequest({
    required this.id,
    required this.hubId,
    required this.childId,
    required this.requestedDate,
    required this.requestedBy,
    this.swapWithDate,
    this.reason,
    this.status = ScheduleChangeStatus.pending,
    required this.createdAt,
    this.respondedBy,
    this.respondedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'childId': childId,
        'requestedDate': requestedDate.toIso8601String(),
        'requestedBy': requestedBy,
        'swapWithDate': swapWithDate,
        'reason': reason,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'respondedBy': respondedBy,
        'respondedAt': respondedAt?.toIso8601String(),
      };

  factory ScheduleChangeRequest.fromJson(Map<String, dynamic> json) =>
      ScheduleChangeRequest(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        childId: json['childId'] as String,
        requestedDate: DateTime.parse(json['requestedDate'] as String),
        requestedBy: json['requestedBy'] as String,
        swapWithDate: json['swapWithDate'] as String?,
        reason: json['reason'] as String?,
        status: ScheduleChangeStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ScheduleChangeStatus.pending,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        respondedBy: json['respondedBy'] as String?,
        respondedAt: json['respondedAt'] != null
            ? DateTime.parse(json['respondedAt'] as String)
            : null,
      );

  ScheduleChangeRequest copyWith({
    String? id,
    String? hubId,
    String? childId,
    DateTime? requestedDate,
    String? requestedBy,
    String? swapWithDate,
    String? reason,
    ScheduleChangeStatus? status,
    DateTime? createdAt,
    String? respondedBy,
    DateTime? respondedAt,
  }) {
    return ScheduleChangeRequest(
      id: id ?? this.id,
      hubId: hubId ?? this.hubId,
      childId: childId ?? this.childId,
      requestedDate: requestedDate ?? this.requestedDate,
      requestedBy: requestedBy ?? this.requestedBy,
      swapWithDate: swapWithDate ?? this.swapWithDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedBy: respondedBy ?? this.respondedBy,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}


