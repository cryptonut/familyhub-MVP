import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../../core/services/logger_service.dart';
import '../../services/games_service.dart';

class WordScrambleScreen extends StatefulWidget {
  const WordScrambleScreen({super.key});

  @override
  State<WordScrambleScreen> createState() => _WordScrambleScreenState();
}

class _WordScrambleScreenState extends State<WordScrambleScreen> {
  final GamesService _gamesService = GamesService();
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  final Random _random = Random();

  final List<String> _words = [
    'FAMILY', 'HAPPY', 'LOVE', 'TOGETHER', 'SHARING',
    'CALENDAR', 'EVENT', 'TASK', 'CHAT', 'LOCATION',
  ];

  String _currentWord = '';
  String _scrambledWord = '';
  String _userGuess = '';
  bool _isCorrect = false;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _loadNewWord();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _loadNewWord() {
    _currentWord = _words[_random.nextInt(_words.length)];
    final chars = _currentWord.split('');
    chars.shuffle(_random);
    _scrambledWord = chars.join();
    _userGuess = '';
    _isCorrect = false;
    setState(() {});
  }

  Future<void> _checkAnswer() async {
    if (_userGuess.toUpperCase() == _currentWord) {
      setState(() {
        _isCorrect = true;
        _score++;
      });
      _confettiController.play();
      
      try {
        await _gamesService.recordWin('scramble');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Correct! +1 win'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        Logger.error('Error recording win', error: e, tag: 'WordScrambleScreen');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect. Try again!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Scramble'),
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
                        Text(
                          'Score: $_score',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Unscramble the word:',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _scrambledWord,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Your answer',
                            border: OutlineInputBorder(),
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _userGuess = value;
                            });
                          },
                          enabled: !_isCorrect,
                        ),
                        const SizedBox(height: 16),
                        if (_isCorrect)
                          Text(
                            'Correct! The word was $_currentWord',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isCorrect ? _loadNewWord : _checkAnswer,
                          child: Text(_isCorrect ? 'Next Word' : 'Check Answer'),
                        ),
                      ],
                    ),
                  ),
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

