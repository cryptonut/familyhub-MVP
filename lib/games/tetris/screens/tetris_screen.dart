import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import '../../../core/services/logger_service.dart';
import '../../../services/games_service.dart';
import '../../../services/auth_service.dart';
import '../../../screens/games/leaderboard_screen.dart';

/// Simplified Tetris Game Screen
class TetrisScreen extends StatefulWidget {
  const TetrisScreen({super.key});

  @override
  State<TetrisScreen> createState() => _TetrisScreenState();
}

class _TetrisScreenState extends State<TetrisScreen> {
  static const int rows = 20;
  static const int cols = 10;
  static const Duration _gameSpeed = Duration(milliseconds: 500);
  
  List<List<int>> _board = []; // 0 = empty, 1-7 = piece types
  List<List<int>>? _currentPiece;
  int _currentPieceType = 0; // 1-7 for different piece types
  int _currentRow = 0;
  int _currentCol = 0;
  int _score = 0;
  int _lines = 0;
  bool _gameOver = false;
  bool _isPaused = false;
  bool _showInstructions = false;
  bool _hasSeenInstructions = false;
  Timer? _gameTimer;
  List<Map<String, dynamic>> _highScores = [];
  static const String _highScoresKey = 'tetris_high_scores';
  static const String _hasSeenInstructionsKey = 'tetris_has_seen_instructions';
  
  final GamesService _gamesService = GamesService();
  final AuthService _authService = AuthService();
  
  // Next piece
  List<List<int>>? _nextPiece;
  int _nextPieceType = 0;
  
  // Touch control state
  DateTime? _lastTapTime;
  DateTime? _pressStartTime;
  static const Duration _tapDebounce = Duration(milliseconds: 100);
  static const Duration _pressThreshold = Duration(milliseconds: 200); // Minimum time for sustained press
  Offset? _panStartPosition;
  static const double _swipeThreshold = 30.0; // Minimum distance for swipe

  final List<List<List<int>>> _pieces = [
    // I-piece (cyan)
    [[1, 1, 1, 1]],
    // O-piece (yellow)
    [[1, 1], [1, 1]],
    // T-piece (purple)
    [[0, 1, 0], [1, 1, 1]],
    // S-piece (green)
    [[0, 1, 1], [1, 1, 0]],
    // Z-piece (red)
    [[1, 1, 0], [0, 1, 1]],
    // J-piece (blue)
    [[1, 0, 0], [1, 1, 1]],
    // L-piece (orange)
    [[0, 0, 1], [1, 1, 1]],
  ];
  
  // Colors for each piece type (1-7)
  final List<Color> _pieceColors = [
    Colors.cyan,      // I-piece
    Colors.yellow,    // O-piece
    Colors.purple,    // T-piece
    Colors.green,     // S-piece
    Colors.red,       // Z-piece
    Colors.blue,      // J-piece
    Colors.orange,    // L-piece
  ];

  @override
  void initState() {
    super.initState();
    _loadHighScores();
    _checkFirstTimePlayer();
  }
  
  Future<void> _checkFirstTimePlayer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenInstructions = prefs.getBool(_hasSeenInstructionsKey) ?? false;
      
      if (!_hasSeenInstructions) {
        // Show instructions overlay before starting the game
        setState(() {
          _showInstructions = true;
        });
      } else {
        // Start the game immediately if user has seen instructions
        _initGame();
      }
    } catch (e) {
      Logger.warning('Error checking first-time player status', error: e, tag: 'TetrisScreen');
      // If there's an error, show instructions anyway
      setState(() {
        _showInstructions = true;
      });
    }
  }
  
  Future<void> _dismissInstructions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasSeenInstructionsKey, true);
      _hasSeenInstructions = true;
      setState(() {
        _showInstructions = false;
      });
      // Start the game after dismissing instructions
      _initGame();
    } catch (e) {
      Logger.warning('Error saving instructions status', error: e, tag: 'TetrisScreen');
      setState(() {
        _showInstructions = false;
      });
      _initGame();
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHighScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getStringList(_highScoresKey) ?? [];
      _highScores = scoresJson.map((json) {
        final parts = json.split('|');
        return {
          'score': int.parse(parts[0]),
          'lines': int.parse(parts[1]),
          'date': parts.length > 2 ? parts[2] : '',
        };
      }).toList();
      _highScores.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      if (mounted) setState(() {});
    } catch (e) {
      Logger.warning('Error loading high scores', error: e, tag: 'TetrisScreen');
    }
  }

  Future<void> _saveHighScore(int score, int lines) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';
      final scoreEntry = '$score|$lines|$dateStr';
      
      final scoresJson = prefs.getStringList(_highScoresKey) ?? [];
      scoresJson.add(scoreEntry);
      
      // Keep only top 10 scores
      final allScores = scoresJson.map((json) {
        final parts = json.split('|');
        return {
          'score': int.parse(parts[0]),
          'lines': int.parse(parts[1]),
          'date': parts.length > 2 ? parts[2] : '',
        };
      }).toList();
      allScores.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      final top10 = allScores.take(10).map((s) => '${s['score']}|${s['lines']}|${s['date']}').toList();
      
      await prefs.setStringList(_highScoresKey, top10);
      await _loadHighScores();
    } catch (e) {
      Logger.warning('Error saving high score', error: e, tag: 'TetrisScreen');
    }
  }

  void _initGame() {
    // Don't start the game if instructions are showing
    if (_showInstructions) return;
    
    _board = List.generate(rows, (_) => List.filled(cols, 0));
    _score = 0;
    _lines = 0;
    _gameOver = false;
    _isPaused = false;
    _spawnPiece();
    _startGame();
    setState(() {});
  }
  
  void _restartGame() {
    _initGame();
  }

  Future<void> _handleGameOver() async {
    if (!mounted) return;
    
    // Save score to Firestore leaderboard (always save, GamesService will check if it's a high score)
    final user = _authService.currentUser;
    if (user != null) {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel?.familyId != null) {
        try {
          await _gamesService.updateTetrisHighScore(
            user.uid,
            userModel!.familyId!,
            _score,
            _lines,
          );
        } catch (e) {
          Logger.error('Error saving Tetris score to leaderboard', error: e, tag: 'TetrisScreen');
        }
      }
    }
    
    // Save score locally if it's a high score
    bool isHighScore = false;
    if (_highScores.isEmpty) {
      // No scores yet, save this one
      isHighScore = true;
      await _saveHighScore(_score, _lines);
    } else if (_highScores.length < 10) {
      // Less than 10 scores, save this one
      isHighScore = true;
      await _saveHighScore(_score, _lines);
    } else {
      // Check if score beats the lowest high score
      final lowestHighScore = _highScores.last['score'] as int;
      if (_score > lowestHighScore) {
        isHighScore = true;
        await _saveHighScore(_score, _lines);
      }
    }
    
    if (!mounted) return;
    
    // Show game over dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Final Score: $_score'),
            Text('Lines Cleared: $_lines'),
            if (isHighScore) ...[
              const SizedBox(height: 8),
              Text(
                '🎉 New High Score!',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close game over dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeaderboardScreen(),
                ),
              );
            },
            child: const Text('View Leaderboard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initGame();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  void _showLeaderboard() {
    // Navigate to the proper leaderboard screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LeaderboardScreen(),
      ),
    );
  }

  void _startGame() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(_gameSpeed, (_) {
      if (!_isPaused && !_gameOver) {
        _moveDown();
      }
    });
  }

  void _spawnPiece() {
    final random = Random();
    
    // If we have a next piece, use it; otherwise generate a new one
    if (_nextPiece != null) {
      _currentPiece = _nextPiece;
      _currentPieceType = _nextPieceType;
    } else {
      final pieceIndex = random.nextInt(_pieces.length);
      _currentPiece = _pieces[pieceIndex].map((row) => List<int>.from(row)).toList();
      _currentPieceType = pieceIndex + 1; // 1-7
    }
    
    _currentRow = 0;
    _currentCol = (cols - _currentPiece![0].length) ~/ 2;
    
    // Generate next piece
    final nextPieceIndex = random.nextInt(_pieces.length);
    _nextPiece = _pieces[nextPieceIndex].map((row) => List<int>.from(row)).toList();
    _nextPieceType = nextPieceIndex + 1;
    
    if (_checkCollision(_currentRow, _currentCol, _currentPiece!)) {
      _gameOver = true;
      _gameTimer?.cancel();
      _handleGameOver();
    }
  }

  bool _checkCollision(int row, int col, List<List<int>> piece) {
    for (int i = 0; i < piece.length; i++) {
      for (int j = 0; j < piece[i].length; j++) {
        if (piece[i][j] == 1) {
          final newRow = row + i;
          final newCol = col + j;
          
          if (newRow >= rows || newCol < 0 || newCol >= cols) {
            return true;
          }
          
          if (newRow >= 0 && _board[newRow][newCol] > 0) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _placePiece() {
    for (int i = 0; i < _currentPiece!.length; i++) {
      for (int j = 0; j < _currentPiece![i].length; j++) {
        if (_currentPiece![i][j] == 1) {
          final row = _currentRow + i;
          final col = _currentCol + j;
          if (row >= 0) {
            _board[row][col] = _currentPieceType; // Store piece type instead of just 1
          }
        }
      }
    }
    _clearLines();
    _spawnPiece();
  }

  void _clearLines() {
    int linesCleared = 0;
    for (int i = rows - 1; i >= 0; i--) {
      if (_board[i].every((cell) => cell > 0)) {
        _board.removeAt(i);
        _board.insert(0, List.filled(cols, 0));
        linesCleared++;
        i++; // Check same row again
      }
    }
    
    if (linesCleared > 0) {
      _lines += linesCleared;
      _score += linesCleared * 100 * linesCleared; // Bonus for multiple lines
    }
  }

  void _moveDown() {
    if (_checkCollision(_currentRow + 1, _currentCol, _currentPiece!)) {
      _placePiece();
    } else {
      setState(() {
        _currentRow++;
      });
    }
  }

  void _moveLeft() {
    if (_gameOver || _isPaused || _currentPiece == null) return;
    if (!_checkCollision(_currentRow, _currentCol - 1, _currentPiece!)) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentCol--;
      });
    }
  }

  void _moveRight() {
    if (_gameOver || _isPaused || _currentPiece == null) return;
    if (!_checkCollision(_currentRow, _currentCol + 1, _currentPiece!)) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentCol++;
      });
    }
  }

  void _rotate() {
    if (_currentPiece == null || _gameOver || _isPaused) return;
    
    final rotated = List.generate(
      _currentPiece![0].length,
      (i) => List.generate(
        _currentPiece!.length,
        (j) => _currentPiece![_currentPiece!.length - 1 - j][i],
      ),
    );
    
    if (!_checkCollision(_currentRow, _currentCol, rotated)) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentPiece = rotated;
      });
    }
  }
  
  void _hardDrop() {
    if (_currentPiece == null || _gameOver || _isPaused) return;
    
    // Move piece down until collision
    int dropDistance = 0;
    while (!_checkCollision(_currentRow + dropDistance + 1, _currentCol, _currentPiece!)) {
      dropDistance++;
    }
    
    if (dropDistance > 0) {
      HapticFeedback.mediumImpact();
      setState(() {
        _currentRow += dropDistance;
        _score += dropDistance * 2; // Bonus points for hard drop
      });
      _placePiece();
    }
  }
  
  void _handleTapDown(Offset localPosition, Size boardSize) {
    if (_gameOver || _isPaused || _currentPiece == null) return;
    
    // Record press start time for sustained press detection
    _pressStartTime = DateTime.now();
  }
  
  void _handleTapUp(Offset localPosition, Size boardSize) {
    if (_gameOver || _isPaused || _currentPiece == null || _pressStartTime == null) return;
    
    final now = DateTime.now();
    final pressDuration = now.difference(_pressStartTime!);
    _pressStartTime = null;
    
    // Debounce rapid taps
    if (_lastTapTime != null && now.difference(_lastTapTime!) < _tapDebounce) {
      return;
    }
    _lastTapTime = now;
    
    // If this was a quick tap (less than press threshold), rotate
    if (pressDuration < _pressThreshold) {
      _rotate();
      return;
    }
    
    // For sustained press, determine direction based on position
    // Calculate cell dimensions (accounting for border)
    final cellWidth = boardSize.width / (cols + 2);
    final cellHeight = boardSize.height / (rows + 2);
    
    // Convert tap position to board coordinates (accounting for border)
    final tapX = localPosition.dx;
    final tapY = localPosition.dy;
    
    // Check if tap is in border area (ignore border taps)
    final col = (tapX / cellWidth).floor();
    final row = (tapY / cellHeight).floor();
    
    if (row == 0 || row == rows + 1 || col == 0 || col == cols + 1) {
      return; // Ignore border taps
    }
    
    // Convert to board coordinates (remove border offset)
    final boardCol = col - 1;
    final boardRow = row - 1;
    
    // Calculate current piece width
    final pieceWidth = _currentPiece![0].length;
    final pieceLeftCol = _currentCol;
    final pieceRightCol = _currentCol + pieceWidth - 1;
    
    // Determine tap zone relative to falling block
    if (boardCol < pieceLeftCol) {
      // Left zone - move left
      _moveLeft();
    } else if (boardCol > pieceRightCol) {
      // Right zone - move right
      _moveRight();
    }
    // For sustained press on the block itself, do nothing (rotation already handled for quick tap)
  }
  
  void _handlePanStart(Offset position) {
    _panStartPosition = position;
    _pressStartTime = DateTime.now(); // Track press start for drag gestures
  }
  
  void _handlePanUpdate(Offset position) {
    if (_panStartPosition == null || _gameOver || _isPaused || _currentPiece == null) return;
    
    final delta = position - _panStartPosition!;
    final absDeltaX = delta.dx.abs();
    final absDeltaY = delta.dy.abs();
    
    // Determine if this is a horizontal or vertical swipe
    if (absDeltaX > _swipeThreshold && absDeltaX > absDeltaY) {
      // Horizontal swipe - move side to side
      if (delta.dx < 0) {
        _moveLeft();
      } else {
        _moveRight();
      }
      _panStartPosition = position; // Reset to prevent multiple moves
    } else if (absDeltaY > _swipeThreshold && absDeltaY > absDeltaX) {
      // Vertical swipe down - soft drop
      if (delta.dy > 0) {
        _moveDown();
        _panStartPosition = position; // Reset to allow continuous soft drop
      }
    }
  }
  
  void _handlePanEnd() {
    _panStartPosition = null;
    _pressStartTime = null;
  }

  List<List<int>> _getDisplayBoard() {
    final display = _board.map((row) => List<int>.from(row)).toList();
    
    if (_currentPiece != null && !_gameOver) {
      for (int i = 0; i < _currentPiece!.length; i++) {
        for (int j = 0; j < _currentPiece![i].length; j++) {
          if (_currentPiece![i][j] == 1) {
            final row = _currentRow + i;
            final col = _currentCol + j;
            if (row >= 0 && row < rows && col >= 0 && col < cols) {
              display[row][col] = _currentPieceType + 10; // Current piece (10-17)
            }
          }
        }
      }
    }
    
    return display;
  }
  
  Color _getBlockColor(int value) {
    if (value == 0) return Colors.black; // Empty cell
    if (value >= 10) {
      // Current falling piece
      return _pieceColors[value - 11];
    }
    // Placed piece
    return _pieceColors[value - 1];
  }
  
  Widget _buildControlHint(String gesture, String action) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          gesture,
          style: TextStyle(
            color: Colors.blue.shade300,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          action,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildBlock(int value, {bool isBorder = false}) {
    final color = isBorder ? Colors.grey[600]! : _getBlockColor(value);
    final isFilled = value > 0 || isBorder;
    
    if (!isFilled) {
      return Container(color: Colors.black);
    }
    
    // Enhanced border blocks (like the image)
    if (isBorder) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[600],
          border: Border.all(
            color: Colors.grey[800]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 2,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey[500]!,
                Colors.grey[600]!,
                Colors.grey[700]!,
              ],
            ),
            border: Border(
              top: BorderSide(color: Colors.grey[400]!, width: 1),
              left: BorderSide(color: Colors.grey[400]!, width: 1),
              right: BorderSide(color: Colors.grey[800]!, width: 1),
              bottom: BorderSide(color: Colors.grey[800]!, width: 1),
            ),
          ),
        ),
      );
    }
    
    // Enhanced game blocks with modern 3D look
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 3,
            offset: const Offset(0, 2),
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 1,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.3, 0.7, 1.0],
            colors: [
              color.withOpacity(1.0), // Bright top
              color, // Main color
              color.withOpacity(0.85), // Slightly darker
              color.withOpacity(0.7), // Darker bottom
            ],
          ),
          borderRadius: BorderRadius.circular(2),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
            left: BorderSide(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            right: BorderSide(
              color: Colors.black.withOpacity(0.3),
              width: 1.5,
            ),
            bottom: BorderSide(
              color: Colors.black.withOpacity(0.4),
              width: 1.5,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.5,
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayBoard = _getDisplayBoard();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tetris'),
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () {
              setState(() {
                _isPaused = !_isPaused;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: _showLeaderboard,
            tooltip: 'Leaderboard',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initGame,
            tooltip: 'New Game',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(
                bottom: BorderSide(color: Colors.grey[700]!, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Next Piece Preview
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'NEXT',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_nextPiece != null)
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 1,
                            mainAxisSpacing: 1,
                          ),
                          itemCount: 16,
                          itemBuilder: (context, index) {
                            final row = index ~/ 4;
                            final col = index % 4;
                            final hasBlock = row < _nextPiece!.length &&
                                col < _nextPiece![row].length &&
                                _nextPiece![row][col] == 1;
                            return _buildBlock(hasBlock ? _nextPieceType : 0);
                          },
                        ),
                      ),
                  ],
                ),
                
                // Score
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SCORE',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_score',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                // Lines
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LINES',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_lines',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Game Board - Takes up most of the screen
                Expanded(
                  child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate board size to maximize screen usage
                  final availableWidth = constraints.maxWidth;
                  final availableHeight = constraints.maxHeight;
                  
                  // Calculate cell size based on available space
                  final cellWidth = availableWidth / (cols + 2);
                  final cellHeight = availableHeight / (rows + 2);
                  final cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;
                  
                  final boardWidth = cellSize * (cols + 2);
                  final boardHeight = cellSize * (rows + 2);
                  
                  return Center(
                    child: Container(
                      width: boardWidth,
                      height: boardHeight,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onTapDown: (details) {
                              _handleTapDown(details.localPosition, constraints.biggest);
                            },
                            onTapUp: (details) {
                              _handleTapUp(details.localPosition, constraints.biggest);
                            },
                            onPanStart: (details) {
                              _handlePanStart(details.localPosition);
                            },
                            onPanUpdate: (details) {
                              _handlePanUpdate(details.localPosition);
                            },
                            onPanEnd: (_) {
                              _handlePanEnd();
                            },
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols + 2, // Add border columns
                                crossAxisSpacing: 0,
                                mainAxisSpacing: 0,
                              ),
                              itemCount: (rows + 2) * (cols + 2), // Add border rows
                              itemBuilder: (context, index) {
                                final totalCols = cols + 2;
                                final row = index ~/ totalCols;
                                final col = index % totalCols;
                                
                                // Check if this is a border cell
                                final isBorder = row == 0 || row == rows + 1 || col == 0 || col == cols + 1;
                                
                                if (isBorder) {
                                  return _buildBlock(0, isBorder: true);
                                }
                                
                                // Game board cell
                                final boardRow = row - 1;
                                final boardCol = col - 1;
                                final value = displayBoard[boardRow][boardCol];
                                return _buildBlock(value);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
                ),
              ],
            ),
            // Instructions overlay (only shown before first game)
            if (_showInstructions)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade700, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sports_esports,
                          size: 64,
                          color: Colors.blue.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'How to Play',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildControlHint('Quick tap on block', '↻ Rotate'),
                        const SizedBox(height: 12),
                        _buildControlHint('Sustained press left of block', '← Move left'),
                        const SizedBox(height: 12),
                        _buildControlHint('Sustained press right of block', '→ Move right'),
                        const SizedBox(height: 12),
                        _buildControlHint('Swipe down', '⬇ Soft drop'),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _dismissInstructions,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('OK, Let\'s Play!'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

