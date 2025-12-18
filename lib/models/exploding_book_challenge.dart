import 'package:cloud_firestore/cloud_firestore.dart';

/// Exploding Books challenge model
class ExplodingBookChallenge {
  final String id;
  final String bookId;
  final String userId;
  final String hubId;
  final DateTime targetCompletionDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? timeScore; // Calculated on completion (0-100)
  final int? memoryScore; // From quiz (0-100)
  final int? totalScore; // timeScore * memoryScore
  final String? quizId; // Reference to completed quiz
  final int? currentPage; // Current reading progress
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExplodingBookChallenge({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.hubId,
    required this.targetCompletionDate,
    this.startedAt,
    this.completedAt,
    this.timeScore,
    this.memoryScore,
    this.totalScore,
    this.quizId,
    this.currentPage,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => startedAt != null && completedAt == null;
  bool get isCompleted => completedAt != null;
  bool get isExpired => targetCompletionDate.isBefore(DateTime.now()) && !isCompleted;

  Duration? get timeRemaining {
    if (!isActive) return null;
    return targetCompletionDate.difference(DateTime.now());
  }

  double get progressPercentage {
    if (currentPage == null) return 0.0;
    // This would need book pageCount - will be calculated in service
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'userId': userId,
        'hubId': hubId,
        'targetCompletionDate': targetCompletionDate.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'timeScore': timeScore,
        'memoryScore': memoryScore,
        'totalScore': totalScore,
        'quizId': quizId,
        'currentPage': currentPage,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory ExplodingBookChallenge.fromJson(Map<String, dynamic> json) {
    DateTime targetCompletionDate;
    if (json['targetCompletionDate'] != null) {
      if (json['targetCompletionDate'] is Timestamp) {
        targetCompletionDate = (json['targetCompletionDate'] as Timestamp).toDate();
      } else if (json['targetCompletionDate'] is String) {
        targetCompletionDate = DateTime.parse(json['targetCompletionDate'] as String);
      } else {
        targetCompletionDate = DateTime.now();
      }
    } else {
      targetCompletionDate = DateTime.now();
    }

    DateTime createdAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        createdAt = (json['createdAt'] as Timestamp).toDate();
      } else if (json['createdAt'] is String) {
        createdAt = DateTime.parse(json['createdAt'] as String);
      } else {
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }

    DateTime? startedAt;
    if (json['startedAt'] != null) {
      if (json['startedAt'] is Timestamp) {
        startedAt = (json['startedAt'] as Timestamp).toDate();
      } else if (json['startedAt'] is String) {
        startedAt = DateTime.tryParse(json['startedAt'] as String);
      }
    }

    DateTime? completedAt;
    if (json['completedAt'] != null) {
      if (json['completedAt'] is Timestamp) {
        completedAt = (json['completedAt'] as Timestamp).toDate();
      } else if (json['completedAt'] is String) {
        completedAt = DateTime.tryParse(json['completedAt'] as String);
      }
    }

    DateTime? updatedAt;
    if (json['updatedAt'] != null) {
      if (json['updatedAt'] is Timestamp) {
        updatedAt = (json['updatedAt'] as Timestamp).toDate();
      } else if (json['updatedAt'] is String) {
        updatedAt = DateTime.tryParse(json['updatedAt'] as String);
      }
    }

    return ExplodingBookChallenge(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      userId: json['userId'] as String,
      hubId: json['hubId'] as String,
      targetCompletionDate: targetCompletionDate,
      startedAt: startedAt,
      completedAt: completedAt,
      timeScore: (json['timeScore'] as num?)?.toInt(),
      memoryScore: (json['memoryScore'] as num?)?.toInt(),
      totalScore: (json['totalScore'] as num?)?.toInt(),
      quizId: json['quizId'] as String?,
      currentPage: (json['currentPage'] as num?)?.toInt(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  ExplodingBookChallenge copyWith({
    String? id,
    String? bookId,
    String? userId,
    String? hubId,
    DateTime? targetCompletionDate,
    DateTime? startedAt,
    DateTime? completedAt,
    int? timeScore,
    int? memoryScore,
    int? totalScore,
    String? quizId,
    int? currentPage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ExplodingBookChallenge(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        userId: userId ?? this.userId,
        hubId: hubId ?? this.hubId,
        targetCompletionDate: targetCompletionDate ?? this.targetCompletionDate,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        timeScore: timeScore ?? this.timeScore,
        memoryScore: memoryScore ?? this.memoryScore,
        totalScore: totalScore ?? this.totalScore,
        quizId: quizId ?? this.quizId,
        currentPage: currentPage ?? this.currentPage,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}


