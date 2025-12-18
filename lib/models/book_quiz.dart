import 'package:cloud_firestore/cloud_firestore.dart';

/// Book quiz model with questions
class BookQuiz {
  final String id;
  final String bookId;
  final String challengeId;
  final String userId; // User who owns the challenge
  final List<QuizQuestion> questions; // 10 questions
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, int>? userAnswers; // questionId -> selectedOptionIndex
  final int? score; // Calculated score (0-100)

  BookQuiz({
    required this.id,
    required this.bookId,
    required this.challengeId,
    required this.userId,
    required this.questions,
    required this.createdAt,
    this.completedAt,
    this.userAnswers,
    this.score,
  });

  bool get isCompleted => completedAt != null && userAnswers != null;
  int get correctAnswers {
    if (userAnswers == null) return 0;
    int correct = 0;
    for (final question in questions) {
      final userAnswer = userAnswers![question.id];
      if (userAnswer == question.correctAnswerIndex) {
        correct++;
      }
    }
    return correct;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'challengeId': challengeId,
        'userId': userId,
        'questions': questions.map((q) => q.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'userAnswers': userAnswers,
        'score': score,
      };

  factory BookQuiz.fromJson(Map<String, dynamic> json) {
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

    DateTime? completedAt;
    if (json['completedAt'] != null) {
      if (json['completedAt'] is Timestamp) {
        completedAt = (json['completedAt'] as Timestamp).toDate();
      } else if (json['completedAt'] is String) {
        completedAt = DateTime.tryParse(json['completedAt'] as String);
      }
    }

    final questionsList = json['questions'] as List? ?? [];
    final questions = questionsList
        .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList();

    Map<String, int>? userAnswers;
    if (json['userAnswers'] != null) {
      final answersMap = json['userAnswers'] as Map;
      userAnswers = answersMap.map((key, value) =>
          MapEntry(key.toString(), (value as num).toInt()));
    }

    return BookQuiz(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      challengeId: json['challengeId'] as String,
      userId: json['userId'] as String? ?? '',
      questions: questions,
      createdAt: createdAt,
      completedAt: completedAt,
      userAnswers: userAnswers,
      score: (json['score'] as num?)?.toInt(),
    );
  }

  BookQuiz copyWith({
    String? id,
    String? bookId,
    String? challengeId,
    String? userId,
    List<QuizQuestion>? questions,
    DateTime? createdAt,
    DateTime? completedAt,
    Map<String, int>? userAnswers,
    int? score,
  }) =>
      BookQuiz(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        challengeId: challengeId ?? this.challengeId,
        userId: userId ?? this.userId,
        questions: questions ?? this.questions,
        createdAt: createdAt ?? this.createdAt,
        completedAt: completedAt ?? this.completedAt,
        userAnswers: userAnswers ?? this.userAnswers,
        score: score ?? this.score,
      );
}

/// Individual quiz question
class QuizQuestion {
  final String id;
  final String question;
  final List<String> options; // 4 options
  final int correctAnswerIndex; // 0-3
  final String? explanation;

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'options': options,
        'correctAnswerIndex': correctAnswerIndex,
        'explanation': explanation,
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswerIndex: (json['correctAnswerIndex'] as num).toInt(),
      explanation: json['explanation'] as String?,
    );
  }

  QuizQuestion copyWith({
    String? id,
    String? question,
    List<String>? options,
    int? correctAnswerIndex,
    String? explanation,
  }) =>
      QuizQuestion(
        id: id ?? this.id,
        question: question ?? this.question,
        options: options ?? this.options,
        correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
        explanation: explanation ?? this.explanation,
      );
}

