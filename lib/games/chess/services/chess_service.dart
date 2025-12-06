import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final ChatService _chatService = ChatService();
  final Connectivity _connectivity = Connectivity();
  final _uuid = const Uuid();
  
  // Timeout duration for invites (10 minutes - extended to prevent premature timeouts during gameplay)
  static const Duration _inviteTimeout = Duration(minutes: 10);
  
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
  /// NOTE: FCM removed - invites are now handled via Firestore streams only
  Future<void> _retryCachedInvites() async {
    // FCM removed - no longer needed as invites are handled via Firestore streams
    // Clear any old cached invites
    if (_inviteCacheBoxInstance != null) {
      try {
        await _inviteCacheBoxInstance!.clear();
      } catch (e) {
        Logger.warning('Error clearing cached invites', error: e, tag: 'ChessService');
      }
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
  /// Sets up timeout for invite expiration
  /// Cancel any existing waiting games between two specific players
  /// This ensures only one waiting challenge exists between any two parties
  /// Handles both directions: games where currentUser challenged opponent, and vice versa
  Future<void> _cancelExistingWaitingGamesBetweenPlayers({
    required String currentUserId, // The user creating the new challenge
    required String opponentId,
    required String familyId,
  }) async {
    try {
      int cancelledCount = 0;
      
      // Find all waiting games between these two players in either direction
      // Query 1: currentUser challenged opponent
      final query1 = await _firestore
          .collection('chess_games')
          .where('mode', isEqualTo: 'family')
          .where('familyId', isEqualTo: familyId)
          .where('status', isEqualTo: 'waiting')
          .where('whitePlayerId', isEqualTo: currentUserId)
          .where('invitedPlayerId', isEqualTo: opponentId)
          .get();
      
      // Query 2: opponent challenged currentUser
      final query2 = await _firestore
          .collection('chess_games')
          .where('mode', isEqualTo: 'family')
          .where('familyId', isEqualTo: familyId)
          .where('status', isEqualTo: 'waiting')
          .where('whitePlayerId', isEqualTo: opponentId)
          .where('invitedPlayerId', isEqualTo: currentUserId)
          .get();
      
      // Cancel all found games
      for (var doc in [...query1.docs, ...query2.docs]) {
        final gameId = doc.id;
        try {
          // Cancel timeout timer if exists
          _inviteTimers[gameId]?.cancel();
          _inviteTimers.remove(gameId);
          
          // Use deleteGame which handles permissions correctly
          // It will work if currentUser is whitePlayerId or invitedPlayerId
          await deleteGame(gameId);
          
          cancelledCount++;
        } catch (e) {
          Logger.warning('Could not cancel game $gameId: $e', tag: 'ChessService');
          // If deleteGame fails, try to at least clean up the invite
          try {
            await _firestore.collection('invites').doc(gameId).update({'status': 'declined'});
          } catch (e2) {
            Logger.warning('Could not update invite status for game $gameId: $e2', tag: 'ChessService');
          }
        }
      }
      
      if (cancelledCount > 0) {
        Logger.info('Cancelled $cancelledCount existing waiting game(s) between $currentUserId and $opponentId', tag: 'ChessService');
      }
    } catch (e, st) {
      Logger.error('Error cancelling existing waiting games', error: e, stackTrace: st, tag: 'ChessService');
      // Don't throw - we still want to create the new game even if cleanup fails
    }
  }

  /// Create a family chess game
  /// Validates inputs and ensures only one waiting challenge exists between players
  Future<ChessGame> createFamilyGame({
    required String whitePlayerId,
    required String whitePlayerName,
    required String familyId,
    String? invitedPlayerId, // The player being invited (they must join)
    String? invitedPlayerName, // Name of invited player (for display)
    int timeLimitMs = 600000,
  }) async {
    try {
      // Validate inputs
      if (whitePlayerId.isEmpty) {
        throw ValidationException('White player ID is required');
      }
      if (familyId.isEmpty) {
        throw ValidationException('Family ID is required');
      }
      if (invitedPlayerId != null && invitedPlayerId == whitePlayerId) {
        throw ValidationException('Cannot challenge yourself');
      }
      if (timeLimitMs <= 0) {
        throw ValidationException('Time limit must be positive');
      }
      
      // CRITICAL: Cancel any existing waiting games between these two players
      // This ensures only one waiting challenge exists between any two parties
      if (invitedPlayerId != null) {
        await _cancelExistingWaitingGamesBetweenPlayers(
          currentUserId: whitePlayerId,
          opponentId: invitedPlayerId,
          familyId: familyId,
        );
      }
      
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
        
        // Invites are now handled via Firestore streams - no FCM needed
        Logger.info('Invite created for game $gameId - target user will see it via Firestore stream', tag: 'ChessService');
        
        // Set up timeout
        _startInviteTimeout(gameId, whitePlayerId, invitedPlayerId, invitedPlayerName ?? 'Player');
      }
      
      return game;
    } catch (e, st) {
      Logger.error('Error creating family game', error: e, stackTrace: st, tag: 'ChessService');
      throw FirestoreException('Failed to create game: ${e.toString()}');
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
        // CRITICAL: Only delete if game is still waiting - never delete active games
        final gameDoc = await _firestore.collection('chess_games').doc(roomId).get();
        if (gameDoc.exists) {
          final gameData = gameDoc.data();
          final gameStatus = gameData?['status'] as String?;
          // Only delete if game is still waiting - if it's active, players are playing
          if (gameStatus == 'waiting') {
            await _firestore.collection('invites').doc(roomId).delete();
            await _firestore.collection('chess_games').doc(roomId).delete();
            Logger.info('Timeout: Deleted waiting game $roomId', tag: 'ChessService');
          } else {
            // Game is active - just delete the invite, don't touch the game
            await _firestore.collection('invites').doc(roomId).delete();
            Logger.info('Timeout: Game $roomId is active, only deleted invite', tag: 'ChessService');
          }
        } else {
          // Game doesn't exist, just clean up invite
          await _firestore.collection('invites').doc(roomId).delete();
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
  /// ATOMIC: Uses transaction to update both invite and game in one operation
  /// Updates invite status and joins the game as black player
  Future<ChessGame> acceptInvite(String roomId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw AuthException('User not logged in', code: 'not-authenticated');
      
      // Get user model for the player name
      final userModel = await _authService.getCurrentUserModel();
      final playerName = userModel?.displayName ?? 'Player';
      
      // ATOMIC TRANSACTION: Update both invite and game in one operation
      final updatedGame = await _firestore.runTransaction<ChessGame>((transaction) async {
        // Fetch invite document
        final inviteDoc = await transaction.get(_firestore.collection('invites').doc(roomId));
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
        
        // Fetch game document
        final gameDoc = await transaction.get(_firestore.collection('chess_games').doc(roomId));
        if (!gameDoc.exists) {
          throw FirestoreException('Game not found', code: 'not-found');
        }
        
        final game = ChessGame.fromJson(gameDoc.data()!);
        
        // EXPLICIT state validation
        if (game.status != GameStatus.waiting) {
          throw ValidationException('Game must be waiting to accept');
        }
        if (game.invitedPlayerId != currentUser.uid) {
          throw ValidationException('You are not invited to this game');
        }
        if (game.blackPlayerId != null) {
          throw ValidationException('Game already has a black player');
        }
        if (game.mode != GameMode.family) {
          throw ValidationException('Not a family game');
        }
        
        // Update invite status
        transaction.update(inviteDoc.reference, {'status': 'accepted'});
        
        // Update game: set blackPlayerId, clear invitedPlayerId, set status=active
        final updatedGame = game.copyWith(
          blackPlayerId: currentUser.uid,
          blackPlayerName: playerName,
          status: GameStatus.active,
          startedAt: DateTime.now(),
          invitedPlayerId: null, // Clear invitation once player joins
        );
        
        transaction.update(gameDoc.reference, updatedGame.toJson());
        
        return updatedGame;
      });
      
      // Cancel timeout timer
      _inviteTimers[roomId]?.cancel();
      _inviteTimers.remove(roomId);
      
      // Challenger will be notified via Firestore stream - no FCM needed
      Logger.info('Invite $roomId accepted and game joined atomically - challenger will be notified via Firestore stream', tag: 'ChessService');
      return updatedGame;
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
  /// ONLY for the invited player (black) to join a waiting game
  /// The challenger (white) should NEVER call this - they're already in the game
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
      if (game.mode != GameMode.family) {
        throw ValidationException('Not a family game');
      }
      
      // CRITICAL: The challenger (whitePlayerId) should NEVER call this method
      // They're already in the game and should just navigate to it
      if (game.whitePlayerId == blackPlayerId) {
        throw ValidationException('You are already in this game as the challenger. Just navigate to the game screen.');
      }
      
      // If game is already active, check if this player is already the black player
      if (game.status == GameStatus.active) {
        if (game.blackPlayerId == blackPlayerId) {
          // Player is already in the game, just return it
          Logger.info('Player $blackPlayerId is already in active game: $gameId', tag: 'ChessService');
          return game;
        } else {
          throw ValidationException('Game is already active with a different player');
        }
      }
      
      // Normal case: Opponent joining a waiting game
      if (game.status != GameStatus.waiting) {
        throw ValidationException('Game is not waiting for players');
      }
      
      // Validate: If game has an invited player, only that player can join
      if (game.invitedPlayerId != null && game.invitedPlayerId != blackPlayerId) {
        throw ValidationException('This game was created for a different player');
      }
      
      // Prevent blackPlayerId from being null or empty
      if (blackPlayerId.isEmpty) {
        throw ValidationException('Invalid player ID');
      }

      // Use Firestore transaction to prevent race conditions
      final updatedGame = await _firestore.runTransaction<ChessGame>((transaction) async {
        // Re-fetch the game document within the transaction
        final freshGameDoc = await transaction.get(_firestore.collection('chess_games').doc(gameId));
        if (!freshGameDoc.exists) {
          throw FirestoreException('Game not found', code: 'not-found');
        }
        
        final freshGame = ChessGame.fromJson(freshGameDoc.data()!);
        
        // Double-check game is still waiting and blackPlayerId is still null
        if (freshGame.status != GameStatus.waiting) {
          throw ValidationException('Game is no longer waiting for players');
        }
        
        if (freshGame.blackPlayerId != null) {
          throw ValidationException('Another player has already joined this game');
        }
        
        // Validate invited player matches
        if (freshGame.invitedPlayerId != null && freshGame.invitedPlayerId != blackPlayerId) {
          throw ValidationException('This game was created for a different player');
        }
        
        // Create updated game
        final newGame = freshGame.copyWith(
          blackPlayerId: blackPlayerId,
          blackPlayerName: blackPlayerName,
          status: GameStatus.active,
          startedAt: DateTime.now(),
          invitedPlayerId: null, // Clear invitation once player joins
        );
        
        // Update in transaction
        transaction.update(_firestore.collection('chess_games').doc(gameId), newGame.toJson());
        
        return newGame;
      });

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
  /// Uses Firestore transaction to prevent race conditions and ensure atomic updates
  Future<ChessGame> makeMove({
    required String gameId,
    required String moveUCI, // e.g., "e2e4" or "e7e8q"
    String? userId, // for validation
  }) async {
    try {
      if (userId == null) {
        throw ValidationException('User ID is required to make a move');
      }
      
      // Use transaction to prevent race conditions
      final updatedGame = await _firestore.runTransaction<ChessGame>((transaction) async {
        final gameDoc = await transaction.get(_firestore.collection('chess_games').doc(gameId));
        if (!gameDoc.exists) {
          throw FirestoreException('Game not found', code: 'not-found');
        }

        var game = ChessGame.fromJson(gameDoc.data()!);
        if (game.status != GameStatus.active) {
          throw ValidationException('Game is not active');
        }
        
        // Validate both players are in the game
        if (game.blackPlayerId == null) {
          throw ValidationException('Game is not ready - opponent has not joined');
        }
        
        // Validate user is a player
        if (!game.isPlayer(userId)) {
          throw ValidationException('You are not a player in this game');
        }

        // Validate it's the user's turn
        if (!game.isMyTurn(userId)) {
          throw ValidationException('Not your turn');
        }

        // Create chess engine instance from FEN
        final chess = chess_lib.Chess();
        chess.load(game.fen);
        
        // Log FEN and turn for debugging
        Logger.debug(
          'makeMove: gameId=$gameId, userId=$userId, moveUCI=$moveUCI, '
          'gameFEN=${game.fen}, engineTurn=${chess.turn}, game.isWhiteTurn=${game.isWhiteTurn}',
          tag: 'ChessService'
        );

        // Validate and make move
        final move = ChessMove.fromUCI(moveUCI);

        // SIMPLIFIED: Just try the move directly - the chess engine will reject invalid moves
        // Don't pre-validate with generate_moves as it can be out of sync
        final moveResult = chess.move({
          'from': move.from,  // Use string square name like "e2"
          'to': move.to,      // Use string square name like "e4"
          'promotion': move.promotion,  // Promotion piece as string like "q"
        });

        if (moveResult == null) {
          // Move was rejected by chess engine - this is the source of truth
          throw ValidationException('Invalid move: $moveUCI');
        }

        // Update game state
        // Note: chess.history returns State objects, not strings
        // We'll generate SAN from the move if needed, but for now just use UCI
        final newMove = ChessMove(
          from: move.from,
          to: move.to,
          promotion: move.promotion,
          uci: moveUCI,
          san: null, // TODO: Generate SAN from move if needed
          timestamp: DateTime.now(),
        );

        final updatedMoves = [...game.moves, newMove];
        final newFen = chess.fen;
        final isCheck = chess.in_check;
        final isCheckmate = chess.in_checkmate;
        final isStalemate = chess.in_stalemate;
        final isDraw = chess.in_draw || chess.in_threefold_repetition;

        // CRITICAL: Derive isWhiteTurn from FEN (not toggle) to ensure sync
        // FEN format: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        // The 'w' or 'b' after the board indicates whose turn it is
        final isWhiteTurnFromFen = newFen.split(' ')[1] == 'w';
        
        // Update game
        var updatedGame = game.copyWith(
          fen: newFen,
          moves: updatedMoves,
          isWhiteTurn: isWhiteTurnFromFen, // Derive from FEN, don't toggle
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

        // Update in transaction
        transaction.update(_firestore.collection('chess_games').doc(gameId), updatedGame.toJson());
        
        return updatedGame;
      });
      
      // Update stats if game finished (outside transaction for performance)
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

  /// Delete a chess game (used for cancelling challenges)
  /// Can delete waiting games or active games that are stuck/broken
  /// Delete a game - works for any status (waiting, active, finished)
  /// Handles non-existent games gracefully (returns success if already deleted)
  Future<void> deleteGame(String gameId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw AuthException('User not logged in', code: 'not-authenticated');
      }
      
      // Check if game exists
      final gameDoc = await _firestore.collection('chess_games').doc(gameId).get();
      if (!gameDoc.exists) {
        // Game doesn't exist - might already be deleted, just clean up invite and return
        Logger.info('Game $gameId does not exist (may already be deleted)', tag: 'ChessService');
        try {
          await _firestore.collection('invites').doc(gameId).delete();
        } catch (e) {
          // Invite might not exist either, that's okay
        }
        _inviteTimers[gameId]?.cancel();
        _inviteTimers.remove(gameId);
        return; // Success - game already gone
      }
      
      final game = ChessGame.fromJson(gameDoc.data()!);
      
      // Validate user is a player in the game
      final isWhitePlayer = game.whitePlayerId == currentUser.uid;
      final isBlackPlayer = game.blackPlayerId == currentUser.uid;
      final isInvitedPlayer = game.invitedPlayerId == currentUser.uid;
      
      if (!isWhitePlayer && !isBlackPlayer && !isInvitedPlayer) {
        Logger.warning(
          'User ${currentUser.uid} attempted to delete game ${gameId} but is not a player. '
          'whitePlayerId=${game.whitePlayerId}, blackPlayerId=${game.blackPlayerId}, invitedPlayerId=${game.invitedPlayerId}',
          tag: 'ChessService'
        );
        throw ValidationException('You are not a player in this game');
      }
      
      // Cancel any invite timeout timer
      _inviteTimers[gameId]?.cancel();
      _inviteTimers.remove(gameId);
      
      // Delete the invite document if it exists
      try {
        await _firestore.collection('invites').doc(gameId).delete();
      } catch (e) {
        // Invite might not exist, that's okay
        Logger.debug('No invite document to delete for game $gameId', tag: 'ChessService');
      }
      
      // Delete the game (allow deletion of any status for cleanup)
      try {
        await _firestore.collection('chess_games').doc(gameId).delete();
        Logger.info('Deleted chess game: $gameId', tag: 'ChessService');
      } catch (e) {
        // If permission denied, it might be a phantom game - log details and try to handle gracefully
        if (e.toString().contains('permission-denied')) {
          Logger.warning(
            'Permission denied deleting game $gameId. User: ${currentUser.uid}, '
            'whitePlayerId: ${game.whitePlayerId}, blackPlayerId: ${game.blackPlayerId}, '
            'invitedPlayerId: ${game.invitedPlayerId}, status: ${game.status}',
            tag: 'ChessService'
          );
          // Try to delete invite anyway (might have permission for that)
          try {
            await _firestore.collection('invites').doc(gameId).delete();
          } catch (_) {}
          // Remove from UI by returning (don't throw - let UI update)
          return;
        }
        rethrow;
      }
    } catch (e, st) {
      Logger.error('Error deleting chess game', error: e, stackTrace: st, tag: 'ChessService');
      rethrow;
    }
  }

  /// Delete ALL chess games and invites from Firestore
  /// WARNING: This is a destructive operation - use with caution
  /// Returns count of deleted items even if some errors occur
  Future<Map<String, int>> deleteAllChessGames() async {
    int gamesDeleted = 0;
    int invitesDeleted = 0;
    int errors = 0;

    try {
      // Cancel all timers
      for (var timer in _inviteTimers.values) {
        timer.cancel();
      }
      _inviteTimers.clear();

      // Step 1: Get all chess game IDs first (needed to filter invites)
      Logger.info('Fetching all chess games to get IDs...', tag: 'ChessService');
      QuerySnapshot gamesSnapshot;
      try {
        gamesSnapshot = await _firestore.collection('chess_games').get();
        Logger.info('Found ${gamesSnapshot.docs.length} chess games to delete', tag: 'ChessService');
      } catch (e) {
        Logger.error('Error fetching games to delete', error: e, tag: 'ChessService');
        throw FirestoreException('Failed to fetch games: ${e.toString()}', code: 'fetch-error');
      }
      
      final chessGameIds = gamesSnapshot.docs.map((doc) => doc.id).toSet();
      Logger.info('Collected ${chessGameIds.length} chess game IDs', tag: 'ChessService');

      // Step 2: Delete all chess games in batches (Firestore limit is 500 per batch)
      Logger.info('Starting deletion of all chess games...', tag: 'ChessService');
      const batchSize = 500;
      
      for (int i = 0; i < gamesSnapshot.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < gamesSnapshot.docs.length) 
            ? i + batchSize 
            : gamesSnapshot.docs.length;
        
        int batchCount = 0;
        for (int j = i; j < end; j++) {
          try {
            batch.delete(gamesSnapshot.docs[j].reference);
            batchCount++;
          } catch (e) {
            errors++;
            Logger.warning('Error adding game ${gamesSnapshot.docs[j].id} to batch: $e', tag: 'ChessService');
          }
        }
        
        if (batchCount > 0) {
          try {
            await batch.commit();
            gamesDeleted += batchCount;
            Logger.info('Deleted batch of $batchCount games (total: $gamesDeleted)', tag: 'ChessService');
          } catch (e) {
            errors += batchCount;
            Logger.error('Error committing batch delete for games', error: e, tag: 'ChessService');
            // Continue with next batch
          }
        }
      }

      // Step 3: Delete chess-related invites (where roomId matches a chess game ID)
      Logger.info('Starting deletion of chess-related invites...', tag: 'ChessService');
      QuerySnapshot? invitesSnapshot;
      try {
        invitesSnapshot = await _firestore.collection('invites').get();
        Logger.info('Found ${invitesSnapshot.docs.length} total invites to check', tag: 'ChessService');
      } catch (e) {
        Logger.error('Error fetching invites to delete', error: e, tag: 'ChessService');
        invitesSnapshot = null;
      }
      
      if (invitesSnapshot != null && chessGameIds.isNotEmpty) {
        final chessInvites = invitesSnapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          final roomId = data?['roomId'] as String?;
          return roomId != null && chessGameIds.contains(roomId);
        }).toList();
        
        Logger.info('Found ${chessInvites.length} chess-related invites to delete', tag: 'ChessService');
        
        for (int i = 0; i < chessInvites.length; i += batchSize) {
          final batch = _firestore.batch();
          final end = (i + batchSize < chessInvites.length) 
              ? i + batchSize 
              : chessInvites.length;
          
          int batchCount = 0;
          for (int j = i; j < end; j++) {
            try {
              batch.delete(chessInvites[j].reference);
              batchCount++;
            } catch (e) {
              errors++;
              Logger.warning('Error adding invite ${chessInvites[j].id} to batch: $e', tag: 'ChessService');
            }
          }
          
          if (batchCount > 0) {
            try {
              await batch.commit();
              invitesDeleted += batchCount;
              Logger.info('Deleted batch of $batchCount invites (total: $invitesDeleted)', tag: 'ChessService');
            } catch (e) {
              errors += batchCount;
              Logger.error('Error committing batch delete for invites', error: e, tag: 'ChessService');
              // Continue with next batch
            }
          }
        }
      }

      Logger.info('✅ Deletion complete: $gamesDeleted games, $invitesDeleted invites, $errors errors', tag: 'ChessService');
      
      return {
        'gamesDeleted': gamesDeleted,
        'invitesDeleted': invitesDeleted,
        'errors': errors,
      };
    } catch (e, st) {
      Logger.error('❌ Error deleting all chess games', error: e, stackTrace: st, tag: 'ChessService');
      rethrow;
    }
  }

  /// Stream waiting family games for real-time updates
  /// SIMPLIFIED: Single source of truth - only query chess_games collection
  /// The invitedPlayerId field in chess_games is the source of truth for invites
  Stream<List<ChessGame>> streamWaitingFamilyGames(String familyId) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    // SINGLE QUERY - no merging needed, no duplicates possible
    return _firestore
        .collection('chess_games')
        .where('mode', isEqualTo: 'family')
        .where('familyId', isEqualTo: familyId)
        .where('status', whereIn: [GameStatus.waiting.name, GameStatus.active.name])
        .snapshots()
        .asyncMap((snapshot) async {
      // Use Map to ensure strict deduplication by game ID AND by player combination
      final gamesMap = <String, ChessGame>{}; // By game ID
      final gamesByPlayers = <String, ChessGame>{}; // By player combination (prevents duplicate challenges)
      
      for (var doc in snapshot.docs) {
        try {
          // Skip if we've already processed this game ID (prevent duplicates)
          if (gamesMap.containsKey(doc.id)) {
            Logger.warning('Duplicate game ID detected in stream: ${doc.id} - skipping', tag: 'ChessService');
            continue;
          }
          
          // Verify document still exists (might have been deleted)
          if (!doc.exists) {
            Logger.warning('Game document ${doc.id} does not exist', tag: 'ChessService');
            continue;
          }
          
          final game = ChessGame.fromJson(doc.data());
          
          // STRICT VALIDATION: Only include games where user is DEFINITELY involved
          final isChallenger = game.whitePlayerId == currentUserId;
          final isInvited = game.invitedPlayerId == currentUserId;
          final isBlackPlayer = game.blackPlayerId == currentUserId;
          
          // CRITICAL: If user is not in any of these roles, skip the game
          if (!isChallenger && !isInvited && !isBlackPlayer) {
            Logger.warning(
              'Skipping game ${game.id} - user $currentUserId not involved. '
              'whitePlayerId=${game.whitePlayerId}, blackPlayerId=${game.blackPlayerId}, invitedPlayerId=${game.invitedPlayerId}',
              tag: 'ChessService'
            );
            continue;
          }
          
          // Additional validation: ensure game state is consistent
          if (game.status == GameStatus.waiting) {
            // Waiting game: user must be challenger OR invited (not black player)
            if (isBlackPlayer) {
              Logger.warning('Skipping waiting game ${game.id} - user is blackPlayer but game is waiting (invalid state)', tag: 'ChessService');
              continue;
            }
            // If user is challenger, there should be an invitedPlayerId
            if (isChallenger && game.invitedPlayerId == null && game.blackPlayerId == null) {
              Logger.warning('Skipping invalid waiting game ${game.id} - challenger but no invitedPlayerId or blackPlayerId', tag: 'ChessService');
              continue;
            }
            // If user is invited, verify they're actually invited
            if (isInvited && game.invitedPlayerId != currentUserId) {
              Logger.warning('Skipping invalid waiting game ${game.id} - invitedPlayerId mismatch', tag: 'ChessService');
              continue;
            }
            
            // CRITICAL DEDUPLICATION: For waiting games, only keep the most recent game between the same players
            // Create a unique key for this player combination
            final playerKey = game.invitedPlayerId != null
                ? '${game.whitePlayerId}_${game.invitedPlayerId}'
                : '${game.whitePlayerId}_${game.blackPlayerId ?? 'null'}';
            
            if (gamesByPlayers.containsKey(playerKey)) {
              final existingGame = gamesByPlayers[playerKey]!;
              // Keep the most recent game (by createdAt or id comparison)
              final existingCreatedAt = existingGame.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final currentCreatedAt = game.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              
              if (currentCreatedAt.isAfter(existingCreatedAt) || 
                  (currentCreatedAt == existingCreatedAt && game.id.compareTo(existingGame.id) > 0)) {
                // Current game is newer - remove old one and add this one
                Logger.warning(
                  'Found duplicate challenge between ${game.whitePlayerId} and ${game.invitedPlayerId ?? game.blackPlayerId}. '
                  'Removing older game ${existingGame.id}, keeping ${game.id}',
                  tag: 'ChessService'
                );
                gamesMap.remove(existingGame.id);
                gamesByPlayers[playerKey] = game;
                gamesMap[game.id] = game;
              } else {
                // Existing game is newer - skip this one
                Logger.warning(
                  'Found duplicate challenge between ${game.whitePlayerId} and ${game.invitedPlayerId ?? game.blackPlayerId}. '
                  'Keeping older game ${existingGame.id}, skipping ${game.id}',
                  tag: 'ChessService'
                );
                continue;
              }
            } else {
              // First game with this player combination
              gamesByPlayers[playerKey] = game;
              gamesMap[game.id] = game;
            }
          } else if (game.status == GameStatus.active) {
            // Active game: must have blackPlayerId set
            if (game.blackPlayerId == null) {
              Logger.warning('Skipping invalid active game ${game.id} - no blackPlayerId', tag: 'ChessService');
              continue;
            }
            // User must be either white or black player (not just invited)
            if (!isChallenger && !isBlackPlayer) {
              Logger.warning('Skipping active game ${game.id} - user not white or black player', tag: 'ChessService');
              continue;
            }
            // Active games shouldn't have invitedPlayerId set
            if (game.invitedPlayerId != null && game.invitedPlayerId == currentUserId && !isBlackPlayer) {
              Logger.warning('Skipping active game ${game.id} - has invitedPlayerId but user is not blackPlayer (corrupted state)', tag: 'ChessService');
              continue;
            }
            
            // For active games, also deduplicate by player combination
            final playerKey = '${game.whitePlayerId}_${game.blackPlayerId}';
            if (gamesByPlayers.containsKey(playerKey)) {
              final existingGame = gamesByPlayers[playerKey]!;
              // Keep the most recent active game
              final existingStartedAt = existingGame.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final currentStartedAt = game.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              
              if (currentStartedAt.isAfter(existingStartedAt) || 
                  (currentStartedAt == existingStartedAt && game.id.compareTo(existingGame.id) > 0)) {
                Logger.warning(
                  'Found duplicate active game between ${game.whitePlayerId} and ${game.blackPlayerId}. '
                  'Removing older game ${existingGame.id}, keeping ${game.id}',
                  tag: 'ChessService'
                );
                gamesMap.remove(existingGame.id);
                gamesByPlayers[playerKey] = game;
                gamesMap[game.id] = game;
              } else {
                Logger.warning(
                  'Found duplicate active game between ${game.whitePlayerId} and ${game.blackPlayerId}. '
                  'Keeping older game ${existingGame.id}, skipping ${game.id}',
                  tag: 'ChessService'
                );
                continue;
              }
            } else {
              gamesByPlayers[playerKey] = game;
              gamesMap[game.id] = game;
            }
          }
        } catch (e) {
          Logger.warning('Error parsing game ${doc.id}', error: e, tag: 'ChessService');
        }
      }
      
      final gamesList = gamesMap.values.toList();
      Logger.info('Stream returning ${gamesList.length} unique games for user $currentUserId (checked ${snapshot.docs.length} documents, deduplicated by player combinations)', tag: 'ChessService');
      return gamesList;
    });
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

