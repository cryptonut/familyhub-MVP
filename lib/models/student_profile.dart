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
        // Don't include 'id' - it's the document ID
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


