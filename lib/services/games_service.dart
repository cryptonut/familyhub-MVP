import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/errors/app_exceptions.dart';
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
      // Keep userId in data for Firestore rules validation
      // familyId is not needed in the document data (it's in the path)
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
  /// Can be sorted by different game types
  Future<List<GameStats>> getLeaderboard({String? gameType}) async {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel?.familyId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('families')
          .doc(userModel!.familyId)
          .collection('game_stats')
          .get();

      final stats = snapshot.docs
          .map((doc) => GameStats.fromJson({
                'userId': doc.id,
                'familyId': userModel.familyId!,
                ...doc.data(),
              }))
          .toList();

      // Sort based on game type
      if (gameType == 'tetris') {
        stats.sort((a, b) => b.tetrisHighScore.compareTo(a.tetrisHighScore));
      } else if (gameType == '2048') {
        stats.sort((a, b) => b.puzzle2048HighScore.compareTo(a.puzzle2048HighScore));
      } else if (gameType == 'slide') {
        // For slide puzzle, lower time is better
        stats.sort((a, b) {
          if (a.slidePuzzleBestTime == 0) return 1;
          if (b.slidePuzzleBestTime == 0) return -1;
          return a.slidePuzzleBestTime.compareTo(b.slidePuzzleBestTime);
        });
      } else {
        // Default: sort by total wins, then by streak, then by Tetris score
        stats.sort((a, b) {
          final totalWinsCompare = b.totalWins.compareTo(a.totalWins);
          if (totalWinsCompare != 0) return totalWinsCompare;
          final streakCompare = b.streakDays.compareTo(a.streakDays);
          if (streakCompare != 0) return streakCompare;
          return b.tetrisHighScore.compareTo(a.tetrisHighScore);
        });
      }

      return stats;
    } catch (e) {
      Logger.error('Error getting leaderboard', error: e, tag: 'GamesService');
      return [];
    }
  }

  /// Get leaderboard stream for real-time updates
  Stream<List<GameStats>> getLeaderboardStream({String? gameType}) async* {
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

        // Sort based on game type (same logic as getLeaderboard)
        if (gameType == 'tetris') {
          stats.sort((a, b) => b.tetrisHighScore.compareTo(a.tetrisHighScore));
        } else if (gameType == '2048') {
          stats.sort((a, b) => b.puzzle2048HighScore.compareTo(a.puzzle2048HighScore));
        } else if (gameType == 'slide') {
          stats.sort((a, b) {
            if (a.slidePuzzleBestTime == 0) return 1;
            if (b.slidePuzzleBestTime == 0) return -1;
            return a.slidePuzzleBestTime.compareTo(b.slidePuzzleBestTime);
          });
        } else {
          // Default: sort by total wins, then by streak, then by Tetris score
          stats.sort((a, b) {
            final totalWinsCompare = b.totalWins.compareTo(a.totalWins);
            if (totalWinsCompare != 0) return totalWinsCompare;
            final streakCompare = b.streakDays.compareTo(a.streakDays);
            if (streakCompare != 0) return streakCompare;
            return b.tetrisHighScore.compareTo(a.tetrisHighScore);
          });
        }

        yield stats;
      }
    } catch (e) {
      Logger.error('Error in leaderboard stream', error: e, tag: 'GamesService');
      yield [];
    }
  }

  /// Update Tetris high score
  /// This method is non-blocking and won't throw errors to prevent disrupting gameplay
  Future<void> updateTetrisHighScore(String userId, String familyId, int score, int lines) async {
    try {
      // Check if user is authenticated before making Firestore calls
      if (_auth.currentUser == null) {
        Logger.warning('Cannot update Tetris score: user not authenticated', tag: 'GamesService');
        return;
      }

      final currentStats = await getUserStats(userId) ?? GameStats(userId: userId, familyId: familyId);
      if (score > currentStats.tetrisHighScore) {
        final updatedStats = currentStats.copyWith(
          tetrisHighScore: score,
          lastPlayed: DateTime.now(),
          lastUpdated: DateTime.now(),
        );
        await updateStats(updatedStats);
        Logger.info('Updated Tetris high score for $userId: $score', tag: 'GamesService');
      }
    } catch (e) {
      // Log error but don't rethrow - don't disrupt gameplay for network issues
      Logger.error('Error updating Tetris high score (non-blocking)', error: e, tag: 'GamesService');
    }
  }

  /// Update 2048 puzzle high score
  Future<void> updatePuzzle2048HighScore(String userId, String familyId, int score) async {
    try {
      final currentStats = await getUserStats(userId) ?? GameStats(userId: userId, familyId: familyId);
      if (score > currentStats.puzzle2048HighScore) {
        final updatedStats = currentStats.copyWith(
          puzzle2048HighScore: score,
          lastPlayed: DateTime.now(),
          lastUpdated: DateTime.now(),
        );
        await updateStats(updatedStats);
        Logger.info('Updated 2048 high score for $userId: $score', tag: 'GamesService');
      }
    } catch (e) {
      Logger.error('Error updating 2048 high score', error: e, tag: 'GamesService');
      rethrow;
    }
  }

  /// Update slide puzzle best time (in seconds, lower is better)
  Future<void> updateSlidePuzzleBestTime(String userId, String familyId, int timeInSeconds) async {
    try {
      final currentStats = await getUserStats(userId) ?? GameStats(userId: userId, familyId: familyId);
      if (currentStats.slidePuzzleBestTime == 0 || timeInSeconds < currentStats.slidePuzzleBestTime) {
        final updatedStats = currentStats.copyWith(
          slidePuzzleBestTime: timeInSeconds,
          lastPlayed: DateTime.now(),
          lastUpdated: DateTime.now(),
        );
        await updateStats(updatedStats);
        Logger.info('Updated slide puzzle best time for $userId: ${timeInSeconds}s', tag: 'GamesService');
      }
    } catch (e) {
      Logger.error('Error updating slide puzzle best time', error: e, tag: 'GamesService');
      rethrow;
    }
  }
}

