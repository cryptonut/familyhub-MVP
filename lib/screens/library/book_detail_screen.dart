import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/book.dart';
import '../../models/book_rating.dart';
import '../../models/exploding_book_challenge.dart';
import '../../models/hub.dart';
import '../../services/book_rating_service.dart';
import '../../services/book_service.dart';
import '../../services/exploding_books_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/book_rating_widget.dart';
import '../../widgets/ui_components.dart';
import 'book_reader_screen.dart';
import 'exploding_books_setup_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Hub hub;
  final Book book;

  const BookDetailScreen({
    super.key,
    required this.hub,
    required this.book,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final BookService _bookService = BookService();
  final BookRatingService _ratingService = BookRatingService();
  final ExplodingBooksService _explodingBooksService = ExplodingBooksService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<BookRating> _ratings = [];
  BookRating? _userRating;
  ExplodingBookChallenge? _activeChallenge;
  bool _isLoading = true;
  bool _canRate = false;

  @override
  void initState() {
    super.initState();
    _loadBookData();
  }

  Future<void> _loadBookData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Ensure book exists in hub before accessing subcollections
      await _bookService.addBookToHub(widget.hub.id, widget.book);

      // Load ratings
      final ratings = await _ratingService.getBookRatings(widget.hub.id, widget.book.id);
      final userRating = await _ratingService.getUserRating(widget.hub.id, widget.book.id, userId);

      // Load active challenge
      final challenge = await _explodingBooksService.getActiveChallenge(
        widget.hub.id,
        widget.book.id,
        userId,
      );

      // Check if user can rate
      final canRate = await _ratingService.canUserRateBook(widget.hub.id, widget.book.id, userId) || userRating != null;

      if (mounted) {
        setState(() {
          _ratings = ratings;
          _userRating = userRating;
          _activeChallenge = challenge;
          _canRate = canRate;
          _isLoading = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading book data: $e')),
        );
      }
    }
  }

  Future<void> _onRatingSubmitted(int rating, {String? comment, bool isAnonymous = false}) async {
    try {
      await _ratingService.rateBook(
        widget.hub.id,
        widget.book.id,
        rating,
        comment: comment,
        isAnonymous: isAnonymous,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted')),
        );
        _loadBookData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting rating: $e')),
        );
      }
    }
  }

  Future<void> _startReading() async {
    // Navigate to reader screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookReaderScreen(
          hub: widget.hub,
          book: widget.book,
          challenge: _activeChallenge,
        ),
      ),
    ).then((_) => _loadBookData());
  }

  Future<void> _startExplodingBooksChallenge() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExplodingBooksSetupScreen(
          hub: widget.hub,
          book: widget.book,
        ),
      ),
    );

    if (result == true && mounted) {
      _loadBookData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book cover and basic info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover
                      Container(
                        width: 120,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: widget.book.coverUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: widget.book.coverUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.book, size: 48),
                                ),
                              )
                            : const Icon(Icons.book, size: 48),
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.book.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.book.authors.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                widget.book.authors.join(', '),
                                style: theme.textTheme.bodyLarge,
                              ),
                            ],
                            if (widget.book.publishDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Published: ${widget.book.publishDate!.year}',
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
                            const SizedBox(height: 12),
                            // Rating display
                            if (widget.book.averageRating != null)
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.book.averageRating!.toStringAsFixed(1)}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${widget.book.ratingCount} ratings)',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              )
                            else
                              Text(
                                'Be the First to Rate This Book!',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLG),

                  // Description
                  if (widget.book.description != null) ...[
                    Text(
                      'Description',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      widget.book.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startReading,
                          icon: const Icon(Icons.book),
                          label: Text(_activeChallenge != null ? 'Continue Reading' : 'Start Reading'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _startExplodingBooksChallenge,
                          icon: const Icon(Icons.timer),
                          label: Text(_activeChallenge != null ? 'View Challenge' : 'Exploding Books'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLG),

                  // Active challenge info
                  if (_activeChallenge != null) ...[
                    ModernCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.timer, color: Colors.orange),
                                const SizedBox(width: 8),
                                Text(
                                  'Active Challenge',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Target: ${_formatDate(_activeChallenge!.targetCompletionDate)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (_activeChallenge!.timeRemaining != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Time remaining: ${_formatDuration(_activeChallenge!.timeRemaining!)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                  ],

                  // Rating section
                  _buildRatingSection(),
                  const SizedBox(height: AppTheme.spacingLG),

                  // Comments section
                  _buildCommentsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate This Book',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        if (!_canRate && _userRating == null)
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Read to Rate',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You must read the book or complete the quiz before you can rate it.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
        else
          BookRatingWidget(
            initialRating: _userRating?.rating,
            initialComment: _userRating?.comment,
            initialIsAnonymous: _userRating?.isAnonymous ?? false,
            onRatingSubmitted: _canRate ? _onRatingSubmitted : null,
          ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    if (_ratings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments (${_ratings.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        ..._ratings.where((r) => r.comment != null && r.comment!.isNotEmpty).map((rating) {
          return ModernCard(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  rating.isAnonymous
                      ? '?'
                      : (rating.userName?.isNotEmpty == true
                          ? rating.userName![0].toUpperCase()
                          : '?'),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    rating.isAnonymous ? 'Anonymous' : (rating.userName ?? 'Unknown'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(5, (index) {
                    return Icon(
                      index < rating.rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    );
                  }),
                ],
              ),
              subtitle: Text(rating.comment ?? ''),
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}

