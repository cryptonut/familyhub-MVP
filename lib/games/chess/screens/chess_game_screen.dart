import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:async' show StreamSubscription, Timer;
import 'package:chess/chess.dart' as chess_lib;
import '../../../core/services/logger_service.dart';
import '../../../services/auth_service.dart';
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
  
  ChessGame? _game;
  chess_lib.Chess? _chessEngine;
  StreamSubscription<ChessGame?>? _gameSubscription;
  bool _isLoading = true;
  bool _isMakingMove = false;
  Timer? _timer;
  int _whiteTimeRemaining = 600000;
  int _blackTimeRemaining = 600000;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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

      // Listen for game updates
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

  @override
  Widget build(BuildContext context) {
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

