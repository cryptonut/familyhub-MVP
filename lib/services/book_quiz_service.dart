import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../models/book_quiz.dart';
import '../utils/firestore_path_utils.dart';
import 'book_quiz_generator_service.dart';
import 'book_service.dart';
import 'exploding_books_service.dart';

/// Service for managing book quizzes
class BookQuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BookService _bookService = BookService();
  final ExplodingBooksService _explodingBooksService = ExplodingBooksService();
  final BookQuizGeneratorService _quizGenerator = BookQuizGeneratorService();
  final _uuid = const Uuid();

  /// Generate a quiz for a book (10 questions)
  Future<BookQuiz> generateQuiz({
    required String hubId,
    required String bookId,
    required String challengeId,
  }) async {
    try {
      // Check if quiz already exists for this challenge
      final existingQuiz = await getQuizByChallenge(hubId, challengeId);
      if (existingQuiz != null) {
        return existingQuiz;
      }

      // Get book details for context
      final book = await _bookService.getHubBook(hubId, bookId);
      if (book == null) {
        throw Exception('Book not found');
      }

      // Generate questions using hybrid approach (AI + curated + community)
      final questions = await _quizGenerator.generateQuestions(
        bookId: bookId,
        bookTitle: book.title,
        bookDescription: book.description,
        authors: book.authors,
      );

      if (questions.length < 10) {
        Logger.warning(
          'Only generated ${questions.length} questions, expected 10',
          tag: 'BookQuizService',
        );
      }

      // Take first 10 questions
      final quizQuestions = questions.take(10).toList();

      // Get challenge to get userId
      final challenge = await _explodingBooksService.getChallenge(hubId, challengeId);
      if (challenge == null) {
        throw Exception('Challenge not found');
      }

      final quiz = BookQuiz(
        id: _uuid.v4(),
        bookId: bookId,
        challengeId: challengeId,
        userId: challenge.userId,
        questions: quizQuestions,
        createdAt: DateTime.now(),
      );

      // Save quiz (sanitize book ID)
      final sanitizedBookId = BookService.sanitizeBookId(bookId);
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .collection('quizzes')
          .doc(quiz.id)
          .set(quiz.toJson());

      return quiz;
    } catch (e, st) {
      Logger.error('Error generating quiz', error: e, stackTrace: st, tag: 'BookQuizService');
      rethrow;
    }
  }

  /// Submit quiz answers
  Future<BookQuiz> submitQuizAnswers({
    required String hubId,
    required String quizId,
    required Map<String, int> answers, // questionId -> selectedOptionIndex
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Find quiz (need to search through books)
      // This is inefficient - we should store quizId -> bookId mapping
      // For now, we'll require bookId to be passed or find via challenge
      throw UnimplementedError('submitQuizAnswers requires bookId - use submitQuizAnswersWithBookId');
    } catch (e, st) {
      Logger.error('Error submitting quiz answers', error: e, stackTrace: st, tag: 'BookQuizService');
      rethrow;
    }
  }

  /// Submit quiz answers (with bookId)
  Future<BookQuiz> submitQuizAnswersWithBookId({
    required String hubId,
    required String bookId,
    required String quizId,
    required Map<String, int> answers,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final sanitizedBookId = BookService.sanitizeBookId(bookId);
      final quizRef = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .collection('quizzes')
          .doc(quizId);

      final quizDoc = await quizRef.get();
      if (!quizDoc.exists) {
        throw Exception('Quiz not found');
      }

      final quiz = BookQuiz.fromJson({'id': quizId, ...quizDoc.data()!});

      if (quiz.isCompleted) {
        throw Exception('Quiz already completed');
      }

      // Calculate score
      final score = calculateMemoryScore(quiz, answers);

      // Update quiz
      await quizRef.update({
        'userAnswers': answers,
        'completedAt': DateTime.now().toIso8601String(),
        'score': score,
      });

      // Get updated quiz
      final updatedQuizDoc = await quizRef.get();
      final updatedQuiz = BookQuiz.fromJson({'id': quizId, ...updatedQuizDoc.data()!});

      // Update challenge scores
      final challenge = await _explodingBooksService.getChallenge(hubId, quiz.challengeId);
      if (challenge != null && challenge.startedAt != null) {
        final timeScore = calculateTimeScore(
          challenge.startedAt!,
          DateTime.now(),
          challenge.targetCompletionDate,
        );

        await _explodingBooksService.updateChallengeScores(
          hubId: hubId,
          challengeId: quiz.challengeId,
          timeScore: timeScore,
          memoryScore: score,
          quizId: quizId,
        );
      }

      return updatedQuiz;
    } catch (e, st) {
      Logger.error('Error submitting quiz answers', error: e, stackTrace: st, tag: 'BookQuizService');
      rethrow;
    }
  }

  /// Calculate memory score from quiz (0-100)
  int calculateMemoryScore(BookQuiz quiz, Map<String, int> answers) {
    if (quiz.questions.isEmpty) return 0;

    int correct = 0;
    for (final question in quiz.questions) {
      final userAnswer = answers[question.id];
      if (userAnswer == question.correctAnswerIndex) {
        correct++;
      }
    }

    // Score = (correct answers / total questions) * 100
    return ((correct / quiz.questions.length) * 100).round();
  }

  /// Calculate time score based on completion vs target (0-100)
  int calculateTimeScore(
    DateTime startedAt,
    DateTime completedAt,
    DateTime targetDate,
  ) {
    final totalTime = targetDate.difference(startedAt);
    final actualTime = completedAt.difference(startedAt);

    if (actualTime <= Duration.zero) {
      return 100; // Completed instantly (edge case)
    }

    if (actualTime <= totalTime) {
      // Completed on time or early - score based on how early
      // If completed exactly on time: 100
      // If completed early: bonus up to 110 (capped at 100)
      final timeRatio = actualTime.inSeconds / totalTime.inSeconds;
      final score = ((1 - timeRatio) * 50 + 50).round(); // 50-100 range
      return score.clamp(0, 100);
    } else {
      // Completed late - penalty
      final lateBy = actualTime - totalTime;
      final lateRatio = lateBy.inSeconds / totalTime.inSeconds;
      final penalty = (lateRatio * 50).round(); // Up to 50 point penalty
      final score = (100 - penalty).clamp(0, 100);
      return score;
    }
  }

  /// Get quiz by ID
  Future<BookQuiz?> getQuiz(String hubId, String bookId, String quizId) async {
    try {
      final sanitizedBookId = BookService.sanitizeBookId(bookId);
      final doc = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .collection('quizzes')
          .doc(quizId)
          .get();

      if (!doc.exists) return null;

      return BookQuiz.fromJson({'id': quizId, ...doc.data()!});
    } catch (e, st) {
      Logger.error('Error getting quiz', error: e, stackTrace: st, tag: 'BookQuizService');
      return null;
    }
  }

  /// Get quiz by challenge ID
  Future<BookQuiz?> getQuizByChallenge(String hubId, String challengeId) async {
    try {
      // Find quiz for this challenge
      // This requires a collection group query or storing challengeId -> bookId mapping
      // For now, we'll search through all books (inefficient but works)
      final booksSnapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .get();

      for (final bookDoc in booksSnapshot.docs) {
        final quizzesSnapshot = await _firestore
            .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
            .doc(bookDoc.id)
            .collection('quizzes')
            .where('challengeId', isEqualTo: challengeId)
            .limit(1)
            .get();

        if (quizzesSnapshot.docs.isNotEmpty) {
          final quizDoc = quizzesSnapshot.docs.first;
          return BookQuiz.fromJson({'id': quizDoc.id, ...quizDoc.data()});
        }
      }

      return null;
    } on Exception catch (e, st) {
      Logger.error('Error getting quiz by challenge', error: e, stackTrace: st, tag: 'BookQuizService');
      return null;
    }
  }

  /// Get all quizzes for a user and book
  Future<List<BookQuiz>> getUserQuizzes(String hubId, String bookId, String userId) async {
    try {
      final sanitizedBookId = BookService.sanitizeBookId(bookId);
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .collection('quizzes')
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs
          .map((doc) => BookQuiz.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } on Exception catch (e, st) {
      Logger.error('Error getting user quizzes', error: e, stackTrace: st, tag: 'BookQuizService');
      return [];
    }
  }
}

