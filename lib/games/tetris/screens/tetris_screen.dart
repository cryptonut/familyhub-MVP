import 'package:flutter/material.dart';
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
  Timer? _gameTimer;
  List<Map<String, dynamic>> _highScores = [];
  static const String _highScoresKey = 'tetris_high_scores';
  
  final GamesService _gamesService = GamesService();
  final AuthService _authService = AuthService();
  
  // Next piece
  List<List<int>>? _nextPiece;
  int _nextPieceType = 0;

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
    _initGame();
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
    _board = List.generate(rows, (_) => List.filled(cols, 0));
    _score = 0;
    _lines = 0;
    _gameOver = false;
    _isPaused = false;
    _spawnPiece();
    _startGame();
    setState(() {});
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
    if (!_checkCollision(_currentRow, _currentCol - 1, _currentPiece!)) {
      setState(() {
        _currentCol--;
      });
    }
  }

  void _moveRight() {
    if (!_checkCollision(_currentRow, _currentCol + 1, _currentPiece!)) {
      setState(() {
        _currentCol++;
      });
    }
  }

  void _rotate() {
    if (_currentPiece == null) return;
    
    final rotated = List.generate(
      _currentPiece![0].length,
      (i) => List.generate(
        _currentPiece!.length,
        (j) => _currentPiece![_currentPiece!.length - 1 - j][i],
      ),
    );
    
    if (!_checkCollision(_currentRow, _currentCol, rotated)) {
      setState(() {
        _currentPiece = rotated;
      });
    }
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
  
  Widget _buildBlock(int value, {bool isBorder = false}) {
    final color = isBorder ? Colors.grey[600]! : _getBlockColor(value);
    final isFilled = value > 0 || isBorder;
    
    return Container(
      decoration: BoxDecoration(
        color: isFilled ? color : Colors.black,
        border: isBorder 
            ? Border.all(color: Colors.grey[800]!, width: 1)
            : null,
        boxShadow: isFilled && !isBorder
            ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                ),
              ]
            : null,
      ),
      child: isFilled && !isBorder
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.9),
                    color,
                    color.withOpacity(0.7),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
            )
          : null,
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Score and Lines
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Score', style: TextStyle(fontSize: 16)),
                      Text('$_score', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Lines', style: TextStyle(fontSize: 16)),
                      Text('$_lines', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            
            // Game Board with Next Piece
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate available width
                  final availableWidth = constraints.maxWidth;
                  final nextPieceWidth = 80.0;
                  final spacing = 8.0;
                  final boardMaxWidth = availableWidth - nextPieceWidth - spacing - 32; // Account for padding
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Main Game Board with Border
                      Flexible(
                        child: Container(
                          constraints: BoxConstraints(maxWidth: boardMaxWidth),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey[900]!.withOpacity(0.5),
                                blurRadius: 4,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: AspectRatio(
                            aspectRatio: (cols + 2) / (rows + 2), // Account for border
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
                          ),
                        ),
                      ),
                      
                      // Next Piece Preview
                      SizedBox(width: spacing),
                      Container(
                        width: nextPieceWidth,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[700]!, width: 1),
                        ),
                        child: Column(
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
                                width: 60,
                                height: 60,
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4, // Max width for preview
                                    crossAxisSpacing: 1,
                                    mainAxisSpacing: 1,
                                  ),
                                  itemCount: 16, // 4x4 grid
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
                      ),
                    ],
                  );
                },
              ),
            ),
            
            // Controls
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 32),
                    onPressed: _gameOver || _isPaused ? null : _moveLeft,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 32),
                    onPressed: _gameOver || _isPaused ? null : _moveDown,
                  ),
                  IconButton(
                    icon: const Icon(Icons.rotate_right, size: 32),
                    onPressed: _gameOver || _isPaused ? null : _rotate,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 32),
                    onPressed: _gameOver || _isPaused ? null : _moveRight,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

