import 'package:uuid/uuid.dart';

enum AssignmentStatus {
  pending,
  inProgress,
  completed,
  graded,
  overdue,
}

class Assignment {
  final String id;
  final String hubId;
  final String studentId;
  final String subject;
  final String title;
  final String? description;
  final DateTime dueDate;
  final AssignmentStatus status;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? completedAt;
  final String? grade;
  final String? feedback;

  Assignment({
    required this.id,
    required this.hubId,
    required this.studentId,
    required this.subject,
    required this.title,
    this.description,
    required this.dueDate,
    this.status = AssignmentStatus.pending,
    required this.createdAt,
    required this.createdBy,
    this.completedAt,
    this.grade,
    this.feedback,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'studentId': studentId,
        'subject': subject,
        'title': title,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'completedAt': completedAt?.toIso8601String(),
        'grade': grade,
        'feedback': feedback,
      };

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        studentId: json['studentId'] as String,
        subject: json['subject'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        dueDate: DateTime.parse(json['dueDate'] as String),
        status: AssignmentStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => AssignmentStatus.pending,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        grade: json['grade'] as String?,
        feedback: json['feedback'] as String?,
      );

  Assignment copyWith({
    String? id,
    String? hubId,
    String? studentId,
    String? subject,
    String? title,
    String? description,
    DateTime? dueDate,
    AssignmentStatus? status,
    DateTime? createdAt,
    String? createdBy,
    DateTime? completedAt,
    String? grade,
    String? feedback,
  }) {
    return Assignment(
      id: id ?? this.id,
      hubId: hubId ?? this.hubId,
      studentId: studentId ?? this.studentId,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      completedAt: completedAt ?? this.completedAt,
      grade: grade ?? this.grade,
      feedback: feedback ?? this.feedback,
    );
  }
}


