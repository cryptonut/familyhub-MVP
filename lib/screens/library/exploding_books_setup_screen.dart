import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/hub.dart';
import '../../models/book.dart';
import '../../services/exploding_books_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

class ExplodingBooksSetupScreen extends StatefulWidget {
  final Hub hub;
  final Book book;

  const ExplodingBooksSetupScreen({
    super.key,
    required this.hub,
    required this.book,
  });

  @override
  State<ExplodingBooksSetupScreen> createState() => _ExplodingBooksSetupScreenState();
}

class _ExplodingBooksSetupScreenState extends State<ExplodingBooksSetupScreen> {
  final ExplodingBooksService _explodingBooksService = ExplodingBooksService();
  final _formKey = GlobalKey<FormState>();

  DateTime _targetDate = DateTime.now().add(const Duration(days: 14));
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use actual page count from book metadata
    // If not available, estimate based on common book lengths
    // Don't default to 300 - that's misleading
    final pageCount = widget.book.pageCount ?? _estimatePageCount(widget.book);
    final suggestedDays = _calculateSuggestedDays(pageCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exploding Books Challenge'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book info card
              ModernCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  child: Row(
                    children: [
                      if (widget.book.coverUrl != null)
                        Image.network(
                          widget.book.coverUrl!,
                          width: 60,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.book, size: 48),
                        )
                      else
                        const Icon(Icons.book, size: 48),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.book.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.book.authors.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.book.authors.join(', '),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            if (widget.book.pageCount != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${widget.book.pageCount} pages',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // Challenge setup
              Text(
                'Set Your Target',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                'Choose a target completion date for your reading challenge. Complete the book by this date to maximize your time score!',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppTheme.spacingMD),

              // Suggested time
              ModernCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            'Smart Suggestion',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.book.pageCount != null
                            ? 'Based on ${pageCount} pages, we suggest completing this book in $suggestedDays days.'
                            : 'Page count not available. We suggest completing this book in $suggestedDays days. You can adjust the target date below.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _targetDate = DateTime.now().add(Duration(days: suggestedDays));
                          });
                        },
                        icon: const Icon(Icons.check),
                        label: Text('Use $suggestedDays days'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),

              // Date picker
              ListTile(
                title: const Text('Target Completion Date'),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(_targetDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _targetDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _targetDate = picked;
                    });
                  }
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // Info box
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'How It Works',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• A countdown timer will track your progress\n'
                      '• Complete the book by your target date for maximum time score\n'
                      '• After finishing, you\'ll take a 10-question quiz\n'
                      '• Your total score = Time Score × Memory Score\n'
                      '• Compete on the leaderboard!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),

              // Create challenge button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createChallenge,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Start Challenge',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Estimate page count if not available from metadata
  /// This is a rough estimate - better to have actual page count from API
  int _estimatePageCount(Book book) {
    // If we have no page count, we can't accurately estimate
    // Return a conservative estimate that won't mislead users
    // Better to show "Unknown" or let user set their own target
    return 200; // Conservative default - user can adjust
  }

  int _calculateSuggestedDays(int pageCount) {
    // Assume average reading speed: 20-30 pages per day
    // For a more intelligent calculation, we could consider:
    // - Book difficulty
    // - User's reading history
    // - Available time
    final days = (pageCount / 25).ceil(); // 25 pages per day average
    return days.clamp(1, 90); // Between 1 day and 90 days
  }

  Future<void> _createChallenge() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isCreating = true);

    try {
      await _explodingBooksService.createChallenge(
        hubId: widget.hub.id,
        bookId: widget.book.id,
        targetCompletionDate: _targetDate,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge created! Start reading to begin the countdown.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating challenge: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

