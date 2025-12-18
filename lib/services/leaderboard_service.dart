import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/services/logger_service.dart';
import '../models/exploding_book_challenge.dart';
import '../models/leaderboard_entry.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'exploding_books_service.dart';

/// Service for managing Exploding Books leaderboards
class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  /// Get family leaderboard
  Future<List<LeaderboardEntry>> getFamilyLeaderboard(String familyId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('leaderboards')
          .doc('exploding_books')
          .collection('entries')
          .orderBy('totalScore', descending: true)
          .limit(limit)
          .get();

      final entries = <LeaderboardEntry>[];
      int rank = 1;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        entries.add(LeaderboardEntry.fromJson({
          ...data,
          'scope': LeaderboardScope.family.name,
          'rank': rank++,
        },),);
      }

      return entries;
    } on Exception catch (e, st) {
      Logger.error('Error getting family leaderboard', error: e, stackTrace: st, tag: 'LeaderboardService');
      return [];
    }
  }

  /// Get hub leaderboard
  Future<List<LeaderboardEntry>> getHubLeaderboard(String hubId, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'leaderboards'))
          .doc('exploding_books')
          .collection('entries')
          .orderBy('totalScore', descending: true)
          .limit(limit)
          .get();

      final entries = <LeaderboardEntry>[];
      int rank = 1;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        entries.add(LeaderboardEntry.fromJson({
          ...data,
          'scope': LeaderboardScope.hub.name,
          'rank': rank++,
        },),);
      }

      return entries;
    } on Exception catch (e, st) {
      Logger.error('Error getting hub leaderboard', error: e, stackTrace: st, tag: 'LeaderboardService');
      return [];
    }
  }

  /// Get global leaderboard
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({int limit = 100}) async {
    try {
      final snapshot = await _firestore
          .collection('global')
          .doc('leaderboards')
          .collection('exploding_books')
          .orderBy('totalScore', descending: true)
          .limit(limit)
          .get();

      final entries = <LeaderboardEntry>[];
      int rank = 1;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        entries.add(LeaderboardEntry.fromJson({
          ...data,
          'scope': LeaderboardScope.global.name,
          'rank': rank++,
        },),);
      }

      return entries;
    } on Exception catch (e, st) {
      Logger.error('Error getting global leaderboard', error: e, stackTrace: st, tag: 'LeaderboardService');
      return [];
    }
  }

  /// Update leaderboard entry for a user
  /// This should be called after a challenge is completed
  Future<void> updateLeaderboard({
    required int totalScore,
    required LeaderboardScope scope,
    required String userId,
    required String userName,
    String? familyId,
    String? hubId,
    String? userPhotoUrl,
  }) async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return;

      // Get user's existing challenges to calculate stats
      final challenges = await _getUserChallenges(userId, hubId: hubId);
      final booksCompleted = challenges.where((c) => c.isCompleted).length;
      final averageScore = booksCompleted > 0
          ? (challenges.where((c) => c.isCompleted).fold<int>(0, (total, c) => total + (c.totalScore ?? 0)) / booksCompleted).toDouble()
          : 0.0;

      final entry = LeaderboardEntry(
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        totalScore: totalScore,
        booksCompleted: booksCompleted,
        averageScore: averageScore,
        scope: scope,
        rank: 0, // Will be calculated when fetching
      );

      // Update based on scope
      switch (scope) {
        case LeaderboardScope.family:
          if (familyId != null) {
            await _updateFamilyLeaderboard(familyId, entry);
          }
          break;
        case LeaderboardScope.hub:
          if (hubId != null) {
            await _updateHubLeaderboard(hubId, entry);
          }
          break;
        case LeaderboardScope.global:
          await _updateGlobalLeaderboard(entry);
          break;
      }
    } on Exception catch (e, st) {
      Logger.error('Error updating leaderboard', error: e, stackTrace: st, tag: 'LeaderboardService');
    }
  }

  /// Update family leaderboard
  Future<void> _updateFamilyLeaderboard(String familyId, LeaderboardEntry entry) async {
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('leaderboards')
        .doc('exploding_books')
        .collection('entries')
        .doc(entry.userId)
        .set(entry.toJson(), SetOptions(merge: true));
  }

  /// Update hub leaderboard
  Future<void> _updateHubLeaderboard(String hubId, LeaderboardEntry entry) async {
    await _firestore
        .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'leaderboards'))
        .doc('exploding_books')
        .collection('entries')
        .doc(entry.userId)
        .set(entry.toJson(), SetOptions(merge: true));
  }

  /// Update global leaderboard
  Future<void> _updateGlobalLeaderboard(LeaderboardEntry entry) async {
    await _firestore
        .collection('global')
        .doc('leaderboards')
        .collection('exploding_books')
        .doc(entry.userId)
        .set(entry.toJson(), SetOptions(merge: true));
  }

  /// Get user's challenges (helper method)
  Future<List<ExplodingBookChallenge>> _getUserChallenges(String userId, {String? hubId}) async {
    if (hubId == null) return [];
    try {
      final explodingBooksService = ExplodingBooksService();
      return await explodingBooksService.getUserChallenges(hubId, userId);
    } catch (e) {
      Logger.warning('Error getting user challenges for leaderboard', error: e, tag: 'LeaderboardService');
      return [];
    }
  }

  /// Get user's rank in a leaderboard
  Future<int?> getUserRank({
    required String userId,
    required LeaderboardScope scope,
    String? familyId,
    String? hubId,
  }) async {
    try {
      List<LeaderboardEntry> entries;
      switch (scope) {
        case LeaderboardScope.family:
          if (familyId == null) return null;
          entries = await getFamilyLeaderboard(familyId);
          break;
        case LeaderboardScope.hub:
          if (hubId == null) return null;
          entries = await getHubLeaderboard(hubId);
          break;
        case LeaderboardScope.global:
          entries = await getGlobalLeaderboard();
          break;
      }

      final userEntry = entries.firstWhere(
        (e) => e.userId == userId,
        orElse: () => LeaderboardEntry(
          userId: userId,
          userName: '',
          totalScore: 0,
          booksCompleted: 0,
          averageScore: 0.0,
          scope: scope,
          rank: entries.length + 1,
        ),
      );

      return userEntry.rank;
    } on Exception catch (e, st) {
      Logger.error('Error getting user rank', error: e, stackTrace: st, tag: 'LeaderboardService');
      return null;
    }
  }
}

