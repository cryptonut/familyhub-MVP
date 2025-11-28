import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../models/game_stats.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Service for managing family games and leaderboards
class GamesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  /// Get game stats for a user
  Future<GameStats?> getUserStats(String userId) async {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel?.familyId == null) return null;

    try {
      final doc = await _firestore
          .collection('families')
          .doc(userModel!.familyId)
          .collection('game_stats')
          .doc(userId)
          .get();

      if (!doc.exists) {
        // Create default stats
        final stats = GameStats(
          userId: userId,
          familyId: userModel.familyId!,
        );
        await updateStats(stats);
        return stats;
      }

      return GameStats.fromJson({
        'userId': userId,
        'familyId': userModel.familyId!,
        ...doc.data()!,
      });
    } catch (e) {
      Logger.error('Error getting user stats', error: e, tag: 'GamesService');
      return null;
    }
  }

  /// Update game stats
  Future<void> updateStats(GameStats stats) async {
    try {
      final data = stats.toJson();
      data.remove('userId');
      data.remove('familyId');
      data['lastUpdated'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('families')
          .doc(stats.familyId)
          .collection('game_stats')
          .doc(stats.userId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      Logger.error('Error updating game stats', error: e, tag: 'GamesService');
      rethrow;
    }
  }

  /// Record a game win
  Future<void> recordWin(String gameType) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('User not authenticated', code: 'not-authenticated');

    final userModel = await _authService.getCurrentUserModel();
    if (userModel?.familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final stats = await getUserStats(user.uid) ?? GameStats(
      userId: user.uid,
      familyId: userModel!.familyId!,
    );

    final now = DateTime.now();
    final lastPlayed = stats.lastPlayed;
    
    // Calculate streak
    int newStreak = stats.streakDays;
    if (lastPlayed != null) {
      final daysSinceLastPlay = now.difference(lastPlayed).inDays;
      if (daysSinceLastPlay == 1) {
        newStreak = stats.streakDays + 1;
      } else if (daysSinceLastPlay > 1) {
        newStreak = 1; // Reset streak
      }
      // If same day, don't increment streak
    } else {
      newStreak = 1; // First play
    }

    final updatedStats = stats.copyWith(
      winsChess: gameType == 'chess' ? stats.winsChess + 1 : stats.winsChess,
      winsScramble: gameType == 'scramble' ? stats.winsScramble + 1 : stats.winsScramble,
      winsBingo: gameType == 'bingo' ? stats.winsBingo + 1 : stats.winsBingo,
      streakDays: newStreak,
      lastPlayed: now,
    );

    await updateStats(updatedStats);
  }

  /// Get leaderboard for family
  Future<List<GameStats>> getLeaderboard() async {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel?.familyId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('families')
          .doc(userModel!.familyId)
          .collection('game_stats')
          .orderBy('winsChess', descending: true)
          .orderBy('winsScramble', descending: true)
          .orderBy('winsBingo', descending: true)
          .get();

      final stats = snapshot.docs
          .map((doc) => GameStats.fromJson({
                'userId': doc.id,
                'familyId': userModel.familyId!,
                ...doc.data(),
              }))
          .toList();

      // Sort by total wins, then by streak
      stats.sort((a, b) {
        final totalWinsCompare = b.totalWins.compareTo(a.totalWins);
        if (totalWinsCompare != 0) return totalWinsCompare;
        return b.streakDays.compareTo(a.streakDays);
      });

      return stats;
    } catch (e) {
      Logger.error('Error getting leaderboard', error: e, tag: 'GamesService');
      return [];
    }
  }

  /// Get leaderboard stream for real-time updates
  Stream<List<GameStats>> getLeaderboardStream() async* {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel?.familyId == null) {
      yield [];
      return;
    }

    try {
      await for (final snapshot in _firestore
          .collection('families')
          .doc(userModel!.familyId)
          .collection('game_stats')
          .snapshots()) {
        final stats = snapshot.docs
            .map((doc) => GameStats.fromJson({
                  'userId': doc.id,
                  'familyId': userModel.familyId!,
                  ...doc.data(),
                }))
            .toList();

        // Sort by total wins, then by streak
        stats.sort((a, b) {
          final totalWinsCompare = b.totalWins.compareTo(a.totalWins);
          if (totalWinsCompare != 0) return totalWinsCompare;
          return b.streakDays.compareTo(a.streakDays);
        });

        yield stats;
      }
    } catch (e) {
      Logger.error('Error in leaderboard stream', error: e, tag: 'GamesService');
      yield [];
    }
  }
}

