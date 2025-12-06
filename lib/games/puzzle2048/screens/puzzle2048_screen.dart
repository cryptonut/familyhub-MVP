import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../../../core/services/logger_service.dart';

/// 2048 Puzzle Game Screen
class Puzzle2048Screen extends StatefulWidget {
  const Puzzle2048Screen({super.key});

  @override
  State<Puzzle2048Screen> createState() => _Puzzle2048ScreenState();
}

class _Puzzle2048ScreenState extends State<Puzzle2048Screen> {
  static const int gridSize = 4;
  static const String _bestScoreKey = 'puzzle2048_best_score';
  
  List<List<int>> _grid = [];
  int _score = 0;
  int _bestScore = 0;
  bool _gameOver = false;
  bool _gameWon = false;

  @override
  void initState() {
    super.initState();
    _loadBestScore();
    _initGame();
  }

  Future<void> _loadBestScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _bestScore = prefs.getInt(_bestScoreKey) ?? 0;
      });
    } catch (e) {
      Logger.warning('Error loading best score', error: e, tag: 'Puzzle2048');
    }
  }

  void _initGame() {
    _grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    _score = 0;
    _gameOver = false;
    _gameWon = false;
    _addRandomTile();
    _addRandomTile();
    setState(() {});
  }

  void _addRandomTile() {
    final emptyCells = <Point<int>>[];
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (_grid[i][j] == 0) {
          emptyCells.add(Point(i, j));
        }
      }
    }
    
    if (emptyCells.isNotEmpty) {
      final random = Random();
      final cell = emptyCells[random.nextInt(emptyCells.length)];
      _grid[cell.x][cell.y] = random.nextDouble() < 0.9 ? 2 : 4;
    }
  }

  bool _moveLeft() {
    bool moved = false;
    for (int i = 0; i < gridSize; i++) {
      final row = _grid[i].where((cell) => cell != 0).toList();
      final newRow = <int>[];
      
      for (int j = 0; j < row.length; j++) {
        if (j < row.length - 1 && row[j] == row[j + 1]) {
          newRow.add(row[j] * 2);
          _score += row[j] * 2;
          if (row[j] * 2 == 2048 && !_gameWon) {
            _gameWon = true;
          }
          j++;
          moved = true;
        } else {
          newRow.add(row[j]);
        }
      }
      
      while (newRow.length < gridSize) {
        newRow.add(0);
      }
      
      if (!_listEquals(_grid[i], newRow)) {
        moved = true;
      }
      _grid[i] = newRow;
    }
    return moved;
  }

  bool _moveRight() {
    bool moved = false;
    for (int i = 0; i < gridSize; i++) {
      final row = _grid[i].where((cell) => cell != 0).toList().reversed.toList();
      final newRow = <int>[];
      
      for (int j = 0; j < row.length; j++) {
        if (j < row.length - 1 && row[j] == row[j + 1]) {
          newRow.add(row[j] * 2);
          _score += row[j] * 2;
          if (row[j] * 2 == 2048 && !_gameWon) {
            _gameWon = true;
          }
          j++;
          moved = true;
        } else {
          newRow.add(row[j]);
        }
      }
      
      while (newRow.length < gridSize) {
        newRow.insert(0, 0);
      }
      
      if (!_listEquals(_grid[i], newRow)) {
        moved = true;
      }
      _grid[i] = newRow;
    }
    return moved;
  }

  bool _moveUp() {
    bool moved = false;
    for (int j = 0; j < gridSize; j++) {
      final column = <int>[];
      for (int i = 0; i < gridSize; i++) {
        if (_grid[i][j] != 0) {
          column.add(_grid[i][j]);
        }
      }
      
      final newColumn = <int>[];
      for (int i = 0; i < column.length; i++) {
        if (i < column.length - 1 && column[i] == column[i + 1]) {
          newColumn.add(column[i] * 2);
          _score += column[i] * 2;
          if (column[i] * 2 == 2048 && !_gameWon) {
            _gameWon = true;
          }
          i++;
          moved = true;
        } else {
          newColumn.add(column[i]);
        }
      }
      
      while (newColumn.length < gridSize) {
        newColumn.add(0);
      }
      
      for (int i = 0; i < gridSize; i++) {
        if (_grid[i][j] != newColumn[i]) {
          moved = true;
        }
        _grid[i][j] = newColumn[i];
      }
    }
    return moved;
  }

  bool _moveDown() {
    bool moved = false;
    for (int j = 0; j < gridSize; j++) {
      final column = <int>[];
      for (int i = gridSize - 1; i >= 0; i--) {
        if (_grid[i][j] != 0) {
          column.add(_grid[i][j]);
        }
      }
      
      var newColumn = <int>[];
      for (int i = 0; i < column.length; i++) {
        if (i < column.length - 1 && column[i] == column[i + 1]) {
          newColumn.add(column[i] * 2);
          _score += column[i] * 2;
          if (column[i] * 2 == 2048 && !_gameWon) {
            _gameWon = true;
          }
          i++;
          moved = true;
        } else {
          newColumn.add(column[i]);
        }
      }
      
      while (newColumn.length < gridSize) {
        newColumn.add(0);
      }
      
      newColumn = newColumn.reversed.toList();
      
      for (int i = 0; i < gridSize; i++) {
        if (_grid[i][j] != newColumn[i]) {
          moved = true;
        }
        _grid[i][j] = newColumn[i];
      }
    }
    return moved;
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _canMove() {
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (_grid[i][j] == 0) return true;
        if (i < gridSize - 1 && _grid[i][j] == _grid[i + 1][j]) return true;
        if (j < gridSize - 1 && _grid[i][j] == _grid[i][j + 1]) return true;
      }
    }
    return false;
  }

  void _handleMove(bool moved) {
    if (moved) {
      _addRandomTile();
      if (!_canMove()) {
        _gameOver = true;
        _saveScore();
      }
      setState(() {});
    }
  }

  Future<void> _saveScore() async {
    if (_score > _bestScore) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_bestScoreKey, _score);
        setState(() {
          _bestScore = _score;
        });
      } catch (e) {
        Logger.error('Error saving score', error: e, tag: 'Puzzle2048');
      }
    }
  }

  Color _getTileColor(int value) {
    if (value == 0) return Colors.grey[300]!;
    final colors = {
      2: Colors.blue[50]!,
      4: Colors.blue[100]!,
      8: Colors.blue[200]!,
      16: Colors.blue[300]!,
      32: Colors.blue[400]!,
      64: Colors.blue[500]!,
      128: Colors.blue[600]!,
      256: Colors.blue[700]!,
      512: Colors.blue[800]!,
      1024: Colors.blue[900]!,
      2048: Colors.amber,
    };
    return colors[value] ?? Colors.purple;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2048'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _initGame();
            },
            tooltip: 'New Game',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Score and Best Score
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
                      const Text('Best', style: TextStyle(fontSize: 16)),
                      Text('$_bestScore', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            
            // Game Grid
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity! > 0) {
                          _handleMove(_moveDown());
                        } else if (details.primaryVelocity! < 0) {
                          _handleMove(_moveUp());
                        }
                      },
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity! > 0) {
                          _handleMove(_moveRight());
                        } else if (details.primaryVelocity! < 0) {
                          _handleMove(_moveLeft());
                        }
                      },
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridSize,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: gridSize * gridSize,
                        itemBuilder: (context, index) {
                          final row = index ~/ gridSize;
                          final col = index % gridSize;
                          final value = _grid[row][col];
                          
                          return Container(
                            decoration: BoxDecoration(
                              color: _getTileColor(value),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: value == 0
                                  ? const SizedBox()
                                  : Text(
                                      '$value',
                                      style: TextStyle(
                                        fontSize: value > 512 ? 20 : 24,
                                        fontWeight: FontWeight.bold,
                                        color: value >= 8 ? Colors.white : Colors.black87,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Instructions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Swipe to move tiles. Combine tiles with the same number!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

