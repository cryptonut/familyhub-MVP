import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../../services/games_service.dart';
import '../../services/auth_service.dart';
import '../../services/chess_puzzle_service.dart';
import '../../widgets/chess_board_widget.dart';

class ChessPuzzleScreen extends StatefulWidget {
  const ChessPuzzleScreen({super.key});

  @override
  State<ChessPuzzleScreen> createState() => _ChessPuzzleScreenState();
}

class _ChessPuzzleScreenState extends State<ChessPuzzleScreen> {
  final GamesService _gamesService = GamesService();
  final ChessPuzzleService _puzzleService = ChessPuzzleService();
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  
  chess_lib.Chess? _game;
  Map<String, dynamic>? _currentPuzzle;
  String _solution = '';
  bool _isSolved = false;
  bool _showHint = false;
  String? _hintMove;

  @override
  void initState() {
    super.initState();
    _loadNewPuzzle();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadNewPuzzle() async {
    final puzzle = _puzzleService.getRandomPuzzle();
    final game = _puzzleService.createGameFromFEN(puzzle['fen'] as String);
    
    setState(() {
      _currentPuzzle = puzzle;
      _game = game;
      _isSolved = false;
      _showHint = false;
      _solution = '';
      _hintMove = null;
    });
  }

  void _onMove(String move) {
    if (_game == null || _isSolved) return;

    // Check if this is the solution before making the move
    final solution = _currentPuzzle?['solution'] as String?;
    if (solution != null && _puzzleService.isSolution(_game!, move, solution)) {
      setState(() {
        _solution = move;
      });
      _handlePuzzleSolved();
    } else {
      // Invalid move - show feedback but don't make the move
      setState(() {
        _solution = move;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not the correct move. Try again!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      // Reset the solution display after a moment
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isSolved) {
          setState(() {
            _solution = '';
          });
        }
      });
    }
  }

  Future<void> _handlePuzzleSolved() async {
    setState(() {
      _isSolved = true;
    });
    _confettiController.play();
    
    try {
      await _gamesService.recordWin('chess');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Puzzle solved! +1 win'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error recording win: $e');
    }
  }

  Future<void> _checkSolution() async {
    if (_solution.isEmpty || _game == null || _currentPuzzle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please make a move first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final solution = _currentPuzzle!['solution'] as String;
    if (_puzzleService.isSolution(_game!, _solution, solution)) {
      await _handlePuzzleSolved();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect move. Try again!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showHintMove() {
    if (_game == null) return;
    
    setState(() {
      _showHint = true;
      _hintMove = _puzzleService.getHint(_game!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Puzzles'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Solve the Puzzle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_game != null)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: ChessBoardWidget(
                              game: _game!,
                              onMove: _onMove,
                            ),
                          )
                        else
                          Container(
                            height: 300,
                            decoration: BoxDecoration(
                              color: Colors.brown[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        if (_currentPuzzle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _currentPuzzle!['description'] as String? ?? 'Solve the puzzle',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Last move: ${_solution.isEmpty ? "Make a move on the board" : _solution}',
                            border: const OutlineInputBorder(),
                            enabled: false,
                          ),
                          controller: TextEditingController(text: _solution),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _showHintMove,
                                child: const Text('Hint'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _isSolved ? null : _checkSolution,
                                child: const Text('Check Solution'),
                              ),
                            ),
                          ],
                        ),
                        if (_showHint && _currentPuzzle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                Text(
                                  _currentPuzzle!['hint'] as String? ?? 'Look for the best move',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                if (_hintMove != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Suggested move: $_hintMove',
                                      style: TextStyle(
                                        color: Colors.orange[900],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (_isSolved)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Correct! Well done!',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadNewPuzzle,
                  icon: const Icon(Icons.refresh),
                  label: const Text('New Puzzle'),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

