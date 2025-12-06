import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/services/logger_service.dart';

/// Classic 15-Slide Puzzle Game Screen
class SlidePuzzleScreen extends StatefulWidget {
  const SlidePuzzleScreen({super.key});

  @override
  State<SlidePuzzleScreen> createState() => _SlidePuzzleScreenState();
}

class _SlidePuzzleScreenState extends State<SlidePuzzleScreen> {
  static const int gridSize = 4;
  List<List<int>> _puzzle = [];
  int _moves = 0;
  bool _isSolved = false;
  int _emptyRow = 3;
  int _emptyCol = 3;

  @override
  void initState() {
    super.initState();
    _initPuzzle();
  }

  void _initPuzzle() {
    // Create solved puzzle
    _puzzle = List.generate(
      gridSize,
      (i) => List.generate(
        gridSize,
        (j) => i * gridSize + j + 1,
      ),
    );
    _puzzle[gridSize - 1][gridSize - 1] = 0; // Empty space
    
    _moves = 0;
    _isSolved = false;
    _emptyRow = gridSize - 1;
    _emptyCol = gridSize - 1;
    
    // Shuffle the puzzle
    _shuffle();
    setState(() {});
  }

  void _shuffle() {
    final random = Random();
    // Make many random moves to shuffle
    for (int i = 0; i < 1000; i++) {
      final directions = <String>[];
      if (_emptyRow > 0) directions.add('up');
      if (_emptyRow < gridSize - 1) directions.add('down');
      if (_emptyCol > 0) directions.add('left');
      if (_emptyCol < gridSize - 1) directions.add('right');
      
      if (directions.isNotEmpty) {
        final direction = directions[random.nextInt(directions.length)];
        _move(direction, false);
      }
    }
    _moves = 0;
  }

  bool _move(String direction, bool countMove) {
    int newRow = _emptyRow;
    int newCol = _emptyCol;
    
    switch (direction) {
      case 'up':
        if (_emptyRow == 0) return false;
        newRow = _emptyRow - 1;
        break;
      case 'down':
        if (_emptyRow == gridSize - 1) return false;
        newRow = _emptyRow + 1;
        break;
      case 'left':
        if (_emptyCol == 0) return false;
        newCol = _emptyCol - 1;
        break;
      case 'right':
        if (_emptyCol == gridSize - 1) return false;
        newCol = _emptyCol + 1;
        break;
    }
    
    // Swap
    _puzzle[_emptyRow][_emptyCol] = _puzzle[newRow][newCol];
    _puzzle[newRow][newCol] = 0;
    _emptyRow = newRow;
    _emptyCol = newCol;
    
    if (countMove) {
      _moves++;
      _checkSolved();
    }
    
    return true;
  }

  void _checkSolved() {
    bool solved = true;
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final expected = i == gridSize - 1 && j == gridSize - 1
            ? 0
            : i * gridSize + j + 1;
        if (_puzzle[i][j] != expected) {
          solved = false;
          break;
        }
      }
      if (!solved) break;
    }
    
    if (solved && !_isSolved) {
      _isSolved = true;
      _showSolvedDialog();
    }
  }

  void _showSolvedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Puzzle Solved!'),
        content: Text('Congratulations! You solved it in $_moves moves!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initPuzzle();
            },
            child: const Text('New Puzzle'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleTileTap(int row, int col) {
    if (_isSolved) return;
    
    // Check if tile is adjacent to empty space
    if ((row == _emptyRow && (col == _emptyCol - 1 || col == _emptyCol + 1)) ||
        (col == _emptyCol && (row == _emptyRow - 1 || row == _emptyRow + 1))) {
      String direction = '';
      if (row < _emptyRow) direction = 'up';
      else if (row > _emptyRow) direction = 'down';
      else if (col < _emptyCol) direction = 'left';
      else if (col > _emptyCol) direction = 'right';
      
      if (_move(direction, true)) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slide Puzzle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initPuzzle,
            tooltip: 'New Puzzle',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Moves counter
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Moves: $_moves',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            // Puzzle Grid
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridSize,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: gridSize * gridSize,
                      itemBuilder: (context, index) {
                        final row = index ~/ gridSize;
                        final col = index % gridSize;
                        final value = _puzzle[row][col];
                        
                        if (value == 0) {
                          // Empty space
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }
                        
                        return GestureDetector(
                          onTap: () => _handleTileTap(row, col),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isSolved ? Colors.green[300] : Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '$value',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
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
            
            // Instructions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Tap tiles to slide them into the empty space',
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

