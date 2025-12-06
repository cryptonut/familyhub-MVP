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
import '../utils/chess_move_validator.dart';

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
  bool _isAIThinking = false;
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
      
      // CRITICAL FIX: Always use the CORRECT starting FEN for new games
      // The chess library seems to have issues, so we'll force the correct FEN
      final correctStartingFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      
      Logger.debug('ChessSoloGameScreen: Loading game. Game FEN: ${game.fen}, Game isWhiteTurn: ${game.isWhiteTurn}', tag: 'ChessSoloGameScreen');
      
      // For new games (no moves yet), always use the correct starting FEN
      if (game.moves.isEmpty) {
        Logger.debug('ChessSoloGameScreen: New game detected, using correct starting FEN', tag: 'ChessSoloGameScreen');
        _chessEngine!.load(correctStartingFen);
      } else {
        // For existing games, use the game's FEN but verify it
        var fenToLoad = game.fen;
        final fenParts = fenToLoad.split(' ');
        if (fenParts.length > 1) {
          final expectedTurnChar = game.isWhiteTurn ? 'w' : 'b';
          if (fenParts[1] != expectedTurnChar) {
            Logger.warning('FEN turn indicator "${fenParts[1]}" does not match. Fixing to "$expectedTurnChar"', tag: 'ChessSoloGameScreen');
            fenParts[1] = expectedTurnChar;
            fenToLoad = fenParts.join(' ');
          }
        }
        _chessEngine!.load(fenToLoad);
      }

      // CRITICAL: Verify the engine state is correct
      final engineTurn = _chessEngine!.turn;
      final expectedTurn = game.isWhiteTurn ? chess_lib.Color.WHITE : chess_lib.Color.BLACK;
      final engineFen = _chessEngine!.fen;
      
      Logger.debug('ChessSoloGameScreen: Engine loaded. FEN: $engineFen, Engine turn: $engineTurn, Expected: $expectedTurn', tag: 'ChessSoloGameScreen');
      
      // If turn is still wrong, force correct FEN
      if (engineTurn != expectedTurn) {
        Logger.error('CRITICAL: Engine turn mismatch! Forcing correct FEN. Engine turn: $engineTurn, Expected: $expectedTurn', tag: 'ChessSoloGameScreen');
        _chessEngine = chess_lib.Chess();
        _chessEngine!.load(correctStartingFen);
        Logger.debug('ChessSoloGameScreen: Reloaded with correct FEN. New turn: ${_chessEngine!.turn}', tag: 'ChessSoloGameScreen');
      }

      // For solo games, ensure status is active and sync turn with chess engine
      setState(() {
        _game = game.copyWith(
          status: GameStatus.active, // Solo games should be active immediately
        );
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
      if (!mounted || _game == null) {
        timer.cancel();
        return;
      }
      
      // For solo games, timer should run when status is active or waiting
      if (_game!.status != GameStatus.active && _game!.status != GameStatus.waiting) {
        timer.cancel();
        return;
      }

      setState(() {
        // Use chess engine turn if available, otherwise use game state
        final isWhiteTurn = _chessEngine?.turn == chess_lib.Color.WHITE ?? _game!.isWhiteTurn;
        
        if (isWhiteTurn) {
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
    Logger.debug('_makeMove: Received move $moveUCI, _isMakingMove=$_isMakingMove, isWhiteTurn=${_game?.isWhiteTurn}', tag: 'ChessSoloGameScreen');
    
    if (_isMakingMove || _game == null || _chessEngine == null) {
      Logger.warning('_makeMove: Cannot make move - _isMakingMove=$_isMakingMove, _game=${_game != null}, _chessEngine=${_chessEngine != null}', tag: 'ChessSoloGameScreen');
      return;
    }
    // For solo games, allow moves when status is active or waiting
    if (_game!.status != GameStatus.active && _game!.status != GameStatus.waiting) {
      Logger.warning('_makeMove: Game not active - status=${_game!.status}', tag: 'ChessSoloGameScreen');
      return;
    }
    
    // Check chess engine turn instead of game state (more reliable)
    final isWhiteTurn = _chessEngine!.turn == chess_lib.Color.WHITE;
    if (!isWhiteTurn) {
      Logger.warning('_makeMove: Not white\'s turn (engine turn: ${_chessEngine!.turn})', tag: 'ChessSoloGameScreen');
      return; // AI's turn
    }

    setState(() => _isMakingMove = true);

    try {
      Logger.debug('_makeMove: Attempting to make move $moveUCI', tag: 'ChessSoloGameScreen');
      final fenBefore = _chessEngine!.fen;
      Logger.debug('_makeMove: FEN before move: $fenBefore', tag: 'ChessSoloGameScreen');
      
      // Use custom validator to execute the move properly
      final newFen = ChessMoveValidator.executeMove(_chessEngine!, moveUCI.substring(0, 2), moveUCI.substring(2, 4));
      if (newFen == null) {
        Logger.error('_makeMove: Invalid move - validator returned null', tag: 'ChessSoloGameScreen');
        throw Exception('Invalid move');
      }
      
      Logger.debug('_makeMove: Move executed successfully. FEN changed from $fenBefore to $newFen', tag: 'ChessSoloGameScreen');

      // Update local state - sync with chess engine turn
      // DO NOT reload the FEN - move() already updated the engine state
      final isWhiteTurn = _chessEngine!.turn == chess_lib.Color.WHITE;
      setState(() {
        _game = _game!.copyWith(
          fen: _chessEngine!.fen,
          isWhiteTurn: isWhiteTurn,
          lastMove: moveUCI,
          status: GameStatus.active, // Ensure status is active
        );
      });
      
      Logger.debug('_makeMove: Updated game state - isWhiteTurn=$isWhiteTurn, fen=${_chessEngine!.fen}', tag: 'ChessSoloGameScreen');

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

    setState(() => _isAIThinking = true);
    
    try {
      final aiMove = await _aiService.getBestMove(
        game: _chessEngine!,
        difficulty: _difficulty,
      );

      final fenBefore = _chessEngine!.fen;
      Logger.debug('_makeAIMove: FEN before AI move: $fenBefore', tag: 'ChessSoloGameScreen');
      
      // Use custom validator to execute the AI move properly
      final from = aiMove.uci.substring(0, 2);
      final to = aiMove.uci.substring(2, 4);
      final newFen = ChessMoveValidator.executeMove(_chessEngine!, from, to);
      if (newFen == null) {
        throw Exception('AI move failed - validator returned null');
      }

      Logger.debug('_makeAIMove: AI move executed. FEN changed from $fenBefore to $newFen', tag: 'ChessSoloGameScreen');

      // Sync game state with chess engine turn
      // DO NOT reload the FEN - move() already updated the engine state
      final isWhiteTurn = _chessEngine!.turn == chess_lib.Color.WHITE;
      setState(() {
        _game = _game!.copyWith(
          fen: _chessEngine!.fen,
          isWhiteTurn: isWhiteTurn,
          lastMove: aiMove.uci,
          status: GameStatus.active, // Ensure status is active
        );
      });
      
      Logger.debug('_makeAIMove: Updated game state - isWhiteTurn=$isWhiteTurn, fen=${_chessEngine!.fen}', tag: 'ChessSoloGameScreen');

      // Check for game end
      if (_chessEngine!.in_checkmate) {
        _showGameOverDialog('Checkmate! AI won!');
      } else if (_chessEngine!.in_stalemate || _chessEngine!.in_draw) {
        _showGameOverDialog('Draw!');
      }
    } catch (e) {
      Logger.error('Error making AI move', error: e, tag: 'ChessSoloGameScreen');
    } finally {
      if (mounted) {
        setState(() => _isAIThinking = false);
      }
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
                    color: _game!.isWhiteTurn ? Colors.blue.shade100 : null,
                    child: Column(
                      children: [
                        Text(
                          _game!.whitePlayerName ?? 'You',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _game!.isWhiteTurn 
                                ? Colors.blue.shade900 
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(_whiteTimeRemaining),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _whiteTimeRemaining < 60000 
                                ? Colors.red.shade700 
                                : (_game!.isWhiteTurn 
                                    ? Colors.blue.shade900 
                                    : Theme.of(context).textTheme.bodyLarge?.color),
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
                    color: !_game!.isWhiteTurn ? Colors.blue.shade100 : null,
                    child: Column(
                      children: [
                        Text(
                          _game!.blackPlayerName ?? 'AI',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: !_game!.isWhiteTurn 
                                ? Colors.blue.shade900 
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(_blackTimeRemaining),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _blackTimeRemaining < 60000 
                                ? Colors.red.shade700 
                                : (!_game!.isWhiteTurn 
                                    ? Colors.blue.shade900 
                                    : Theme.of(context).textTheme.bodyLarge?.color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingMD),
            
            // AI thinking indicator
            if (_isAIThinking)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI is thinking...',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Chess board - use chess engine turn for interactivity
            ChessBoardWidget(
              game: _chessEngine!,
              onMove: (_chessEngine!.turn == chess_lib.Color.WHITE && !_isMakingMove) ? _makeMove : null,
              isWhiteBottom: true,
              isInteractive: _chessEngine!.turn == chess_lib.Color.WHITE && !_isMakingMove,
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

