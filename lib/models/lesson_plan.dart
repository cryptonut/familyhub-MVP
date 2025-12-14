import 'package:uuid/uuid.dart';

enum LessonStatus {
  planned,
  inProgress,
  completed,
  cancelled,
}

class LessonPlan {
  final String id;
  final String hubId;
  final String subject;
  final String title;
  final String? description;
  final List<String> learningObjectives;
  final List<String> resources;
  final DateTime? scheduledDate;
  final int estimatedDurationMinutes;
  final LessonStatus status;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? completedAt;

  LessonPlan({
    required this.id,
    required this.hubId,
    required this.subject,
    required this.title,
    this.description,
    this.learningObjectives = const [],
    this.resources = const [],
    this.scheduledDate,
    this.estimatedDurationMinutes = 60,
    this.status = LessonStatus.planned,
    required this.createdAt,
    required this.createdBy,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'subject': subject,
        'title': title,
        'description': description,
        'learningObjectives': learningObjectives,
        'resources': resources,
        'scheduledDate': scheduledDate?.toIso8601String(),
        'estimatedDurationMinutes': estimatedDurationMinutes,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory LessonPlan.fromJson(Map<String, dynamic> json) => LessonPlan(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        subject: json['subject'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        learningObjectives: List<String>.from(json['learningObjectives'] as List? ?? []),
        resources: List<String>.from(json['resources'] as List? ?? []),
        scheduledDate: json['scheduledDate'] != null
            ? DateTime.parse(json['scheduledDate'] as String)
            : null,
        estimatedDurationMinutes: json['estimatedDurationMinutes'] as int? ?? 60,
        status: json['status'] != null
            ? LessonStatus.values.firstWhere(
                (e) => e.name == json['status'],
                orElse: () => LessonStatus.planned,
              )
            : LessonStatus.planned,
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );

  LessonPlan copyWith({
    String? id,
    String? hubId,
    String? subject,
    String? title,
    String? description,
    List<String>? learningObjectives,
    List<String>? resources,
    DateTime? scheduledDate,
    int? estimatedDurationMinutes,
    LessonStatus? status,
    DateTime? createdAt,
    String? createdBy,
    DateTime? completedAt,
  }) {
    return LessonPlan(
      id: id ?? this.id,
      hubId: hubId ?? this.hubId,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      description: description ?? this.description,
      learningObjectives: learningObjectives ?? this.learningObjectives,
      resources: resources ?? this.resources,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}


