/// Progress report for a student
class ProgressReport {
  final String id;
  final String hubId;
  final String studentId;
  final String reportPeriod; // e.g., "Q1 2025", "Semester 1", "Week 1-4"
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, SubjectProgress> subjectProgress; // subject -> progress
  final double overallAverage;
  final List<String> strengths;
  final List<String> areasForImprovement;
  final String? notes;
  final DateTime createdAt;
  final String createdBy;

  ProgressReport({
    required this.id,
    required this.hubId,
    required this.studentId,
    required this.reportPeriod,
    required this.startDate,
    required this.endDate,
    this.subjectProgress = const {},
    required this.overallAverage,
    this.strengths = const [],
    this.areasForImprovement = const [],
    this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'studentId': studentId,
        'reportPeriod': reportPeriod,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'subjectProgress': subjectProgress.map(
          (k, v) => MapEntry(k, v.toJson()),
        ),
        'overallAverage': overallAverage,
        'strengths': strengths,
        'areasForImprovement': areasForImprovement,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };

  factory ProgressReport.fromJson(Map<String, dynamic> json) {
    final subjectProgressData = json['subjectProgress'] as Map<String, dynamic>? ?? {};
    final subjectProgress = subjectProgressData.map(
      (k, v) => MapEntry(
        k,
        SubjectProgress.fromJson(v as Map<String, dynamic>),
      ),
    );

    return ProgressReport(
      id: json['id'] as String,
      hubId: json['hubId'] as String,
      studentId: json['studentId'] as String,
      reportPeriod: json['reportPeriod'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      subjectProgress: subjectProgress,
      overallAverage: (json['overallAverage'] as num).toDouble(),
      strengths: List<String>.from(json['strengths'] as List? ?? []),
      areasForImprovement:
          List<String>.from(json['areasForImprovement'] as List? ?? []),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String,
    );
  }
}

/// Progress for a specific subject
class SubjectProgress {
  final String subject;
  final double averageGrade;
  final int assignmentsCompleted;
  final int assignmentsTotal;
  final int lessonsCompleted;
  final List<String> milestonesAchieved;

  SubjectProgress({
    required this.subject,
    required this.averageGrade,
    required this.assignmentsCompleted,
    required this.assignmentsTotal,
    required this.lessonsCompleted,
    this.milestonesAchieved = const [],
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'averageGrade': averageGrade,
        'assignmentsCompleted': assignmentsCompleted,
        'assignmentsTotal': assignmentsTotal,
        'lessonsCompleted': lessonsCompleted,
        'milestonesAchieved': milestonesAchieved,
      };

  factory SubjectProgress.fromJson(Map<String, dynamic> json) =>
      SubjectProgress(
        subject: json['subject'] as String,
        averageGrade: (json['averageGrade'] as num).toDouble(),
        assignmentsCompleted: (json['assignmentsCompleted'] as num).toInt(),
        assignmentsTotal: (json['assignmentsTotal'] as num).toInt(),
        lessonsCompleted: (json['lessonsCompleted'] as num).toInt(),
        milestonesAchieved:
            List<String>.from(json['milestonesAchieved'] as List? ?? []),
      );
}

