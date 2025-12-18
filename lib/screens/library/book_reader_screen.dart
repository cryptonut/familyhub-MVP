import 'package:flutter/material.dart';
import '../../models/hub.dart';
import '../../models/book.dart';
import '../../models/exploding_book_challenge.dart';
import '../../services/exploding_books_service.dart';
import '../../services/book_service.dart';
import '../../widgets/exploding_books_countdown.dart';
import '../../widgets/book_viewer.dart';
import '../../widgets/ui_components.dart';
import 'book_quiz_screen.dart';
import 'upload_book_file_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/logger_service.dart';

class BookReaderScreen extends StatefulWidget {
  final Hub hub;
  final Book book;
  final ExplodingBookChallenge? challenge;

  const BookReaderScreen({
    super.key,
    required this.hub,
    required this.book,
    this.challenge,
  });

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final ExplodingBooksService _explodingBooksService = ExplodingBooksService();
  final BookService _bookService = BookService();

  int _currentPage = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingContent = true;
  BookContent? _bookContent;
  String? _contentError;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.challenge?.currentPage ?? 0;
    _startReadingIfNeeded();
    _loadBookContent();
  }

  Future<void> _loadBookContent() async {
    setState(() {
      _isLoadingContent = true;
      _contentError = null;
    });

    try {
      // First check for user-uploaded book
      final uploadedContent = await _bookService.getUserUploadedBook(widget.hub.id, widget.book.id);
      if (uploadedContent != null) {
        if (mounted) {
          setState(() {
            _bookContent = uploadedContent;
            _isLoadingContent = false;
          });
        }
        return;
      }

      // Then try online sources (Archive.org, Project Gutenberg)
      Logger.info('Loading book content for: ${widget.book.title} (ID: ${widget.book.id})', tag: 'BookReaderScreen');
      final content = await _bookService.getBookContentUrl(widget.book);
      Logger.info('Book content result: ${content != null ? "Found ${content.format} at ${content.url}" : "NOT FOUND"}', tag: 'BookReaderScreen');
      if (mounted) {
        setState(() {
          _bookContent = content;
          _isLoadingContent = false;
          if (content == null) {
            _contentError = null; // Will show helpful message in UI
          }
        });
      }
    } catch (e, st) {
      Logger.error('Error loading book content', error: e, stackTrace: st, tag: 'BookReaderScreen');
      if (mounted) {
        setState(() {
          _contentError = 'Failed to load book: ${e.toString()}';
          _isLoadingContent = false;
        });
      }
    }
  }

  Future<void> _startReadingIfNeeded() async {
    if (widget.challenge != null && widget.challenge!.startedAt == null) {
      try {
        await _explodingBooksService.startReading(widget.hub.id, widget.challenge!.id);
        if (mounted) {
          setState(() {});
        }
      } on Exception catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting challenge: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateProgress(int page) async {
    setState(() {
      _currentPage = page;
    });

    // Only update challenge if one exists
    if (widget.challenge != null) {
      try {
        await _explodingBooksService.updateReadingProgress(
          widget.hub.id,
          widget.challenge!.id,
          currentPage: page,
        );
      } catch (e) {
        Logger.warning('Error updating reading progress', error: e, tag: 'BookReaderScreen');
      }
    }
  }

  Future<void> _completeReading() async {
    if (widget.challenge == null) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _explodingBooksService.completeChallenge(
        widget.hub.id,
        widget.challenge!.id,
      );

      if (mounted) {
        // Navigate to quiz
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookQuizScreen(
              hub: widget.hub,
              book: widget.book,
              challengeId: widget.challenge!.id,
            ),
          ),
        );

        if (result == true && mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing reading: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Prioritize book.pageCount (from API/metadata) over _totalPages (from BookViewer)
    // BookViewer will set _totalPages even if book.pageCount is null (uses estimate)
    final totalPages = widget.book.pageCount ?? (_totalPages > 0 ? _totalPages : 200); // Default estimate
    // Calculate progress - always show something, even if approximate
    final progress = totalPages > 0 
        ? (_currentPage / totalPages).clamp(0.0, 1.0) 
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            onPressed: _isLoading ? null : _completeReading,
            tooltip: 'Complete Reading',
          ),
        ],
      ),
      body: Column(
        children: [
          // Countdown timer (if challenge active)
          if (widget.challenge != null && widget.challenge!.isActive)
            ExplodingBooksCountdownExpanded(challenge: widget.challenge!),

          // Progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.book.pageCount != null
                          ? 'Page $_currentPage / $totalPages'
                          : 'Page $_currentPage / ~$totalPages (approx)',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                ),
              ],
            ),
          ),

          // Book content
          Expanded(
            child: _isLoadingContent
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading book content...'),
                      ],
                    ),
                  )
                : _contentError != null || _bookContent == null
                    ? _buildBookNotAvailableView(theme, totalPages ?? 0)
                    : BookViewer(
                        book: widget.book,
                        content: _bookContent!,
                        initialPage: _currentPage,
                        onPageChanged: (page) {
                          _updateProgress(page);
                        },
                        onTotalPagesChanged: (totalPages) {
                          setState(() {
                            _totalPages = totalPages;
                          });
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookNotAvailableView(ThemeData theme, int totalPages) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Book Not Available Online',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ModernCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'Why isn\'t this book available?',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Many books are protected by copyright and cannot be downloaded for free. This includes most modern books published after 1928.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'What you can do:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildOptionTile(
                      icon: Icons.upload_file,
                      title: 'Upload Your Own Copy',
                      description: 'If you own this book, you can upload the EPUB or PDF file',
                      onTap: _uploadBookFile,
                    ),
                    const SizedBox(height: 8),
                    _buildOptionTile(
                      icon: Icons.library_books,
                      title: 'Try Public Domain Books',
                      description: 'Classics like Pride and Prejudice, Moby Dick, and more are available for free',
                      onTap: () {
                        Navigator.pop(context);
                        // Navigate to search with public domain filter
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Manual page tracking fallback
            Text(
              'You can still track your reading progress:',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _currentPage > 0
                      ? () => _updateProgress(_currentPage - 1)
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_currentPage',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: (totalPages == null || _currentPage < totalPages)
                      ? () => _updateProgress(_currentPage + 1)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadBookFile() async {
    // Show file picker dialog
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => UploadBookFileSheet(
        hub: widget.hub,
        book: widget.book,
        onUploaded: () {
          // Reload book content after upload
          _loadBookContent();
        },
      ),
    );
  }
}

