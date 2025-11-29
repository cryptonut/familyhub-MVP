import 'package:flutter/material.dart';
import 'dart:async';
import 'package:chess/chess.dart' as chess_lib;
import '../../../core/services/logger_service.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/ui_components.dart';
import '../../../utils/app_theme.dart';
import '../models/chess_game.dart';
import '../services/chess_service.dart';
import '../services/chess_ai_service.dart';
import '../widgets/chess_board_widget.dart';

/// Solo game screen (vs AI)
class ChessSoloGameScreen extends StatefulWidget {
  final AIDifficulty? difficulty;
  final int? timeLimitMs;

  const ChessSoloGameScreen({
    super.key,
    this.difficulty,
    this.timeLimitMs,
  });

  @override
  State<ChessSoloGameScreen> createState() => _ChessSoloGameScreenState();
}

class _ChessSoloGameScreenState extends State<ChessSoloGameScreen> {
  final ChessService _chessService = ChessService();
  final ChessAIService _aiService = ChessAIService();
  final AuthService _authService = AuthService();
  
  ChessGame? _game;
  chess_lib.Chess? _chessEngine;
  bool _isLoading = true;
  bool _isMakingMove = false;
  AIDifficulty _difficulty = AIDifficulty.medium;
  Timer? _timer;
  int _whiteTimeRemaining = 600000;
  int _blackTimeRemaining = 600000;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.difficulty ?? AIDifficulty.medium;
    _whiteTimeRemaining = widget.timeLimitMs ?? 600000;
    _blackTimeRemaining = widget.timeLimitMs ?? 600000;
    _startNewGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startNewGame() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user == null) {
        Navigator.pop(context);
        return;
      }

      final userModel = await _authService.getCurrentUserModel();
      final game = await _chessService.createSoloGame(
        userId: user.uid,
        userName: userModel?.displayName ?? 'Player',
        difficulty: _difficulty,
        timeLimitMs: widget.timeLimitMs ?? 600000,
      );

      _chessEngine = chess_lib.Chess();
      _chessEngine!.load(game.fen);

      setState(() {
        _game = game;
        _isLoading = false;
      });

      _startTimer();
    } catch (e) {
      Logger.error('Error starting solo game', error: e, tag: 'ChessSoloGameScreen');
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
    // Game ends - AI wins if player times out
    // In solo mode, player is always white
    if (mounted) {
      _showGameOverDialog('Time\'s up! You lost on time.');
    }
  }

  Future<void> _makeMove(String moveUCI) async {
    if (_isMakingMove || _game == null || _chessEngine == null) return;
    if (_game!.status != GameStatus.active) return;
    if (!_game!.isWhiteTurn) return; // AI's turn

    setState(() => _isMakingMove = true);

    try {
      // Validate move
      final move = _chessEngine!.move(moveUCI);
      if (move == null) {
        throw Exception('Invalid move');
      }

      // Update local state
      _chessEngine!.load(_chessEngine!.fen);
      setState(() {
        _game = _game!.copyWith(
          fen: _chessEngine!.fen,
          isWhiteTurn: false,
          lastMove: moveUCI,
        );
      });

      // Check for game end
      if (_chessEngine!.in_checkmate) {
        _showGameOverDialog('Checkmate! You won!');
        return;
      }
      if (_chessEngine!.in_stalemate || _chessEngine!.in_draw) {
        _showGameOverDialog('Draw!');
        return;
      }

      // AI's turn
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay for UX
      await _makeAIMove();
    } catch (e) {
      Logger.error('Error making move', error: e, tag: 'ChessSoloGameScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid move: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isMakingMove = false);
    }
  }

  Future<void> _makeAIMove() async {
    if (_chessEngine == null || _game == null) return;

    try {
      final aiMove = await _aiService.getBestMove(
        game: _chessEngine!,
        difficulty: _difficulty,
      );

      // Make AI move
      final moveResult = _chessEngine!.move(aiMove.uci);
      if (moveResult == null) {
        throw Exception('AI move failed');
      }

      setState(() {
        _game = _game!.copyWith(
          fen: _chessEngine!.fen,
          isWhiteTurn: true,
          lastMove: aiMove.uci,
        );
      });

      // Check for game end
      if (_chessEngine!.in_checkmate) {
        _showGameOverDialog('Checkmate! AI won!');
      } else if (_chessEngine!.in_stalemate || _chessEngine!.in_draw) {
        _showGameOverDialog('Draw!');
      }
    } catch (e) {
      Logger.error('Error making AI move', error: e, tag: 'ChessSoloGameScreen');
    }
  }

  void _showGameOverDialog(String message) {
    _timer?.cancel();
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
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _startNewGame();
            },
            child: const Text('New Game'),
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
            onPressed: () {
              Navigator.pop(context);
              _showGameOverDialog('You resigned. AI wins!');
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
        appBar: AppBar(title: const Text('Chess vs AI')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final lastMove = _game!.lastMove;
    final lastMoveFrom = lastMove != null ? lastMove.substring(0, 2) : null;
    final lastMoveTo = lastMove != null ? lastMove.substring(2, 4) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess vs AI'),
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
                          _game!.whitePlayerName ?? 'You',
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
                          _game!.blackPlayerName ?? 'AI',
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
            
            // Chess board
            ChessBoardWidget(
              game: _chessEngine!,
              onMove: _isMakingMove ? null : _makeMove,
              isWhiteBottom: true,
              isInteractive: _game!.isWhiteTurn && !_isMakingMove,
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

