import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:async' show StreamSubscription, Timer;
import 'package:chess/chess.dart' as chess_lib;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../../core/services/logger_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/video_call_service.dart';
import '../../../widgets/ui_components.dart';
import '../../../utils/app_theme.dart';
import '../models/chess_game.dart';
import '../services/chess_service.dart';
import '../widgets/chess_board_widget.dart';

/// Multiplayer game screen (family or open)
class ChessGameScreen extends StatefulWidget {
  final String? gameId;
  final GameMode mode;

  const ChessGameScreen({
    super.key,
    this.gameId,
    required this.mode,
  });

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  final ChessService _chessService = ChessService();
  final AuthService _authService = AuthService();
  final VideoCallService? _videoCallService = VideoCallService();
  
  ChessGame? _game;
  chess_lib.Chess? _chessEngine;
  StreamSubscription<ChessGame?>? _gameSubscription;
  bool _isLoading = true;
  bool _isMakingMove = false;
  Timer? _timer;
  int _whiteTimeRemaining = 600000;
  int _blackTimeRemaining = 600000;
  
  // WebSocket connection state
  IO.Socket? _socket;
  bool _isWebSocketConnected = false;
  bool _showConnectionBanner = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  
  // Exponential backoff intervals: 2s, 4s, 8s, 16s, 32s, 60s
  static const List<Duration> _backoffIntervals = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 32),
    Duration(seconds: 60),
  ];
  
  // Agora engine reference (if video call is active)
  RtcEngine? _agoraEngine;

  @override
  void initState() {
    super.initState();
    _initializeAgoraMuting();
    if (widget.gameId != null) {
      _loadGame(widget.gameId!);
    } else if (widget.mode == GameMode.open) {
      _joinMatchmaking();
    }
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    _timer?.cancel();
    _reconnectTimer?.cancel();
    _disconnectWebSocket();
    _unmuteAgora();
    super.dispose();
  }
  
  /// Initialize Agora video muting during chess game
  /// Mutes local video stream to conserve battery
  Future<void> _initializeAgoraMuting() async {
    try {
      if (_videoCallService != null) {
        await _videoCallService!.initialize();
        _agoraEngine = _videoCallService!.engine;
        if (_agoraEngine != null) {
          await _agoraEngine!.muteLocalVideoStream(true);
          Logger.info('Agora video muted for chess game', tag: 'ChessGameScreen');
        }
      }
    } catch (e, st) {
      Logger.warning('Error muting Agora video', error: e, stackTrace: st, tag: 'ChessGameScreen');
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'Agora mute failed');
    }
  }
  
  /// Unmute Agora video when exiting game
  Future<void> _unmuteAgora() async {
    try {
      if (_agoraEngine != null) {
        await _agoraEngine!.muteLocalVideoStream(false);
        Logger.info('Agora video unmuted after chess game', tag: 'ChessGameScreen');
      }
    } catch (e, st) {
      Logger.warning('Error unmuting Agora video', error: e, stackTrace: st, tag: 'ChessGameScreen');
    }
  }
  
  /// Connect to WebSocket for real-time game updates
  /// Implements exponential backoff retry on connection failure
  Future<void> _connectWebSocket(String gameId) async {
    if (_socket != null && _socket!.connected) {
      return; // Already connected
    }
    
    try {
      // WebSocket URL - adjust based on your backend
      final socketUrl = 'wss://your-backend.com/chess'; // TODO: Replace with actual WebSocket URL
      
      _socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });
      
      _socket!.onConnect((_) {
        setState(() {
          _isWebSocketConnected = true;
          _showConnectionBanner = false;
          _reconnectAttempt = 0;
        });
        Logger.info('WebSocket connected for game $gameId', tag: 'ChessGameScreen');
        
        // Join game room
        _socket!.emit('join_game', {'gameId': gameId});
      });
      
      _socket!.onDisconnect((_) {
        setState(() {
          _isWebSocketConnected = false;
          _showConnectionBanner = true;
        });
        Logger.warning('WebSocket disconnected for game $gameId', tag: 'ChessGameScreen');
        _scheduleReconnect(gameId);
      });
      
      _socket!.onError((error) {
        Logger.error('WebSocket error', error: error, tag: 'ChessGameScreen');
        FirebaseCrashlytics.instance.recordError(error, StackTrace.current, reason: 'WebSocket error');
        _scheduleReconnect(gameId);
      });
      
      _socket!.on('game_update', (data) {
        // Handle real-time game updates from WebSocket
        Logger.debug('WebSocket game update: $data', tag: 'ChessGameScreen');
        // Refresh game state from Firestore
        _loadGame(gameId);
      });
      
      _socket!.connect();
    } catch (e, st) {
      Logger.error('Error connecting WebSocket', error: e, stackTrace: st, tag: 'ChessGameScreen');
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'WebSocket connection failed');
      _scheduleReconnect(gameId);
    }
  }
  
  /// Schedule WebSocket reconnection with exponential backoff
  /// Retry intervals: 2s, 4s, 8s, 16s, 32s, 60s
  void _scheduleReconnect(String gameId) {
    _reconnectTimer?.cancel();
    
    if (_reconnectAttempt >= _backoffIntervals.length) {
      // Max retries reached - show manual retry button
      setState(() {
        _showConnectionBanner = true;
      });
      return;
    }
    
    final delay = _backoffIntervals[_reconnectAttempt];
    _reconnectAttempt++;
    
    Logger.info('Scheduling WebSocket reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempt)', tag: 'ChessGameScreen');
    
    _reconnectTimer = Timer(delay, () {
      if (mounted && widget.gameId != null) {
        _connectWebSocket(gameId);
      }
    });
  }
  
  /// Disconnect WebSocket
  void _disconnectWebSocket() {
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isWebSocketConnected = false;
  }
  
  /// Manual retry WebSocket connection
  void _retryWebSocketConnection() {
    if (widget.gameId != null) {
      setState(() {
        _reconnectAttempt = 0;
      });
      _connectWebSocket(widget.gameId!);
    }
  }

  Future<void> _joinMatchmaking() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user == null) {
        Navigator.pop(context);
        return;
      }

      final userModel = await _authService.getCurrentUserModel();
      await _chessService.joinMatchmakingQueue(
        userId: user.uid,
        userName: userModel?.displayName ?? 'Player',
        familyId: userModel?.familyId,
      );

      // Wait for match
      _waitForMatch();
    } catch (e) {
      Logger.error('Error joining matchmaking', error: e, tag: 'ChessGameScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _waitForMatch() {
    // Poll for new game
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final user = _authService.currentUser;
      if (user == null) {
        timer.cancel();
        return;
      }

      final activeGames = await _chessService.getActiveGames(user.uid);
      if (activeGames.isNotEmpty) {
        timer.cancel();
        _loadGame(activeGames.first.id);
      }
    });
  }

  Future<void> _loadGame(String gameId) async {
    setState(() => _isLoading = true);
    try {
      final game = await _chessService.getGame(gameId);
      if (game == null) {
        throw Exception('Game not found');
      }

      _chessEngine = chess_lib.Chess();
      _chessEngine!.load(game.fen);

      setState(() {
        _game = game;
        _whiteTimeRemaining = game.whiteTimeRemaining;
        _blackTimeRemaining = game.blackTimeRemaining;
        _isLoading = false;
      });

      // Connect WebSocket for real-time updates
      _connectWebSocket(gameId);
      
      // Listen for game updates (Firestore fallback)
      _gameSubscription?.cancel();
      _gameSubscription = _chessService.streamGame(gameId).listen((updatedGame) {
        if (updatedGame != null && mounted) {
          setState(() {
            _game = updatedGame;
            _whiteTimeRemaining = updatedGame.whiteTimeRemaining;
            _blackTimeRemaining = updatedGame.blackTimeRemaining;
            
            if (_chessEngine != null) {
              _chessEngine!.load(updatedGame.fen);
            }
          });

          // Check for game end
          if (updatedGame.status == GameStatus.finished) {
            _showGameOverDialog(updatedGame);
          }
        }
      });

      if (game.status == GameStatus.active) {
        _startTimer();
      }
    } catch (e) {
      Logger.error('Error loading game', error: e, tag: 'ChessGameScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _game == null || _game!.status != GameStatus.active) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_game!.isWhiteTurn) {
          _whiteTimeRemaining = (_whiteTimeRemaining - 1000).clamp(0, double.infinity).toInt();
          if (_whiteTimeRemaining <= 0) {
            _handleTimeout(true);
          }
        } else {
          _blackTimeRemaining = (_blackTimeRemaining - 1000).clamp(0, double.infinity).toInt();
          if (_blackTimeRemaining <= 0) {
            _handleTimeout(false);
          }
        }
      });
    });
  }

  void _handleTimeout(bool isWhite) {
    // Resign on timeout
    final user = _authService.currentUser;
    if (user != null && _game != null) {
      _chessService.resignGame(_game!.id, user.uid);
    }
  }

  Future<void> _makeMove(String moveUCI) async {
    if (_isMakingMove || _game == null || _chessEngine == null) return;
    if (_game!.status != GameStatus.active) return;

    final user = _authService.currentUser;
    if (user == null) return;
    if (!_game!.isMyTurn(user.uid)) return;

    setState(() => _isMakingMove = true);

    try {
      // Validate move locally first
      final move = _chessEngine!.move(moveUCI);
      if (move == null) {
        throw Exception('Invalid move');
      }

      // Make move via service
      final updatedGame = await _chessService.makeMove(
        gameId: _game!.id,
        moveUCI: moveUCI,
        userId: user.uid,
      );

      setState(() {
        _game = updatedGame;
        _chessEngine!.load(updatedGame.fen);
      });

      // Check for game end
      if (updatedGame.status == GameStatus.finished) {
        _showGameOverDialog(updatedGame);
      }
    } catch (e) {
      Logger.error('Error making move', error: e, tag: 'ChessGameScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid move: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isMakingMove = false);
    }
  }

  void _showGameOverDialog(ChessGame game) {
    _timer?.cancel();
    
    String message = 'Game Over';
    if (game.result == GameResult.whiteWin) {
      message = game.winnerId == _authService.currentUser?.uid
          ? 'You won!'
          : 'White won!';
    } else if (game.result == GameResult.blackWin) {
      message = game.winnerId == _authService.currentUser?.uid
          ? 'You won!'
          : 'Black won!';
    } else {
      message = 'Draw!';
    }

    if (game.resultReason != null) {
      message += ' (${game.resultReason})';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close game screen
            },
            child: const Text('Back to Lobby'),
          ),
        ],
      ),
    );
  }

  void _resign() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign?'),
        content: const Text('Are you sure you want to resign?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final user = _authService.currentUser;
              if (user != null && _game != null) {
                try {
                  await _chessService.resignGame(_game!.id, user.uid);
                } catch (e) {
                  Logger.error('Error resigning', error: e, tag: 'ChessGameScreen');
                }
              }
            },
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Build connection lost banner with retry button
  Widget _buildConnectionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.orange.shade700,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Connection lost, rejoining...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: _retryWebSocketConnection,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMainContent(context),
          // Connection lost banner
          if (_showConnectionBanner)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildConnectionBanner(),
            ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent(BuildContext context) {
    if (_isLoading || _game == null || _chessEngine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chess')),
        body: Center(
          child: widget.mode == GameMode.open && _game == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Waiting for opponent...'),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final user = _authService.currentUser;
    if (user == null) {
      Navigator.pop(context);
      return const SizedBox.shrink();
    }

    // Handle waiting status - show waiting for opponent message
    if (_game!.status == GameStatus.waiting) {
      final isCreator = _game!.whitePlayerId == user.uid;
      final opponentName = isCreator 
          ? (_game!.blackPlayerName ?? 'Opponent')
          : (_game!.whitePlayerName ?? 'Opponent');
      
      return Scaffold(
        appBar: AppBar(title: const Text('Chess')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                isCreator 
                    ? 'Waiting for $opponentName to join...'
                    : 'Game created by $opponentName\nTap to join',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (!isCreator) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final userModel = await _authService.getCurrentUserModel();
                      await _chessService.joinFamilyGame(
                        gameId: _game!.id,
                        blackPlayerId: user.uid,
                        blackPlayerName: userModel?.displayName ?? 'Player',
                      );
                      // Game will update via stream, no need to reload
                    } catch (e) {
                      Logger.error('Error joining game', error: e, tag: 'ChessGameScreen');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error joining: ${e.toString()}')),
                        );
                      }
                    }
                  },
                  child: const Text('Join Game'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final isWhite = _game!.isPlayerWhite(user.uid) ?? true;
    final isMyTurn = _game!.isMyTurn(user.uid);
    final lastMove = _game!.lastMove;
    final lastMoveFrom = lastMove != null ? lastMove.substring(0, 2) : null;
    final lastMoveTo = lastMove != null ? lastMove.substring(2, 4) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: _resign,
            tooltip: 'Resign',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          children: [
            // Player info and timer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ModernCard(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    color: _game!.isWhiteTurn ? Colors.blue.shade50 : null,
                    child: Column(
                      children: [
                        Text(
                          _game!.whitePlayerName ?? 'White',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatTime(_whiteTimeRemaining),
                          style: TextStyle(
                            fontSize: 18,
                            color: _whiteTimeRemaining < 60000 ? Colors.red : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ModernCard(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    color: !_game!.isWhiteTurn ? Colors.blue.shade50 : null,
                    child: Column(
                      children: [
                        Text(
                          _game!.blackPlayerName ?? 'Black',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatTime(_blackTimeRemaining),
                          style: TextStyle(
                            fontSize: 18,
                            color: _blackTimeRemaining < 60000 ? Colors.red : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingMD),
            
            // Turn indicator
            if (!isMyTurn && !_isMakingMove)
              ModernCard(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                color: Colors.orange.shade50,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Waiting for opponent...'),
                  ],
                ),
              ),
            
            const SizedBox(height: AppTheme.spacingMD),
            
            // Chess board
            ChessBoardWidget(
              game: _chessEngine!,
              onMove: _isMakingMove || !isMyTurn ? null : _makeMove,
              isWhiteBottom: isWhite,
              isInteractive: isMyTurn && !_isMakingMove,
              lastMoveFrom: lastMoveFrom,
              lastMoveTo: lastMoveTo,
            ),
            
            const SizedBox(height: AppTheme.spacingMD),
            
            // Move history
            if (_game!.moves.isNotEmpty) ...[
              const Text(
                'Move History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              ModernCard(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                child: SizedBox(
                  height: 150,
                  child: ListView.builder(
                    itemCount: _game!.moves.length,
                    itemBuilder: (context, index) {
                      final move = _game!.moves[index];
                      return ListTile(
                        dense: true,
                        title: Text('${index + 1}. ${move.san ?? move.uci}'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

