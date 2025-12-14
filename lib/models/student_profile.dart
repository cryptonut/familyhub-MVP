import 'package:cloud_firestore/cloud_firestore.dart';

/// Student profile for homeschooling hub
class StudentProfile {
  final String id;
  final String hubId;
  final String userId; // User ID of the student
  final String name;
  final DateTime? dateOfBirth;
  final String? gradeLevel; // e.g., "Grade 5", "Kindergarten"
  final List<String> subjects; // Subjects being taught
  final Map<String, double> grades; // subject -> average grade
  final DateTime createdAt;
  final String createdBy;

  StudentProfile({
    required this.id,
    required this.hubId,
    required this.userId,
    required this.name,
    this.dateOfBirth,
    this.gradeLevel,
    this.subjects = const [],
    this.grades = const {},
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'userId': userId,
        'name': name,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
        if (gradeLevel != null) 'gradeLevel': gradeLevel,
        'subjects': subjects,
        'grades': grades.map((k, v) => MapEntry(k, v)),
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        userId: json['userId'] as String,
        name: json['name'] as String,
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.parse(json['dateOfBirth'] as String)
            : null,
        gradeLevel: json['gradeLevel'] as String?,
        subjects: List<String>.from(json['subjects'] as List? ?? []),
        grades: (json['grades'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as double)) ??
            {},
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
      );
}

/// Assignment for homeschooling
class Assignment {
  final String id;
  final String hubId;
  final String studentId;
  final String subject;
  final String title;
  final String? description;
  final DateTime dueDate;
  final DateTime? completedAt;
  final String? completedBy;
  final double? grade; // 0-100
  final String? feedback;
  final AssignmentStatus status;
  final DateTime createdAt;
  final String createdBy;

  Assignment({
    required this.id,
    required this.hubId,
    required this.studentId,
    required this.subject,
    required this.title,
    this.description,
    required this.dueDate,
    this.completedAt,
    this.completedBy,
    this.grade,
    this.feedback,
    this.status = AssignmentStatus.pending,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'studentId': studentId,
        'subject': subject,
        'title': title,
        if (description != null) 'description': description,
        'dueDate': dueDate.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (completedBy != null) 'completedBy': completedBy,
        if (grade != null) 'grade': grade,
        if (feedback != null) 'feedback': feedback,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        studentId: json['studentId'] as String,
        subject: json['subject'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        dueDate: DateTime.parse(json['dueDate'] as String),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        completedBy: json['completedBy'] as String?,
        grade: json['grade'] as double?,
        feedback: json['feedback'] as String?,
        status: AssignmentStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => AssignmentStatus.pending,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
      );
}

enum AssignmentStatus {
  pending,
  inProgress,
  completed,
  graded,
}

/// Lesson plan for homeschooling
class LessonPlan {
  final String id;
  final String hubId;
  final String subject;
  final String title;
  final String? description;
  final List<String> learningObjectives;
  final List<String> resources; // URLs or resource IDs
  final DateTime? scheduledDate;
  final int estimatedDurationMinutes;
  final LessonStatus status;
  final DateTime createdAt;
  final String createdBy;

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
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'subject': subject,
        'title': title,
        if (description != null) 'description': description,
        'learningObjectives': learningObjectives,
        'resources': resources,
        if (scheduledDate != null) 'scheduledDate': scheduledDate!.toIso8601String(),
        'estimatedDurationMinutes': estimatedDurationMinutes,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
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
        status: LessonStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => LessonStatus.planned,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String,
      );
}

enum LessonStatus {
  planned,
  inProgress,
  completed,
  cancelled,
}


