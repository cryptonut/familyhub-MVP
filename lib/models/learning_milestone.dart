/// Learning milestone/achievement for students
class LearningMilestone {
  final String id;
  final String hubId;
  final String studentId;
  final String title;
  final String? description;
  final MilestoneType type;
  final String? subject; // Subject this milestone relates to (null = general)
  final DateTime achievedAt;
  final String? iconName; // Icon identifier for display

  LearningMilestone({
    required this.id,
    required this.hubId,
    required this.studentId,
    required this.title,
    this.description,
    required this.type,
    this.subject,
    required this.achievedAt,
    this.iconName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'studentId': studentId,
        'title': title,
        'description': description,
        'type': type.name,
        'subject': subject,
        'achievedAt': achievedAt.toIso8601String(),
        'iconName': iconName,
      };

  factory LearningMilestone.fromJson(Map<String, dynamic> json) =>
      LearningMilestone(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        studentId: json['studentId'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        type: MilestoneType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => MilestoneType.achievement,
        ),
        subject: json['subject'] as String?,
        achievedAt: DateTime.parse(json['achievedAt'] as String),
        iconName: json['iconName'] as String?,
      );
}

enum MilestoneType {
  achievement, // General achievement
  streak, // Daily lesson streak
  mastery, // Subject mastery
  completion, // Assignment/lesson completion milestone
  improvement, // Significant improvement
}

extension MilestoneTypeExtension on MilestoneType {
  String get displayName {
    switch (this) {
      case MilestoneType.achievement:
        return 'Achievement';
      case MilestoneType.streak:
        return 'Streak';
      case MilestoneType.mastery:
        return 'Mastery';
      case MilestoneType.completion:
        return 'Completion';
      case MilestoneType.improvement:
        return 'Improvement';
    }
  }
}

