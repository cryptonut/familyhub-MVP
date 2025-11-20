import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../../services/games_service.dart';

class FamilyBingoScreen extends StatefulWidget {
  const FamilyBingoScreen({super.key});

  @override
  State<FamilyBingoScreen> createState() => _FamilyBingoScreenState();
}

class _FamilyBingoScreenState extends State<FamilyBingoScreen> {
  final GamesService _gamesService = GamesService();
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  final Random _random = Random();

  List<List<int?>> _bingoCard = [];
  List<int> _calledNumbers = [];
  int _currentNumber = 0;
  bool _isBingo = false;

  @override
  void initState() {
    super.initState();
    _generateBingoCard();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _generateBingoCard() {
    _bingoCard = List.generate(5, (_) => List.generate(5, (_) => null));
    _calledNumbers = [];
    _currentNumber = 0;
    _isBingo = false;

    // Generate random numbers for each cell (1-25 for simplicity)
    final numbers = List.generate(25, (i) => i + 1);
    numbers.shuffle(_random);
    int index = 0;
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        if (i == 2 && j == 2) {
          _bingoCard[i][j] = null; // Free space
        } else {
          _bingoCard[i][j] = numbers[index++];
        }
      }
    }
    setState(() {});
  }

  void _callNumber() {
    if (_calledNumbers.length >= 25) return;

    int number;
    do {
      number = _random.nextInt(25) + 1;
    } while (_calledNumbers.contains(number));

    setState(() {
      _currentNumber = number;
      _calledNumbers.add(number);
    });

    _checkBingo();
  }

  void _checkBingo() {
    // Check rows
    for (int i = 0; i < 5; i++) {
      bool rowComplete = true;
      for (int j = 0; j < 5; j++) {
        if (_bingoCard[i][j] != null && !_calledNumbers.contains(_bingoCard[i][j])) {
          rowComplete = false;
          break;
        }
      }
      if (rowComplete) {
        _onBingo();
        return;
      }
    }

    // Check columns
    for (int j = 0; j < 5; j++) {
      bool colComplete = true;
      for (int i = 0; i < 5; i++) {
        if (_bingoCard[i][j] != null && !_calledNumbers.contains(_bingoCard[i][j])) {
          colComplete = false;
          break;
        }
      }
      if (colComplete) {
        _onBingo();
        return;
      }
    }

    // Check diagonals
    bool diag1Complete = true;
    bool diag2Complete = true;
    for (int i = 0; i < 5; i++) {
      if (_bingoCard[i][i] != null && !_calledNumbers.contains(_bingoCard[i][i])) {
        diag1Complete = false;
      }
      if (_bingoCard[i][4 - i] != null && !_calledNumbers.contains(_bingoCard[i][4 - i])) {
        diag2Complete = false;
      }
    }
    if (diag1Complete || diag2Complete) {
      _onBingo();
    }
  }

  Future<void> _onBingo() async {
    if (_isBingo) return;
    
    setState(() {
      _isBingo = true;
    });
    _confettiController.play();

    try {
      await _gamesService.recordWin('bingo');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BINGO! +1 win'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error recording win: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Bingo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Current Number Display
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Current Number',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentNumber > 0 ? _currentNumber.toString() : '--',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isBingo ? null : _callNumber,
                      icon: const Icon(Icons.casino),
                      label: const Text('Call Number'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Bingo Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Your Bingo Card',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Table(
                      border: TableBorder.all(),
                      children: List.generate(5, (i) {
                        return TableRow(
                          children: List.generate(5, (j) {
                            final number = _bingoCard[i][j];
                            final isCalled = number != null && _calledNumbers.contains(number);
                            final isFree = number == null;

                            return Container(
                              height: 50,
                              color: isFree
                                  ? Colors.grey[200]
                                  : isCalled
                                      ? Colors.green[200]
                                      : Colors.white,
                              child: Center(
                                child: Text(
                                  isFree ? 'FREE' : number.toString(),
                                  style: TextStyle(
                                    fontWeight: isCalled ? FontWeight.bold : FontWeight.normal,
                                    color: isCalled ? Colors.green[900] : Colors.black,
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      }),
                    ),
                    if (_isBingo)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'BINGO!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generateBingoCard,
              icon: const Icon(Icons.refresh),
              label: const Text('New Card'),
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
      ),
    );
  }
}

