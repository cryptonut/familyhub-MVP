import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:uuid/uuid.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../services/auth_service.dart';
import '../models/chess_game.dart';
import '../models/chess_move.dart';

/// Service for managing chess games
class ChessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final _uuid = const Uuid();

  /// Create a new solo game (vs AI)
  Future<ChessGame> createSoloGame({
    required String userId,
    required String userName,
    AIDifficulty difficulty = AIDifficulty.medium,
    int timeLimitMs = 600000, // 10 minutes default
  }) async {
    try {
      final gameId = _uuid.v4();
      final game = ChessGame.newGame(
        id: gameId,
        whitePlayerId: userId,
        whitePlayerName: userName,
        blackPlayerId: null, // AI
        blackPlayerName: 'AI (${difficulty.name})',
        mode: GameMode.solo,
        metadata: {'aiDifficulty': difficulty.name},
        initialTimeMs: timeLimitMs,
      );

      await _firestore.collection('chess_games').doc(gameId).set(game.toJson());
      Logger.info('Created solo chess game: $gameId', tag: 'ChessService');
      return game;
    } catch (e, st) {
      Logger.error('Error creating solo game', error: e, stackTrace: st, tag: 'ChessService');
      throw AppException('Failed to create game: ${e.toString()}');
    }
  }

  /// Create a family game (invite family member)
  Future<ChessGame> createFamilyGame({
    required String whitePlayerId,
    required String whitePlayerName,
    required String familyId,
    int timeLimitMs = 600000,
  }) async {
    try {
      final gameId = _uuid.v4();
      final game = ChessGame.newGame(
        id: gameId,
        whitePlayerId: whitePlayerId,
        whitePlayerName: whitePlayerName,
        mode: GameMode.family,
        familyId: familyId,
        initialTimeMs: timeLimitMs,
      );

      await _firestore.collection('chess_games').doc(gameId).set(game.toJson());
      Logger.info('Created family chess game: $gameId', tag: 'ChessService');
      return game;
    } catch (e, st) {
      Logger.error('Error creating family game', error: e, stackTrace: st, tag: 'ChessService');
      throw AppException('Failed to create game: ${e.toString()}');
    }
  }

  /// Join a family game
  Future<ChessGame> joinFamilyGame({
    required String gameId,
    required String blackPlayerId,
    required String blackPlayerName,
  }) async {
    try {
      final gameDoc = await _firestore.collection('chess_games').doc(gameId).get();
      if (!gameDoc.exists) {
        throw AppException('Game not found');
      }

      final game = ChessGame.fromJson(gameDoc.data()!);
      if (game.status != GameStatus.waiting) {
        throw AppException('Game is not waiting for players');
      }
      if (game.mode != GameMode.family) {
        throw AppException('Not a family game');
      }

      final updatedGame = game.copyWith(
        blackPlayerId: blackPlayerId,
        blackPlayerName: blackPlayerName,
        status: GameStatus.active,
        startedAt: DateTime.now(),
      );

      await _firestore.collection('chess_games').doc(gameId).update(updatedGame.toJson());
      Logger.info('Player joined family game: $gameId', tag: 'ChessService');
      return updatedGame;
    } catch (e, st) {
      Logger.error('Error joining family game', error: e, stackTrace: st, tag: 'ChessService');
      rethrow;
    }
  }

  /// Join open matchmaking queue
  Future<String> joinMatchmakingQueue({
    required String userId,
    required String userName,
    required String? familyId,
    int timeLimitMs = 600000,
  }) async {
    try {
      // Check if family allows open mode
      if (familyId != null) {
        final familyDoc = await _firestore.collection('families').doc(familyId).get();
        if (familyDoc.exists) {
          final familyData = familyDoc.data();
          final openModeEnabled = familyData?['openChessModeEnabled'] as bool? ?? false;
          if (!openModeEnabled) {
            throw AppException('Open chess mode is disabled for your family');
          }
        }
      }

      // Add to matchmaking queue
      final queueId = _uuid.v4();
      await _firestore.collection('chess_matchmaking').doc(queueId).set({
        'userId': userId,
        'userName': userName,
        'familyId': familyId,
        'timeLimitMs': timeLimitMs,
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'waiting',
      });

      Logger.info('Joined matchmaking queue: $queueId', tag: 'ChessService');

      // Try to find a match immediately
      await _tryMatchmaking(userId, familyId);

      return queueId;
    } catch (e, st) {
      Logger.error('Error joining matchmaking', error: e, stackTrace: st, tag: 'ChessService');
      rethrow;
    }
  }

  /// Try to match player with another waiting player
  Future<void> _tryMatchmaking(String userId, String? familyId) async {
    try {
      // Find another player waiting (from different family)
      final waitingPlayers = await _firestore
          .collection('chess_matchmaking')
          .where('status', isEqualTo: 'waiting')
          .where('userId', isNotEqualTo: userId)
          .orderBy('createdAt')
          .limit(10)
          .get();

      for (var playerDoc in waitingPlayers.docs) {
        final playerData = playerDoc.data();
        final otherFamilyId = playerData['familyId'] as String?;

        // Don't match players from same family (they should use family mode)
        if (otherFamilyId == familyId && familyId != null) {
          continue;
        }

        // Found a match! Create game
        final otherUserId = playerData['userId'] as String;
        final otherUserName = playerData['userName'] as String;
        final timeLimitMs = playerData['timeLimitMs'] as int? ?? 600000;

        // Get current user info
        final currentUser = _auth.currentUser;
        if (currentUser == null) return;
        final currentUserModel = await _authService.getCurrentUserModel();
        final currentUserName = currentUserModel?.displayName ?? 'Player';

        // Randomly assign colors
        final isCurrentUserWhite = DateTime.now().millisecond % 2 == 0;
        final whiteId = isCurrentUserWhite ? currentUser.uid : otherUserId;
        final whiteName = isCurrentUserWhite ? currentUserName : otherUserName;
        final blackId = isCurrentUserWhite ? otherUserId : currentUser.uid;
        final blackName = isCurrentUserWhite ? otherUserName : currentUserName;

        final gameId = _uuid.v4();
        final game = ChessGame.newGame(
          id: gameId,
          whitePlayerId: whiteId,
          whitePlayerName: whiteName,
          blackPlayerId: blackId,
          blackPlayerName: blackName,
          mode: GameMode.open,
          initialTimeMs: timeLimitMs,
        );

        // Create game
        await _firestore.collection('chess_games').doc(gameId).set(game.toJson());

        // Remove both players from queue
        await _firestore.collection('chess_matchmaking').doc(playerDoc.id).delete();
        await _firestore
            .collection('chess_matchmaking')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'waiting')
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

        Logger.info('Matched players: $whiteName vs $blackName (game: $gameId)', tag: 'ChessService');
        return;
      }
    } catch (e, st) {
      Logger.error('Error in matchmaking', error: e, stackTrace: st, tag: 'ChessService');
    }
  }

  /// Leave matchmaking queue
  Future<void> leaveMatchmakingQueue(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chess_matchmaking')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'waiting')
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      Logger.info('Left matchmaking queue', tag: 'ChessService');
    } catch (e, st) {
      Logger.error('Error leaving matchmaking', error: e, stackTrace: st, tag: 'ChessService');
    }
  }

  /// Get a game by ID
  Future<ChessGame?> getGame(String gameId) async {
    try {
      final doc = await _firestore.collection('chess_games').doc(gameId).get();
      if (!doc.exists) return null;
      return ChessGame.fromJson(doc.data()!);
    } catch (e, st) {
      Logger.error('Error getting game', error: e, stackTrace: st, tag: 'ChessService');
      return null;
    }
  }

  /// Stream game updates
  Stream<ChessGame?> streamGame(String gameId) {
    return _firestore
        .collection('chess_games')
        .doc(gameId)
        .snapshots()
        .map((doc) => doc.exists ? ChessGame.fromJson(doc.data()!) : null);
  }

  /// Make a move in a game
  Future<ChessGame> makeMove({
    required String gameId,
    required String moveUCI, // e.g., "e2e4" or "e7e8q"
    String? userId, // for validation
  }) async {
    try {
      final gameDoc = await _firestore.collection('chess_games').doc(gameId).get();
      if (!gameDoc.exists) {
        throw AppException('Game not found');
      }

      var game = ChessGame.fromJson(gameDoc.data()!);
      if (game.status != GameStatus.active) {
        throw AppException('Game is not active');
      }

      // Validate it's the user's turn
      if (userId != null) {
        if (!game.isMyTurn(userId)) {
          throw AppException('Not your turn');
        }
      }

      // Create chess engine instance from FEN
      final chess = chess_lib.Chess();
      chess.load(game.fen);

      // Validate and make move
      final move = ChessMove.fromUCI(moveUCI);
      final fromIndex = _squareToIndex(move.from);
      final toIndex = _squareToIndex(move.to);

      // Get valid moves
      final validMoves = chess.generate_moves({'verbose': true});
      final validMove = validMoves.firstWhere(
        (m) => m.from == fromIndex && m.to == toIndex && (move.promotion == null || _getPromotionPiece(move.promotion!) == m.promotion),
        orElse: () => throw AppException('Invalid move'),
      );

      // Make the move
      chess.move({
        'from': fromIndex,
        'to': toIndex,
        'promotion': move.promotion != null ? _getPromotionPiece(move.promotion!) : null,
      });

      // Update game state
      final newMove = ChessMove(
        from: move.from,
        to: move.to,
        promotion: move.promotion,
        uci: moveUCI,
        san: chess.history.isNotEmpty ? chess.history.last : null,
        timestamp: DateTime.now(),
      );

      final updatedMoves = [...game.moves, newMove];
      final newFen = chess.fen;
      final isCheck = chess.in_check;
      final isCheckmate = chess.in_checkmate;
      final isStalemate = chess.in_stalemate;
      final isDraw = chess.in_draw || chess.in_threefold_repetition;

      // Update game
      var updatedGame = game.copyWith(
        fen: newFen,
        moves: updatedMoves,
        isWhiteTurn: !game.isWhiteTurn,
        lastMove: moveUCI,
        whiteCanCastleKingside: chess.castling['w']?.contains('K') ?? false,
        whiteCanCastleQueenside: chess.castling['w']?.contains('Q') ?? false,
        blackCanCastleKingside: chess.castling['b']?.contains('k') ?? false,
        blackCanCastleQueenside: chess.castling['b']?.contains('q') ?? false,
        enPassantSquare: chess.ep_square != null ? _indexToSquare(chess.ep_square!) : null,
        halfmoveClock: chess.half_moves,
        fullmoveNumber: chess.move_number,
      );

      // Check for game end
      if (isCheckmate) {
        updatedGame = updatedGame.copyWith(
          status: GameStatus.finished,
          finishedAt: DateTime.now(),
          result: game.isWhiteTurn ? GameResult.blackWin : GameResult.whiteWin,
          winnerId: game.isWhiteTurn ? game.blackPlayerId : game.whitePlayerId,
          resultReason: 'checkmate',
        );
      } else if (isStalemate || isDraw) {
        updatedGame = updatedGame.copyWith(
          status: GameStatus.finished,
          finishedAt: DateTime.now(),
          result: GameResult.draw,
          resultReason: isStalemate ? 'stalemate' : 'draw',
        );
      }

      // Save to Firebase
      await _firestore.collection('chess_games').doc(gameId).update(updatedGame.toJson());

      // Update stats if game finished
      if (updatedGame.status == GameStatus.finished) {
        await _updateGameStats(updatedGame);
      }

      Logger.info('Move made in game $gameId: $moveUCI', tag: 'ChessService');
      return updatedGame;
    } catch (e, st) {
      Logger.error('Error making move', error: e, stackTrace: st, tag: 'ChessService');
      rethrow;
    }
  }

  /// Resign from a game
  Future<void> resignGame(String gameId, String userId) async {
    try {
      final game = await getGame(gameId);
      if (game == null) throw AppException('Game not found');
      if (game.status != GameStatus.active) throw AppException('Game is not active');
      if (!game.isPlayer(userId)) throw AppException('You are not a player in this game');

      final winnerId = game.whitePlayerId == userId ? game.blackPlayerId : game.whitePlayerId;
      final updatedGame = game.copyWith(
        status: GameStatus.finished,
        finishedAt: DateTime.now(),
        result: game.whitePlayerId == userId ? GameResult.blackWin : GameResult.whiteWin,
        winnerId: winnerId,
        resultReason: 'resignation',
      );

      await _firestore.collection('chess_games').doc(gameId).update(updatedGame.toJson());
      await _updateGameStats(updatedGame);
      Logger.info('Player resigned from game $gameId', tag: 'ChessService');
    } catch (e, st) {
      Logger.error('Error resigning game', error: e, stackTrace: st, tag: 'ChessService');
      rethrow;
    }
  }

  /// Get user's active games
  Future<List<ChessGame>> getActiveGames(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chess_games')
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs
          .map((doc) => ChessGame.fromJson(doc.data()))
          .where((game) => game.isPlayer(userId))
          .toList();
    } catch (e, st) {
      Logger.error('Error getting active games', error: e, stackTrace: st, tag: 'ChessService');
      return [];
    }
  }

  /// Get user's game history
  Future<List<ChessGame>> getGameHistory(String userId, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('chess_games')
          .where('status', isEqualTo: 'finished')
          .orderBy('finishedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ChessGame.fromJson(doc.data()))
          .where((game) => game.isPlayer(userId))
          .toList();
    } catch (e, st) {
      Logger.error('Error getting game history', error: e, stackTrace: st, tag: 'ChessService');
      return [];
    }
  }

  /// Update game statistics
  Future<void> _updateGameStats(ChessGame game) async {
    try {
      if (game.status != GameStatus.finished || game.result == null) return;

      // Update stats for both players
      final players = [game.whitePlayerId, game.blackPlayerId].whereType<String>().toList();
      for (var playerId in players) {
        final userModel = await _authService.getUserModel(playerId);
        if (userModel?.familyId == null) continue;

        final isWinner = game.winnerId == playerId;
        final isDraw = game.result == GameResult.draw;

        // Get current stats
        final statsDoc = await _firestore
            .collection('families')
            .doc(userModel!.familyId)
            .collection('game_stats')
            .doc(playerId)
            .get();

        final currentWins = (statsDoc.data()?['winsChess'] as num?)?.toInt() ?? 0;
        final currentLosses = (statsDoc.data()?['lossesChess'] as num?)?.toInt() ?? 0;
        final currentDraws = (statsDoc.data()?['drawsChess'] as num?)?.toInt() ?? 0;

        await _firestore
            .collection('families')
            .doc(userModel.familyId)
            .collection('game_stats')
            .doc(playerId)
            .set({
          'winsChess': isWinner ? currentWins + 1 : currentWins,
          'lossesChess': !isWinner && !isDraw ? currentLosses + 1 : currentLosses,
          'drawsChess': isDraw ? currentDraws + 1 : currentDraws,
          'lastPlayed': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }
    } catch (e, st) {
      Logger.error('Error updating game stats', error: e, stackTrace: st, tag: 'ChessService');
    }
  }

  /// Helper: Convert square name to index
  int _squareToIndex(String square) {
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    return rank * 8 + file;
  }

  /// Helper: Convert index to square name
  String _indexToSquare(int index) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + (index % 8));
    final rank = (index ~/ 8) + 1;
    return '$file$rank';
  }

  /// Helper: Get promotion piece type
  chess_lib.PieceType? _getPromotionPiece(String promotion) {
    switch (promotion.toLowerCase()) {
      case 'q':
        return chess_lib.PieceType.QUEEN;
      case 'r':
        return chess_lib.PieceType.ROOK;
      case 'b':
        return chess_lib.PieceType.BISHOP;
      case 'n':
        return chess_lib.PieceType.KNIGHT;
      default:
        return null;
    }
  }
}

enum AIDifficulty {
  easy,
  medium,
  hard,
}

