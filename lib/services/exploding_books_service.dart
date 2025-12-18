import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../models/exploding_book_challenge.dart';
import '../utils/firestore_path_utils.dart';

/// Service for managing Exploding Books challenges
class ExplodingBooksService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  /// Create a new Exploding Books challenge
  Future<ExplodingBookChallenge> createChallenge({
    required String hubId,
    required String bookId,
    required DateTime targetCompletionDate,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if user already has an active challenge for this book
      final existingChallenge = await getActiveChallenge(hubId, bookId, userId);
      if (existingChallenge != null) {
        throw Exception('You already have an active challenge for this book');
      }

      final challenge = ExplodingBookChallenge(
        id: _uuid.v4(),
        bookId: bookId,
        userId: userId,
        hubId: hubId,
        targetCompletionDate: targetCompletionDate,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'exploding_books'))
          .doc(challenge.id)
          .set(challenge.toJson());

      return challenge;
    } catch (e, st) {
      Logger.error('Error creating challenge', error: e, stackTrace: st, tag: 'ExplodingBooksService');
      rethrow;
    }
  }

  /// Start reading (begin countdown)
  Future<void> startReading(String hubId, String challengeId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final challengeRef = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'exploding_books'))
          .doc(challengeId);

      final challengeDoc = await challengeRef.get();
      if (!challengeDoc.exists) {
        throw Exception('Challenge not found');
      }

      final challengeData = challengeDoc.data()!;
      if (challengeData['userId'] != userId) {
        throw Exception('Not authorized to start this challenge');
      }

      if (challengeData['startedAt'] != null) {
        throw Exception('Challenge already started');
      }

      await challengeRef.update({
        'startedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      Logger.error('Error starting reading', error: e, stackTrace: st, tag: 'ExplodingBooksService');
      rethrow;
    }
  }

  /// Get active challenge for a book and user
  Future<ExplodingBookChallenge?> getActiveChallenge(
    String hubId,
    String bookId,
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'exploding_books'))
          .where('bookId', isEqualTo: bookId)
          .where('userId', isEqualTo: userId)
          .where('completedAt', isNull: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      return ExplodingBookChallenge.fromJson({'id': doc.id, ...doc.data()});
    } catch (e, st) {
      Logger.error('Error getting active challenge', error: e, stackTrace: st, tag: 'ExplodingBooksService');
      return null;
    }
  }

  /// Get challenge by ID
  Future<ExplodingBookChallenge?> getChallenge(String hubId, String challengeId) async {
    try {
      final doc = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'exploding_books'))
          .doc(challengeId)
          .get();

      if (!doc.exists) return null;

      return ExplodingBookChallenge.fromJson({'id': doc.id, ...doc.data()!});
    } catch (e, st) {
      Logger.error('Error getting challenge', error: e, stackTrace: st, tag: 'ExplodingBooksService');
      return null;
    }
  }

  /// Update reading progress
  Future<void> updateReadingProgress(
    String hubId,
    String challengeId, {
    int? currentPage,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final challengeRef = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'exploding_books'))
          .doc(challengeId);

      final challengeDoc = await challengeRef.get();
      if (!challengeDoc.exists) {
        throw Exception('Challenge not found');
      }

      final challengeData = challengeDoc.data()!;
      if (challengeData['userId'] != userId) {
        throw Exception('Not authorized to update this challenge');
      }

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (currentPage != null) {
        updates['currentPage'] = currentPage;
      }

      await challengeRef.update(updates);
    } catch (e, st) {
      Logger.error('Error updating reading progress', error: e, stackTrace: st, tag: 'ExplodingBooksService');
      rethrow;
    }
  }

  /// Complete challenge (triggers quiz)
  Future<void> completeChallenge(String hubId, String challengeId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final challengeRef = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'exploding_books'))
          .doc(challengeId);

      final challengeDoc = await challengeRef.get();
      if (!challengeDoc.exists) {
        throw Exception('Challenge not found');
      }

      final challengeData = challengeDoc.data()!;
      if (challengeData['userId'] != userId) {
        throw Exception('Not authorized to complete this challenge');
      }

      if (challengeData['completedAt'] != null) {
        throw Exception('Challenge already completed');
      }

      await challengeRef.update({
        'completedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      Logger.error('Error completing challenge', error: e, stackTrace: st, tag: 'ExplodingBooksService');
      rethrow;
    }
  }

  /// Get all challenges for a user
  Future<List<ExplodingBookChallenge>> getUserChallenges(
    String hubId,
    String userId, {
    bool? activeOnly,
  }) async {
    try {
      var query = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'exploding_books'))
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      if (activeOnly ?? false) {
        query = query.where('completedAt', isNull: true);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => ExplodingBookChallenge.fromJson({'id': doc.id, ...doc.data()}))
          .toList();
    } on Exception catch (e, st) {
      Logger.error('Error getting user challenges', error: e, stackTrace: st, tag: 'ExplodingBooksService');
      return [];
    }
  }

  /// Update challenge scores after quiz completion
  Future<void> updateChallengeScores({
    required String hubId,
    required String challengeId,
    required int timeScore,
    required int memoryScore,
    required String quizId,
  }) async {
    try {
      final totalScore = timeScore * memoryScore;

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'exploding_books'))
          .doc(challengeId)
          .update({
        'timeScore': timeScore,
        'memoryScore': memoryScore,
        'totalScore': totalScore,
        'quizId': quizId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      Logger.error('Error updating challenge scores', error: e, stackTrace: st, tag: 'ExplodingBooksService');
      rethrow;
    }
  }
}


