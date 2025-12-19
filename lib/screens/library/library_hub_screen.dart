import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/hub.dart';
import '../../models/book.dart';
import '../../models/exploding_book_challenge.dart';
import '../../services/book_service.dart';
import '../../services/exploding_books_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'book_detail_screen.dart';
import 'leaderboard_screen.dart';

class LibraryHubScreen extends StatefulWidget {
  final Hub hub;

  const LibraryHubScreen({super.key, required this.hub});

  @override
  State<LibraryHubScreen> createState() => _LibraryHubScreenState();
}

class _LibraryHubScreenState extends State<LibraryHubScreen> {
  final BookService _bookService = BookService();
  final ExplodingBooksService _explodingBooksService = ExplodingBooksService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Book> _hubBooks = [];
  List<Book> _searchResults = [];
  List<ExplodingBookChallenge> _activeChallenges = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadHubData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHubData() async {
    setState(() => _isLoading = true);
    try {
      final allBooks = await _bookService.getHubBooks(widget.hub.id, limit: 20);
      // Filter to only show available books (books that can be read in-app)
      final books = await _bookService.filterAvailableBooks(widget.hub.id, allBooks);
      
      final userId = _getCurrentUserId();
      final challenges = userId != null
          ? await _explodingBooksService.getUserChallenges(
              widget.hub.id,
              userId,
              activeOnly: true,
            )
          : <ExplodingBookChallenge>[];

      if (mounted) {
        setState(() {
          _hubBooks = books;
          _activeChallenges = challenges;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading library: $e')),
        );
      }
    }
  }

  String? _getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  Future<void> _searchBooks(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _bookService.searchBooks(query, limit: 20);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching books: $e')),
        );
      }
    }
  }

  Future<void> _addBookToLibrary(Book book) async {
    try {
      await _bookService.addBookToHub(widget.hub.id, book);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book added to library')),
        );
        await _loadHubData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding book: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hub.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LeaderboardScreen(hubId: widget.hub.id),
                ),
              );
            },
            tooltip: 'View Leaderboard',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for books...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchBooks('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: _searchBooks,
              onChanged: (value) {
                setState(() {});
                if (value.isEmpty) {
                  _searchBooks('');
                } else if (value.length >= 3) {
                  // Auto-search after 3 characters (debounced)
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted && _searchController.text == value && value.length >= 3) {
                      _searchBooks(value);
                    }
                  });
                }
              },
            ),
          ),

          // Content
          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildHubContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHubContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadHubData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Exploding Books Challenges
            if (_activeChallenges.isNotEmpty) ...[
              _buildSectionHeader('Active Challenges', Icons.timer),
              const SizedBox(height: AppTheme.spacingSM),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _activeChallenges.length,
                  itemBuilder: (context, index) {
                    final challenge = _activeChallenges[index];
                    return _buildChallengeCard(challenge);
                  },
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),
            ],

            // Featured/Popular Books (only show if we have available books)
            FutureBuilder<List<Book>>(
              future: _bookService.getPopularBooks(limit: 10).then(
                (books) => _bookService.filterAvailableBooks(widget.hub.id, books),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink(); // Don't show loading, just hide section
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink(); // Don't show section if no books
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Popular Books', Icons.trending_up),
                    const SizedBox(height: AppTheme.spacingSM),
                    _buildBookGrid(snapshot.data!),
                  ],
                );
              },
            ),
            const SizedBox(height: AppTheme.spacingLG),

            // Hub Library Books
            _buildSectionHeader('Library Books', Icons.library_books),
            const SizedBox(height: AppTheme.spacingSM),
            if (_hubBooks.isEmpty)
              const EmptyState(
                icon: Icons.library_books,
                title: 'No books in library',
                message: 'Search for books and add them to your library',
              )
            else
              _buildBookGrid(_hubBooks),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Searching for books...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No results found',
        message: 'Try searching for:\n• Pride and Prejudice\n• Moby Dick\n• Alice in Wonderland\n• Sherlock Holmes',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: AppTheme.spacingSM,
        mainAxisSpacing: AppTheme.spacingSM,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return _buildBookCard(book, showAddButton: true);
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(ExplodingBookChallenge challenge) {
    final timeRemaining = challenge.timeRemaining;
    final isUrgent = timeRemaining != null && timeRemaining.inHours < 24;

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: AppTheme.spacingSM),
      child: ModernCard(
        child: InkWell(
          onTap: () {
            // Navigate to challenge details or book
          },
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 16,
                      color: isUrgent ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        timeRemaining != null
                            ? '${timeRemaining.inDays}d ${timeRemaining.inHours % 24}h'
                            : 'Expired',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isUrgent ? Colors.red : Colors.orange,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Challenge Active',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookGrid(List<Book> books) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: AppTheme.spacingSM,
        mainAxisSpacing: AppTheme.spacingSM,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        return _buildBookCard(books[index]);
      },
    );
  }

  Widget _buildBookCard(Book book, {bool showAddButton = false}) {
    final isGutenberg = book.id.startsWith('gutenberg_');
    
    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookDetailScreen(
                hub: widget.hub,
                book: book,
              ),
            ),
          ).then((_) => _loadHubData());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover with beautiful gradient fallback
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (book.coverUrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: Image.network(
                          book.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildCoverPlaceholder(book, isGutenberg);
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return _buildCoverPlaceholder(book, isGutenberg);
                          },
                        ),
                      )
                    else
                      _buildCoverPlaceholder(book, isGutenberg),
                    // Availability badge for Project Gutenberg
                    if (isGutenberg)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'FREE',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Book info
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingSM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.authors.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      book.authors.join(', '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (book.averageRating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${book.averageRating!.toStringAsFixed(1)} (${book.ratingCount})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ] else if (showAddButton) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _addBookToLibrary(book),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add to Library'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(Book book, bool isGutenberg) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            ),
            if (isGutenberg) ...[
              const SizedBox(height: 4),
              Text(
                'Public Domain',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

