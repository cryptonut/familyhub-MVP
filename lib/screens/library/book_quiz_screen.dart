import 'package:flutter/material.dart';
import '../../models/hub.dart';
import '../../models/book.dart';
import '../../models/book_quiz.dart';
import '../../services/book_quiz_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'leaderboard_screen.dart';

class BookQuizScreen extends StatefulWidget {
  final Hub hub;
  final Book book;
  final String challengeId;

  const BookQuizScreen({
    super.key,
    required this.hub,
    required this.book,
    required this.challengeId,
  });

  @override
  State<BookQuizScreen> createState() => _BookQuizScreenState();
}

class _BookQuizScreenState extends State<BookQuizScreen> {
  final BookQuizService _quizService = BookQuizService();

  BookQuiz? _quiz;
  Map<String, int> _answers = {}; // questionId -> selectedOptionIndex
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showResults = false;
  int? _finalScore;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() => _isLoading = true);
    try {
      // Generate or get existing quiz
      final quiz = await _quizService.generateQuiz(
        hubId: widget.hub.id,
        bookId: widget.book.id,
        challengeId: widget.challengeId,
      );

      if (mounted) {
        setState(() {
          _quiz = quiz;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quiz: $e')),
        );
      }
    }
  }

  void _selectAnswer(String questionId, int optionIndex) {
    setState(() {
      _answers[questionId] = optionIndex;
    });
  }

  void _nextQuestion() {
    if (_quiz == null) return;

    if (_currentQuestionIndex < _quiz!.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _submitQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitQuiz() async {
    if (_quiz == null) return;

    // Ensure all questions are answered
    if (_answers.length < _quiz!.questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all questions before submitting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final completedQuiz = await _quizService.submitQuizAnswersWithBookId(
        hubId: widget.hub.id,
        bookId: widget.book.id,
        quizId: _quiz!.id,
        answers: _answers,
      );

      if (mounted) {
        setState(() {
          _quiz = completedQuiz;
          _finalScore = completedQuiz.score;
          _showResults = true;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting quiz: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Quiz...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quiz == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('Quiz not found')),
      );
    }

    if (_showResults) {
      return _buildResultsScreen(theme);
    }

    final question = _quiz!.questions[_currentQuestionIndex];
    final selectedAnswer = _answers[question.id];

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentQuestionIndex + 1} / ${_quiz!.questions.length}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _quiz!.questions.length,
              minHeight: 6,
            ),
            const SizedBox(height: AppTheme.spacingLG),

            // Question
            Text(
              question.question,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),

            // Options
            ...question.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = selectedAnswer == index;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                child: InkWell(
                  onTap: () => _selectAnswer(question.id, index),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withValues(alpha: 0.4),
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: theme.colorScheme.onPrimary,
                                )
                              : null,
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: Text(
                            option,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: AppTheme.spacingLG),

            // Navigation buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                  child: const Text('Previous'),
                ),
                ElevatedButton(
                  onPressed: selectedAnswer != null
                      ? (_currentQuestionIndex < _quiz!.questions.length - 1
                          ? _nextQuestion
                          : _submitQuiz)
                      : null,
                  child: Text(
                    _currentQuestionIndex < _quiz!.questions.length - 1
                        ? 'Next'
                        : 'Submit Quiz',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsScreen(ThemeData theme) {
    if (_quiz == null || _finalScore == null) {
      return const Center(child: Text('Results not available'));
    }

    final correctAnswers = _quiz!.correctAnswers;
    final totalQuestions = _quiz!.questions.length;
    final percentage = (correctAnswers / totalQuestions * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Score display
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$_finalScore',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              'Memory Score',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              '$correctAnswers / $totalQuestions correct',
              style: theme.textTheme.bodyLarge,
            ),
            Text(
              '$percentage%',
              style: theme.textTheme.titleMedium?.copyWith(
                color: percentage >= 70 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),

            // Breakdown
            ModernCard(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Score Breakdown',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    _buildScoreRow('Memory Score', _finalScore!),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'Your total score = Memory Score × Time Score',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LeaderboardScreen(hubId: widget.hub.id),
                    ),
                  );
                },
                icon: const Icon(Icons.leaderboard),
                label: const Text('View Leaderboard'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          '$value',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

