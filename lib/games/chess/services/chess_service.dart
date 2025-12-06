import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../services/auth_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/chat_service.dart';
import '../../../models/chat_message.dart';
import '../models/chess_game.dart';
import '../models/chess_move.dart';

/// Service for managing chess games
class ChessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final ChatService _chatService = ChatService();
  final Connectivity _connectivity = Connectivity();
  final _uuid = const Uuid();
  
  // FCM topic for chess invites
  static const String _chessTopic = 'family-chess';
  
  // Timeout duration for invites (2 minutes)
  static const Duration _inviteTimeout = Duration(minutes: 2);
  
  // Map of roomId -> Timer for timeout handling
  final Map<String, Timer> _inviteTimers = {};
  
  // Hive box for offline caching
  static const String _inviteCacheBox = 'chess_invites_cache';
  Box? _inviteCacheBoxInstance;
  
  /// Initialize the service (call this after Hive is initialized)
  Future<void> initialize() async {
    try {
      _inviteCacheBoxInstance = await Hive.openBox(_inviteCacheBox);
      _retryCachedInvites();
      _setupConnectivityListener();
    } catch (e, st) {
      Logger.error('Error initializing ChessService', error: e, stackTrace: st, tag: 'ChessService');
    }
  }
  
  /// Set up connectivity listener to retry cached invites on reconnect
  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _retryCachedInvites();
      }
    });
  }
  
  /// Retry sending cached invites when connectivity is restored
  Future<void> _retryCachedInvites() async {
    if (_inviteCacheBoxInstance == null) return;
    
    try {
      final cachedInvites = _inviteCacheBoxInstance!.values.toList();
      for (var inviteData in cachedInvites) {
        if (inviteData is Map) {
          try {
            await _sendFCMInvite(
              roomId: inviteData['roomId'] as String,
              sender: inviteData['sender'] as String,
              targetUser: inviteData['targetUser'] as String,
              timestamp: inviteData['timestamp'] as int,
            );
            // Remove from cache on success
            await _inviteCacheBoxInstance!.delete(inviteData['roomId'] as String);
          } catch (e) {
            Logger.warning('Failed to retry cached invite', error: e, tag: 'ChessService');
          }
        }
      }
    } catch (e, st) {
      Logger.error('Error retrying cached invites', error: e, stackTrace: st, tag: 'ChessService');
    }
  }

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
      throw FirestoreException('Failed to create game: ${e.toString()}');
    }
  }

  /// Create a family game (invite family member)
  /// When inviting a specific opponent, the game is created in "waiting" status
  /// The opponent must join via joinFamilyGame to start the game
  /// Sends FCM topic-based invite and sets up 2-minute timeout
  Future<ChessGame> createFamilyGame({
    required String whitePlayerId,
    required String whitePlayerName,
    required String familyId,
    String? invitedPlayerId, // The player being invited (they must join)
    String? invitedPlayerName, // Name of invited player (for display)
    int timeLimitMs = 600000,
  }) async {
    try {
      final gameId = _uuid.v4();
      // Create game in waiting status - blackPlayerId is null until opponent joins
      final game = ChessGame.newGame(
        id: gameId,
        whitePlayerId: whitePlayerId,
        whitePlayerName: whitePlayerName,
        blackPlayerId: null, // Will be set when opponent joins
        blackPlayerName: invitedPlayerName, // Show name for display, but they haven't joined yet
        mode: GameMode.family,
        familyId: familyId,
        initialTimeMs: timeLimitMs,
        invitedPlayerId: invitedPlayerId, // Store intended opponent
      );

      await _firestore.collection('chess_games').doc(gameId).set(game.toJson());
      Logger.info('Created family chess game: $gameId (invited: $invitedPlayerId)', tag: 'ChessService');
      
      // Create invite document in Firestore
      if (invitedPlayerId != null) {
        final inviteData = {
          'roomId': gameId,
          'sender': whitePlayerId,
          'targetUser': invitedPlayerId,
          'status': 'pending',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'createdAt': DateTime.now().toIso8601String(),
        };
        
        await _firestore.collection('invites').doc(gameId).set(inviteData);
        
        // Send FCM invite via topic
        try {
          await _sendFCMInvite(
            roomId: gameId,
            sender: whitePlayerId,
            targetUser: invitedPlayerId,
            timestamp: inviteData['timestamp'] as int,
          );
        } catch (e, st) {
          Logger.warning('FCM send failed, caching invite for retry', error: e, stackTrace: st, tag: 'ChessService');
          // Cache invite for offline retry
          if (_inviteCacheBoxInstance != null) {
            await _inviteCacheBoxInstance!.put(gameId, inviteData);
          }
        }
        
        // Set up 2-minute timeout
        _startInviteTimeout(gameId, whitePlayerId, invitedPlayerId, invitedPlayerName ?? 'Player');
      }
      
      return game;
    } catch (e, st) {
      Logger.error('Error creating family game', error: e, stackTrace: st, tag: 'ChessService');
      throw FirestoreException('Failed to create game: ${e.toString()}');
    }
  }
  
  /// Send FCM data-only message to 'family-chess' topic
  /// Payload: {action: 'chess_invite', sender, roomId, timestamp, targetUser}
  Future<void> _sendFCMInvite({
    required String roomId,
    required String sender,
    required String targetUser,
    required int timestamp,
  }) async {
    try {
      // Note: FCM topic messaging from client requires Cloud Functions
      // For now, we'll use Firestore to trigger Cloud Function or use HTTP API
      // This is a placeholder - in production, use Cloud Functions to send FCM
      Logger.info('Sending FCM invite for room $roomId', tag: 'ChessService');
      
      // Store FCM message data in Firestore for Cloud Function to process
      await _firestore.collection('fcm_messages').add({
        'topic': _chessTopic,
        'data': {
          'action': 'chess_invite',
          'sender': sender,
          'roomId': roomId,
          'timestamp': timestamp,
          'targetUser': targetUser,
        },
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      Logger.error('Error sending FCM invite', error: e, stackTrace: st, tag: 'ChessService');
      rethrow;
    }
  }
  
  /// Start 2-minute timeout timer for invite
  /// If no accept/decline in 120 seconds, cancel invite and notify challenger
  void _startInviteTimeout(String roomId, String challengerId, String invitedUserId, String invitedUserName) {
    // Cancel existing timer if any
    _inviteTimers[roomId]?.cancel();
    
    _inviteTimers[roomId] = Timer(_inviteTimeout, () async {
      try {
        // Check if invite still exists and is pending
        final inviteDoc = await _firestore.collection('invites').doc(roomId).get();
        if (!inviteDoc.exists) {
          _inviteTimers.remove(roomId);
          return;
        }
        
        final inviteData = inviteDoc.data();
        if (inviteData?['status'] != 'pending') {
          _inviteTimers.remove(roomId);
          return;
        }
        
        // Timeout expired - cancel invite
        await _firestore.collection('invites').doc(roomId).delete();
        
        // Delete game if still waiting
        final gameDoc = await _firestore.collection('chess_games').doc(roomId).get();
        if (gameDoc.exists) {
          final gameData = gameDoc.data();
          if (gameData?['status'] == 'waiting') {
            await _firestore.collection('chess_games').doc(roomId).delete();
          }
        }
        
        // Send chat message to challenger
        final userModel = await _authService.getUserModel(invitedUserId);
        final invitedName = userModel?.displayName ?? invitedUserName;
        
        await _chatService.sendMessage(
          ChatMessage(
            id: _uuid.v4(),
            senderId: 'system',
            senderName: 'System',
            content: 'Challenge to $invitedName expired.',
            timestamp: DateTime.now(),
          ),
        );
        
        Logger.info('Invite $roomId expired and cancelled', tag: 'ChessService');
        _inviteTimers.remove(roomId);
      } catch (e, st) {
        Logger.error('Error handling invite timeout', error: e, stackTrace: st, tag: 'ChessService');
        _inviteTimers.remove(roomId);
      }
    });
  }
  
  /// Accept a chess invite
  /// Updates invite status, joins the game, and publishes 'chess_start' to FCM topic
  Future<ChessGame> acceptInvite(String roomId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw AuthException('User not logged in', code: 'not-authenticated');
      
      final inviteDoc = await _firestore.collection('invites').doc(roomId).get();
      if (!inviteDoc.exists) {
        throw FirestoreException('Invite not found', code: 'not-found');
      }
      
      final inviteData = inviteDoc.data()!;
      if (inviteData['status'] != 'pending') {
        throw ValidationException('Invite has already been ${inviteData['status']}');
      }
      
      if (inviteData['targetUser'] != currentUser.uid) {
        throw ValidationException('This invite is not for you');
      }
      
      // Get user model for name
      final userModel = await _authService.getCurrentUserModel();
      final userName = userModel?.displayName ?? 'Player';
      
      // Update invite status
      await _firestore.collection('invites').doc(roomId).update({'status': 'accepted'});
      
      // Cancel timeout timer
      _inviteTimers[roomId]?.cancel();
      _inviteTimers.remove(roomId);
      
      // Actually join the game (this was missing!)
      final joinedGame = await joinFamilyGame(
        gameId: roomId,
        blackPlayerId: currentUser.uid,
        blackPlayerName: userName,
      );
      
      final senderId = inviteData['sender'] as String;
      
      // Publish 'chess_start' to FCM topic
      await _firestore.collection('fcm_messages').add({
        'topic': _chessTopic,
        'data': {
          'action': 'chess_start',
          'roomId': roomId,
          'players': [senderId, currentUser.uid],
        },
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      Logger.info('Invite $roomId accepted and game joined', tag: 'ChessService');
      return joinedGame;
    } catch (e, st) {
      Logger.error('Error accepting invite', error: e, stackTrace: st, tag: 'ChessService');
      rethrow;
    }
  }
  
  /// Decline a chess invite
  /// Updates invite status and sends chat message to challenger
  Future<void> declineInvite(String roomId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw AuthException('User not logged in', code: 'not-authenticated');
      
      final inviteDoc = await _firestore.collection('invites').doc(roomId).get();
      if (!inviteDoc.exists) {
        throw FirestoreException('Invite not found', code: 'not-found');
      }
      
      final inviteData = inviteDoc.data()!;
      if (inviteData['status'] != 'pending') {
        throw ValidationException('Invite has already been ${inviteData['status']}');
      }
      
      if (inviteData['targetUser'] != currentUser.uid) {
        throw ValidationException('This invite is not for you');
      }
      
      // Update invite status
      await _firestore.collection('invites').doc(roomId).update({'status': 'declined'});
      
      // Cancel timeout timer
      _inviteTimers[roomId]?.cancel();
      _inviteTimers.remove(roomId);
      
      // Delete game
      await _firestore.collection('chess_games').doc(roomId).delete();
      
      // Send chat message to challenger
      final userModel = await _authService.getCurrentUserModel();
      final userName = userModel?.displayName ?? 'Player';
      
      await _chatService.sendMessage(
        ChatMessage(
          id: _uuid.v4(),
          senderId: 'system',
          senderName: 'System',
          content: '$userName passed on the chess challenge.',
          timestamp: DateTime.now(),
        ),
      );
      
      Logger.info('Invite $roomId declined', tag: 'ChessService');
    } catch (e, st) {
      Logger.error('Error declining invite', error: e, stackTrace: st, tag: 'ChessService');
      rethrow;
    }
  }

  /// Join a family game
  /// Validates that the joining player is the invited opponent (if game has an invited player)
  /// Also updates invite status if there's a pending invite
  Future<ChessGame> joinFamilyGame({
    required String gameId,
    required String blackPlayerId,
    required String blackPlayerName,
  }) async {
    try {
      final gameDoc = await _firestore.collection('chess_games').doc(gameId).get();
      if (!gameDoc.exists) {
        throw FirestoreException('Game not found', code: 'not-found');
      }

      final game = ChessGame.fromJson(gameDoc.data()!);
      if (game.status != GameStatus.waiting) {
        throw ValidationException('Game is not waiting for players');
      }
      if (game.mode != GameMode.family) {
        throw ValidationException('Not a family game');
      }
      
      // Validate: If game has an invited player, only that player can join
      if (game.invitedPlayerId != null && game.invitedPlayerId != blackPlayerId) {
        throw ValidationException('This game was created for a different player');
      }
      
      // Prevent joining your own game
      if (game.whitePlayerId == blackPlayerId) {
        throw ValidationException('You cannot join your own game');
      }

      // Update invite status if there's a pending invite
      final inviteDoc = await _firestore.collection('invites').doc(gameId).get();
      if (inviteDoc.exists) {
        final inviteData = inviteDoc.data();
        if (inviteData?['status'] == 'pending' && inviteData?['targetUser'] == blackPlayerId) {
          await _firestore.collection('invites').doc(gameId).update({'status': 'accepted'});
          // Cancel timeout timer
          _inviteTimers[gameId]?.cancel();
          _inviteTimers.remove(gameId);
        }
      }

      final updatedGame = game.copyWith(
        blackPlayerId: blackPlayerId,
        blackPlayerName: blackPlayerName,
        status: GameStatus.active,
        startedAt: DateTime.now(),
        invitedPlayerId: null, // Clear invitation once player joins
      );

      await _firestore.collection('chess_games').doc(gameId).update(updatedGame.toJson());
      Logger.info('Player $blackPlayerId joined family game: $gameId', tag: 'ChessService');
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
            throw ValidationException('Open chess mode is disabled for your family');
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
        throw FirestoreException('Game not found', code: 'not-found');
      }

      var game = ChessGame.fromJson(gameDoc.data()!);
      if (game.status != GameStatus.active) {
        throw ValidationException('Game is not active');
      }

      // Validate it's the user's turn
      if (userId != null) {
        if (!game.isMyTurn(userId)) {
          throw ValidationException('Not your turn');
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
        orElse: () => throw ValidationException('Invalid move'),
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
        san: chess.history.isNotEmpty ? (chess.history.last as String) : null,
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
        // Castling rights - chess library stores as string like "KQkq"
        whiteCanCastleKingside: (chess.castling.toString().contains('K')),
        whiteCanCastleQueenside: (chess.castling.toString().contains('Q')),
        blackCanCastleKingside: (chess.castling.toString().contains('k')),
        blackCanCastleQueenside: (chess.castling.toString().contains('q')),
        enPassantSquare: chess.ep_square != null ? _indexToSquare(chess.ep_square!) : null,
        halfmoveClock: chess.half_moves,
        fullmoveNumber: chess.move_number,
      );

      // Check for game end
      if (isCheckmate) {
        updatedGame = updatedGame.copyWith(
          status: GameStatus.finished,
          finishedAt: DateTime.now(),
          result: game.isWhiteTurn ? GameResult.whiteWin : GameResult.blackWin,
          winnerId: game.isWhiteTurn ? game.whitePlayerId : game.blackPlayerId,
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
      if (game == null) throw FirestoreException('Game not found', code: 'not-found');
      if (game.status != GameStatus.active) throw ValidationException('Game is not active');
      if (!game.isPlayer(userId)) throw ValidationException('You are not a player in this game');

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

  /// Get waiting family games for a family
  Future<List<ChessGame>> getWaitingFamilyGames(String familyId) async {
    try {
      final snapshot = await _firestore
          .collection('chess_games')
          .where('mode', isEqualTo: 'family')
          .where('familyId', isEqualTo: familyId)
          .where('status', isEqualTo: 'waiting')
          .get();

      return snapshot.docs
          .map((doc) => ChessGame.fromJson(doc.data()))
          .toList();
    } catch (e, st) {
      Logger.error('Error getting waiting family games', error: e, stackTrace: st, tag: 'ChessService');
      return [];
    }
  }

  /// Stream waiting family games for real-time updates
  Stream<List<ChessGame>> streamWaitingFamilyGames(String familyId) {
    return _firestore
        .collection('chess_games')
        .where('mode', isEqualTo: 'family')
        .where('familyId', isEqualTo: familyId)
        .where('status', isEqualTo: 'waiting')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChessGame.fromJson(doc.data()))
            .toList());
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

  /// Helper: Convert square name to 0x88 index format
  /// The chess library uses 0x88 format where:
  /// - file = index & 0x0F (lower 4 bits)
  /// - rank = index >> 4 (upper 4 bits)
  int _squareToIndex(String square) {
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    return (rank << 4) | file; // 0x88 format
  }

  /// Helper: Convert 0x88 index to square name
  String _indexToSquare(int index) {
    final file = index & 0x0F; // Lower 4 bits
    final rank = index >> 4; // Upper 4 bits
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    return '$fileChar${rank + 1}';
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

