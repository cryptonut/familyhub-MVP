import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../models/book_rating.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'exploding_books_service.dart';
import 'book_quiz_service.dart';
import 'book_service.dart';

/// Service for managing book ratings and comments
class BookRatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final _uuid = const Uuid();

  /// Check if user can rate a book (has read it or completed quiz)
  Future<bool> canUserRateBook(String hubId, String bookId, String userId) async {
    try {
      // Check if user has completed a challenge for this book
      final explodingBooksService = ExplodingBooksService();
      final challenges = await explodingBooksService.getUserChallenges(hubId, userId, activeOnly: false);
      final hasCompletedChallenge = challenges.any((c) => 
        c.bookId == bookId && c.isCompleted
      );

      if (hasCompletedChallenge) {
        return true;
      }

      // Check if user has completed a quiz for this book
      final bookQuizService = BookQuizService();
      final quizzes = await bookQuizService.getUserQuizzes(hubId, bookId, userId);
      final hasCompletedQuiz = quizzes.any((q) => q.isCompleted);

      return hasCompletedQuiz;
    } catch (e) {
      Logger.warning('Error checking if user can rate book', error: e, tag: 'BookRatingService');
      return false;
    }
  }

  /// Rate a book with optional comment
  Future<BookRating> rateBook(
    String hubId,
    String bookId,
    int rating, {
    String? comment,
    bool isAnonymous = false,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Validate that user has read the book or completed quiz
      final canRate = await canUserRateBook(hubId, bookId, userId);
      if (!canRate) {
        throw Exception('You must read the book or complete the quiz before rating');
      }

      // Validate rating (1-5)
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      // Get user name if not anonymous
      String? userName;
      if (!isAnonymous) {
        final userModel = await _authService.getCurrentUserModel();
        userName = userModel?.displayName;
      }

      // Check if user already rated this book
      final existingRating = await getUserRating(hubId, bookId, userId);
      
      final ratingId = existingRating?.id ?? _uuid.v4();
      final now = DateTime.now();

      final bookRating = BookRating(
        id: ratingId,
        bookId: bookId,
        userId: userId,
        userName: userName,
        rating: rating,
        comment: comment,
        isAnonymous: isAnonymous,
        createdAt: existingRating?.createdAt ?? now,
        updatedAt: now,
      );

      // Save rating (sanitize book ID for Firestore)
      final sanitizedBookId = BookService.sanitizeBookId(bookId);
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .collection('ratings')
          .doc(ratingId)
          .set(bookRating.toJson());

      // Update book's average rating
      await _updateBookRating(hubId, bookId);

      return bookRating;
    } catch (e, st) {
      Logger.error('Error rating book', error: e, stackTrace: st, tag: 'BookRatingService');
      rethrow;
    }
  }

  /// Get all ratings for a book
  Future<List<BookRating>> getBookRatings(String hubId, String bookId) async {
    try {
      final sanitizedBookId = BookService.sanitizeBookId(bookId);
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .collection('ratings')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BookRating.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } on Exception catch (e, st) {
      Logger.error('Error getting book ratings', error: e, stackTrace: st, tag: 'BookRatingService');
      return [];
    }
  }

  /// Get user's rating for a book
  Future<BookRating?> getUserRating(String hubId, String bookId, String userId) async {
    try {
      final sanitizedBookId = BookService.sanitizeBookId(bookId);
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .collection('ratings')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return BookRating.fromJson({'id': doc.id, ...doc.data()});
    } on Exception catch (e, st) {
      Logger.error('Error getting user rating', error: e, stackTrace: st, tag: 'BookRatingService');
      return null;
    }
  }

  /// Get all ratings by a user
  Future<List<BookRating>> getUserRatings(String hubId, String userId) async {
    try {
      // Note: This requires a collection group query or iterating through all books
      // For now, we'll use a collection group query
      final snapshot = await _firestore
          .collectionGroup('ratings')
          .where('userId', isEqualTo: userId)
          .get();

      // Filter to only ratings in this hub's books
      final hubPath = FirestorePathUtils.getHubSubcollectionPath(hubId, 'books');
      return snapshot.docs
          .where((doc) => doc.reference.path.contains(hubPath))
          .map((doc) => BookRating.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } on Exception catch (e, st) {
      Logger.error('Error getting user ratings', error: e, stackTrace: st, tag: 'BookRatingService');
      return [];
    }
  }

  /// Update a rating
  Future<void> updateRating(
    String hubId,
    String ratingId,
    int rating, {
    String? comment,
    bool? isAnonymous,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Validate rating (1-5)
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      // Find the rating document (we need bookId)
      // This is a limitation - we'd need to store bookId in the rating path or query
      // For now, we'll require bookId to be passed or find it via collection group query
      // Let's use a simpler approach: update by bookId and userId
      throw UnimplementedError('updateRating requires bookId - use rateBook to update');
    } catch (e, st) {
      Logger.error('Error updating rating', error: e, stackTrace: st, tag: 'BookRatingService');
      rethrow;
    }
  }

  /// Delete a rating
  Future<void> deleteRating(String hubId, String bookId, String ratingId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify user owns this rating (sanitize book ID)
      final sanitizedBookId = BookService.sanitizeBookId(bookId);
      final rating = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .collection('ratings')
          .doc(ratingId)
          .get();

      if (!rating.exists) {
        throw Exception('Rating not found');
      }

      final ratingData = rating.data()!;
      if (ratingData['userId'] != userId) {
        throw Exception('Not authorized to delete this rating');
      }

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .collection('ratings')
          .doc(ratingId)
          .delete();

      // Update book's average rating
      await _updateBookRating(hubId, bookId);
    } catch (e, st) {
      Logger.error('Error deleting rating', error: e, stackTrace: st, tag: 'BookRatingService');
      rethrow;
    }
  }

  /// Update book's average rating and rating count
  Future<void> _updateBookRating(String hubId, String bookId) async {
    try {
      final ratings = await getBookRatings(hubId, bookId);
      
      if (ratings.isEmpty) {
        // Remove rating fields if no ratings (sanitize book ID)
        final sanitizedBookId = BookService.sanitizeBookId(bookId);
        await _firestore
            .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
            .doc(sanitizedBookId)
            .update({
          'averageRating': null,
          'ratingCount': 0,
        });
        return;
      }

      final totalRating = ratings.fold<int>(0, (total, r) => total + r.rating);
      final averageRating = totalRating / ratings.length;
      final ratingCount = ratings.length;

      final sanitizedBookId = BookService.sanitizeBookId(bookId);
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .update({
        'averageRating': averageRating,
        'ratingCount': ratingCount,
      });
    } on Exception catch (e, st) {
      Logger.error('Error updating book rating', error: e, stackTrace: st, tag: 'BookRatingService');
    }
  }
}

