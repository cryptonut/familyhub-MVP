import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../models/book.dart';
import '../utils/firestore_path_utils.dart';

/// Service for managing books from Open Library API
class BookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _openLibraryBaseUrl = 'https://openlibrary.org';
  static const String _openLibrarySearchUrl = '$_openLibraryBaseUrl/search.json';
  static const String _openLibraryWorksUrl = '$_openLibraryBaseUrl/works';
  static const String _openLibraryCoversUrl = 'https://covers.openlibrary.org/b';

  /// Search for books using Open Library API and Project Gutenberg
  /// Returns books immediately - Project Gutenberg books are guaranteed available
  Future<List<Book>> searchBooks(String query, {int limit = 20, int offset = 0}) async {
    try {
      final availableBooks = <Book>[];
      
      // PRIORITY 1: Search Project Gutenberg first (guaranteed available, fast)
      try {
        final pgUri = Uri.parse('https://gutendex.com/books/').replace(
          queryParameters: {
            'search': query,
            'languages': 'en',
            'limit': limit.toString(),
          },
        );

        Logger.info('Searching Project Gutenberg: $pgUri', tag: 'BookService');
        final pgResponse = await http.get(pgUri).timeout(const Duration(seconds: 8));
        
        if (pgResponse.statusCode == 200) {
          final pgData = json.decode(pgResponse.body) as Map<String, dynamic>;
          final pgResults = pgData['results'] as List? ?? [];

          for (var result in pgResults) {
            try {
              final resultData = result as Map<String, dynamic>;
              final formats = resultData['formats'] as Map<String, dynamic>?;
              
              // Only include if it has EPUB or HTML format (guaranteed available)
              if (formats != null && 
                  (formats.containsKey('application/epub+zip') || 
                   formats.containsKey('text/html'))) {
                final book = _parseProjectGutenbergBook(resultData);
                if (book != null) {
                  availableBooks.add(book);
                  if (availableBooks.length >= limit) {
                    Logger.info('Found ${availableBooks.length} Project Gutenberg books', tag: 'BookService');
                    return availableBooks; // Return immediately with guaranteed available books
                  }
                }
              }
            } catch (e) {
              Logger.warning('Error parsing Project Gutenberg book', error: e, tag: 'BookService');
            }
          }
        }
      } catch (e) {
        Logger.warning('Error searching Project Gutenberg', error: e, tag: 'BookService');
      }

      // PRIORITY 2: Search Open Library in parallel (if we need more results)
      if (availableBooks.length < limit) {
        try {
          final uri = Uri.parse(_openLibrarySearchUrl).replace(queryParameters: {
            'q': query,
            'limit': (limit - availableBooks.length).toString(),
            'offset': offset.toString(),
          });

          Logger.info('Searching Open Library: $uri', tag: 'BookService');
          final response = await http.get(uri).timeout(const Duration(seconds: 8));
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body) as Map<String, dynamic>;
            final docs = data['docs'] as List? ?? [];

            // For Open Library, we'll include them and check availability on-demand
            // This allows UI to show results immediately
            for (var doc in docs) {
              try {
                final book = _parseOpenLibraryDoc(doc as Map<String, dynamic>);
                if (book != null && availableBooks.length < limit) {
                  availableBooks.add(book);
                }
              } catch (e) {
                Logger.warning('Error parsing book from Open Library', error: e, tag: 'BookService');
              }
            }
          }
        } catch (e) {
          Logger.warning('Error searching Open Library', error: e, tag: 'BookService');
        }
      }

      Logger.info('Found ${availableBooks.length} books total', tag: 'BookService');
      return availableBooks;
    } on Exception catch (e, st) {
      Logger.error('Error searching books', error: e, stackTrace: st, tag: 'BookService');
      return [];
    }
  }

  /// Parse Project Gutenberg book from Gutendex API
  Book? _parseProjectGutenbergBook(Map<String, dynamic> data) {
    try {
      final title = data['title'] as String? ?? 'Unknown Title';
      final authors = <String>[];
      
      if (data['authors'] != null) {
        final authorsList = data['authors'] as List;
        for (var author in authorsList) {
          final authorData = author as Map<String, dynamic>;
          final name = authorData['name'] as String?;
          if (name != null) authors.add(name);
        }
      }

      // Use Gutenberg ID as book ID
      final gutenbergId = data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      // Get cover image if available from Gutendex
      // Gutendex doesn't provide cover images directly, but we can construct URLs
      // Project Gutenberg covers: https://www.gutenberg.org/cache/epub/{id}/pg{id}.cover.medium.jpg
      String? coverUrl;
      if (gutenbergId.isNotEmpty) {
        // Try Project Gutenberg cover URL format
        coverUrl = 'https://www.gutenberg.org/cache/epub/$gutenbergId/pg$gutenbergId.cover.medium.jpg';
      }
      
      // Try to get page count from Gutendex data
      // Gutendex doesn't directly provide page count, but we can estimate
      // based on download_count or use a reasonable default
      // For now, we'll leave it null and let the UI handle estimation
      // The actual page count should come from the EPUB file itself when loaded
      int? pageCount;
      
      // Check if there's any page-related data in the response
      // Some Project Gutenberg books have page info in metadata
      if (data.containsKey('download_count')) {
        // Very rough estimate: assume ~250 words per page, but this is unreliable
        // Better to get actual count from EPUB when loaded
        pageCount = null; // Will be determined from EPUB file
      }
      
      return Book(
        id: 'gutenberg_$gutenbergId',
        title: title,
        authors: authors,
        description: data['subjects'] != null 
            ? (data['subjects'] as List).take(3).join(', ')
            : null,
        publishDate: null,
        coverUrl: coverUrl,
        pageCount: pageCount, // Will be updated when EPUB is loaded
        isbn: null,
        olid: gutenbergId,
        averageRating: null,
        ratingCount: 0,
      );
    } catch (e) {
      Logger.warning('Error parsing Project Gutenberg book', error: e, tag: 'BookService');
      return null;
    }
  }

  /// Get book details by Open Library ID (OLID)
  Future<Book?> getBookDetails(String olid) async {
    try {
      // Remove /works/ prefix if present
      final cleanOlid = olid.replaceAll('/works/', '').replaceAll('OL', '');
      final uri = Uri.parse('$_openLibraryWorksUrl/$cleanOlid.json');

      final response = await http.get(uri);
      
      if (response.statusCode != 200) {
        Logger.warning('Open Library API error: ${response.statusCode}', tag: 'BookService');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return _parseOpenLibraryWork(data, olid: olid);
    } on Exception catch (e, st) {
      Logger.error('Error getting book details', error: e, stackTrace: st, tag: 'BookService');
      return null;
    }
  }

  /// Get book cover URL
  String? getBookCoverUrl(String? coverId, {String size = 'M'}) {
    if (coverId == null) return null;
    
    // Size: S (small), M (medium), L (large)
    // Format: https://covers.openlibrary.org/b/{key}/{value}-{size}.jpg
    // For cover_id: https://covers.openlibrary.org/b/id/{coverId}-{size}.jpg
    return '$_openLibraryCoversUrl/id/$coverId-$size.jpg';
  }

  /// Get popular/trending books - ONLY returns books with available content
  Future<List<Book>> getPopularBooks({int limit = 20}) async {
    try {
      // Get popular public domain books from Project Gutenberg
      // These are guaranteed to be available
      final popularTitles = [
        'Pride and Prejudice',
        'Moby Dick',
        'Alice in Wonderland',
        'The Adventures of Sherlock Holmes',
        'Dracula',
        'Frankenstein',
        'The Picture of Dorian Gray',
        'The Great Gatsby',
        'Jane Eyre',
        'Wuthering Heights',
        'The Count of Monte Cristo',
        'Les Misérables',
        'War and Peace',
        'Anna Karenina',
        'The Brothers Karamazov',
        'Crime and Punishment',
        'Don Quixote',
        'The Odyssey',
        'The Iliad',
        'The Divine Comedy',
      ];

      final availableBooks = <Book>[];
      
      // Search for each popular title and verify availability
      for (final title in popularTitles.take(limit * 2)) {
        try {
          // Search Project Gutenberg first (faster, guaranteed available)
          final pgUri = Uri.parse('https://gutendex.com/books/').replace(
            queryParameters: {
              'search': title,
              'languages': 'en',
              'limit': '1',
            },
          );

          final pgResponse = await http.get(pgUri).timeout(const Duration(seconds: 5));
          
          if (pgResponse.statusCode == 200) {
            final pgData = json.decode(pgResponse.body) as Map<String, dynamic>;
            final pgResults = pgData['results'] as List? ?? [];

            if (pgResults.isNotEmpty) {
              final resultData = pgResults.first as Map<String, dynamic>;
              final formats = resultData['formats'] as Map<String, dynamic>?;
              
              if (formats != null && 
                  (formats.containsKey('application/epub+zip') || 
                   formats.containsKey('text/html'))) {
                final book = _parseProjectGutenbergBook(resultData);
                if (book != null) {
                  availableBooks.add(book);
                  if (availableBooks.length >= limit) break;
                }
              }
            }
          }
        } catch (e) {
          Logger.warning('Error getting popular book "$title"', error: e, tag: 'BookService');
          continue;
        }
      }

      Logger.info('Found ${availableBooks.length} popular available books', tag: 'BookService');
      return availableBooks;
    } on Exception catch (e, st) {
      Logger.error('Error getting popular books', error: e, stackTrace: st, tag: 'BookService');
      return [];
    }
  }

  /// Sanitize book ID for Firestore (remove slashes and invalid characters)
  static String sanitizeBookId(String bookId) {
    // Replace slashes and other invalid characters with underscores
    return bookId.replaceAll('/', '_').replaceAll('\\', '_');
  }

  /// Add book to hub library (cache in Firestore)
  Future<void> addBookToHub(String hubId, Book book) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final bookData = book.toJson();
      bookData['addedAt'] = DateTime.now().toIso8601String();
      bookData['addedBy'] = userId;

      // CRITICAL FIX: Remove pageCount if it's the old default (300) for Project Gutenberg books
      // Project Gutenberg books don't have page counts from API
      if (book.id.startsWith('gutenberg_') && bookData['pageCount'] == 300) {
        bookData['pageCount'] = null;
        Logger.info('Removed invalid pageCount: 300 for Project Gutenberg book ${book.id}', tag: 'BookService');
      }

      // Sanitize book ID for Firestore document ID
      final sanitizedId = sanitizeBookId(book.id);

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedId)
          .set(bookData, SetOptions(merge: true));
    } catch (e, st) {
      Logger.error('Error adding book to hub', error: e, stackTrace: st, tag: 'BookService');
      rethrow;
    }
  }

  /// Get books from hub library
  Future<List<Book>> getHubBooks(String hubId, {int? limit}) async {
    try {
      var query = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .orderBy('addedAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final books = snapshot.docs
          .map((doc) {
            final bookData = doc.data();
            final book = Book.fromJson({'id': doc.id, ...bookData});
            
            // CRITICAL FIX: If this is a Project Gutenberg book and has pageCount: 300 (old default),
            // set it to null and update Firestore to fix the data
            if (book.id.startsWith('gutenberg_') && book.pageCount == 300) {
              // Update Firestore to remove the invalid pageCount
              final sanitizedId = sanitizeBookId(book.id);
              _firestore
                  .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
                  .doc(sanitizedId)
                  .update({'pageCount': null})
                  .catchError((e) {
                    Logger.warning('Failed to update pageCount for book ${book.id}', error: e, tag: 'BookService');
                  });
              return book.copyWith(pageCount: null);
            }
            
            return book;
          })
          .toList();
      
      return books;
    } catch (e, st) {
      Logger.error('Error getting hub books', error: e, stackTrace: st, tag: 'BookService');
      return [];
    }
  }

  /// Get book from hub library by ID
  Future<Book?> getHubBook(String hubId, String bookId) async {
    try {
      // Sanitize book ID for Firestore document ID
      final sanitizedId = sanitizeBookId(bookId);

      final doc = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedId)
          .get();

      if (!doc.exists) return null;

      final bookData = doc.data()!;
      final book = Book.fromJson({'id': doc.id, ...bookData});
      
      // CRITICAL FIX: If this is a Project Gutenberg book and has pageCount: 300 (old default),
      // set it to null and update Firestore to fix the data
      if (book.id.startsWith('gutenberg_') && book.pageCount == 300) {
        // Update Firestore to remove the invalid pageCount
        final sanitizedId = sanitizeBookId(book.id);
        _firestore
            .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
            .doc(sanitizedId)
            .update({'pageCount': null})
            .catchError((e) {
              Logger.warning('Failed to update pageCount for book ${book.id}', error: e, tag: 'BookService');
            });
        return book.copyWith(pageCount: null);
      }
      
      return book;
    } catch (e, st) {
      Logger.error('Error getting hub book', error: e, stackTrace: st, tag: 'BookService');
      return null;
    }
  }

  /// Parse Open Library search result document
  Book? _parseOpenLibraryDoc(Map<String, dynamic> doc) {
    try {
      final title = doc['title'] as String? ?? 'Unknown Title';
      final authors = (doc['author_name'] as List?)?.map((a) => a.toString()).toList() ?? [];
      final olid = doc['key'] as String? ?? '';
      final coverId = doc['cover_i'] as int?;
      final isbn = (doc['isbn'] as List?)?.isNotEmpty ?? false
          ? (doc['isbn'] as List).first.toString()
          : null;
      final publishYear = doc['first_publish_year'] as int?;
      final pageCount = doc['number_of_pages_median'] as int?;

      final coverUrl = coverId != null ? getBookCoverUrl(coverId.toString()) : null;

      DateTime? publishDate;
      if (publishYear != null) {
        publishDate = DateTime(publishYear);
      }

      // Clean OLID (remove /works/ prefix)
      final cleanOlid = olid.replaceAll('/works/', '').replaceAll('OL', '');

      return Book(
        id: olid.isNotEmpty ? olid : DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        authors: authors,
        description: doc['first_sentence'] as String?,
        publishDate: publishDate,
        coverUrl: coverUrl,
        pageCount: pageCount,
        isbn: isbn,
        olid: cleanOlid,
        averageRating: null,
        ratingCount: 0,
      );
    } catch (e) {
      Logger.warning('Error parsing Open Library doc', error: e, tag: 'BookService');
      return null;
    }
  }

  /// Parse Open Library work (detailed book info)
  Book? _parseOpenLibraryWork(Map<String, dynamic> work, {String? olid}) {
    try {
      final title = work['title'] as String? ?? 'Unknown Title';
      final authors = <String>[];
      
      if (work['authors'] != null) {
        final authorsList = work['authors'] as List;
        for (final author in authorsList) {
          if (author is Map) {
            final name = author['name'] as String?;
            if (name != null) authors.add(name);
          }
        }
      }

      final description = work['description'] is String
          ? work['description'] as String
          : (work['description'] is Map
              ? (work['description'] as Map)['value'] as String?
              : null);

      final coverId = work['covers'] != null && (work['covers'] as List).isNotEmpty
          ? (work['covers'] as List).first.toString()
          : null;

      final coverUrl = coverId != null ? getBookCoverUrl(coverId) : null;

      final isbn = work['isbn_13'] != null && (work['isbn_13'] as List).isNotEmpty
          ? (work['isbn_13'] as List).first.toString()
          : (work['isbn_10'] != null && (work['isbn_10'] as List).isNotEmpty
              ? (work['isbn_10'] as List).first.toString()
              : null);

      final publishDate = work['first_publish_date'] != null
          ? DateTime.tryParse(work['first_publish_date'] as String)
          : null;

      final pageCount = work['number_of_pages'] as int?;

      final workKey = work['key'] as String? ?? olid ?? '';
      final cleanOlid = workKey.replaceAll('/works/', '').replaceAll('OL', '');

      return Book(
        id: workKey.isNotEmpty ? workKey : DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        authors: authors,
        description: description,
        publishDate: publishDate,
        coverUrl: coverUrl,
        pageCount: pageCount,
        isbn: isbn,
        olid: cleanOlid,
        averageRating: null,
        ratingCount: 0,
      );
    } catch (e) {
      Logger.warning('Error parsing Open Library work', error: e, tag: 'BookService');
      return null;
    }
  }

  /// Get book content URL from Archive.org or Project Gutenberg
  /// Returns EPUB or PDF URL if available
  Future<BookContent?> getBookContentUrl(Book book) async {
    try {
      // Check if this is a Project Gutenberg book first (faster)
      if (book.id.startsWith('gutenberg_')) {
        final gutenbergId = book.id.replaceAll('gutenberg_', '');
        if (gutenbergId.isNotEmpty) {
          // This is a Project Gutenberg book
          final pgUri = Uri.parse('https://gutendex.com/books/$gutenbergId/');
          try {
            final pgResponse = await http.get(pgUri).timeout(const Duration(seconds: 5));
            if (pgResponse.statusCode == 200) {
              final pgData = json.decode(pgResponse.body) as Map<String, dynamic>;
              final formats = pgData['formats'] as Map<String, dynamic>?;
              
              if (formats != null) {
                // Prefer EPUB
                final epubUrl = formats['application/epub+zip'] as String?;
                if (epubUrl != null && epubUrl.isNotEmpty) {
                  Logger.info('Found Project Gutenberg EPUB: $epubUrl', tag: 'BookService');
                  return BookContent(url: epubUrl, format: BookFormat.epub);
                }
                
                // Fallback to HTML
                final htmlUrl = formats['text/html'] as String?;
                if (htmlUrl != null && htmlUrl.isNotEmpty) {
                  Logger.info('Found Project Gutenberg HTML: $htmlUrl', tag: 'BookService');
                  return BookContent(url: htmlUrl, format: BookFormat.epub);
                }
              }
            }
          } catch (e) {
            Logger.warning('Error fetching Project Gutenberg book details', error: e, tag: 'BookService');
          }
        }
      }

      // Method 1: Use Open Library work API to get Archive.org identifier
      String? workKey = book.id;
      if (workKey.contains('/works/')) {
        workKey = workKey.replaceAll('/works/', '');
      }
      
      if (workKey.isNotEmpty) {
        // Get work details from Open Library
        final workUrl = '$_openLibraryWorksUrl/$workKey.json';
        Logger.info('Fetching work details from: $workUrl', tag: 'BookService');
        
        try {
          final workResponse = await http.get(Uri.parse(workUrl));
          if (workResponse.statusCode == 200) {
            final workData = json.decode(workResponse.body) as Map<String, dynamic>;
            
            // Check for Archive.org identifiers in various fields
            final identifiers = workData['identifiers'] as Map<String, dynamic>?;
            if (identifiers != null) {
              // Check for Internet Archive identifier
              final iaIds = identifiers['internet_archive'] as List?;
              if (iaIds != null && iaIds.isNotEmpty) {
                final iaId = iaIds.first.toString();
                Logger.info('Found Archive.org ID: $iaId', tag: 'BookService');
                
                // Try EPUB first
                final epubUrl = 'https://archive.org/download/$iaId/$iaId.epub';
                final epubResponse = await http.head(Uri.parse(epubUrl));
                if (epubResponse.statusCode == 200) {
                  Logger.info('Found EPUB at: $epubUrl', tag: 'BookService');
                  return BookContent(url: epubUrl, format: BookFormat.epub);
                }
                
                // Try PDF
                final pdfUrl = 'https://archive.org/download/$iaId/$iaId.pdf';
                final pdfResponse = await http.head(Uri.parse(pdfUrl));
                if (pdfResponse.statusCode == 200) {
                  Logger.info('Found PDF at: $pdfUrl', tag: 'BookService');
                  return BookContent(url: pdfUrl, format: BookFormat.pdf);
                }
              }
            }
            
            // Check for ia_loaded_id field (another way Archive.org IDs are stored)
            final iaLoadedId = workData['ia_loaded_id'] as List?;
            if (iaLoadedId != null && iaLoadedId.isNotEmpty) {
              final iaId = iaLoadedId.first.toString();
              Logger.info('Found Archive.org ID (ia_loaded_id): $iaId', tag: 'BookService');
              
              final epubUrl = 'https://archive.org/download/$iaId/$iaId.epub';
              final epubResponse = await http.head(Uri.parse(epubUrl));
              if (epubResponse.statusCode == 200) {
                return BookContent(url: epubUrl, format: BookFormat.epub);
              }
            }
          }
        } catch (e) {
          Logger.warning('Error fetching work details', error: e, tag: 'BookService');
        }
      }

      // Method 2: Try using ISBN with Open Library Read API
      if (book.isbn != null && book.isbn!.isNotEmpty) {
        final readApiUrl = 'https://openlibrary.org/api/volumes/brief/isbn/${book.isbn}.json';
        Logger.info('Trying ISBN API: $readApiUrl', tag: 'BookService');
        
        try {
          final response = await http.get(Uri.parse(readApiUrl));
          if (response.statusCode == 200) {
            final data = json.decode(response.body) as Map<String, dynamic>;
            
            // The API returns data in a nested structure
            final records = data['records'] as Map<String, dynamic>?;
            if (records != null && records.isNotEmpty) {
              final firstRecord = records.values.first as Map<String, dynamic>;
              
              // Check for Archive.org identifier
              final identifiers = firstRecord['identifiers'] as Map<String, dynamic>?;
              if (identifiers != null) {
                final iaIds = identifiers['internet_archive'] as List?;
                if (iaIds != null && iaIds.isNotEmpty) {
                  final iaId = iaIds.first.toString();
                  final epubUrl = 'https://archive.org/download/$iaId/$iaId.epub';
                  final epubResponse = await http.head(Uri.parse(epubUrl));
                  if (epubResponse.statusCode == 200) {
                    Logger.info('Found EPUB via ISBN: $epubUrl', tag: 'BookService');
                    return BookContent(url: epubUrl, format: BookFormat.epub);
                  }
                }
              }
            }
          }
        } catch (e) {
          Logger.warning('Error with ISBN API', error: e, tag: 'BookService');
        }
      }

      // Method 3: Try Project Gutenberg for public domain books
      final pgContent = await _tryProjectGutenberg(book);
      if (pgContent != null) {
        Logger.info('Found book on Project Gutenberg', tag: 'BookService');
        return pgContent;
      }

      Logger.warning('No book content found for: ${book.title}', tag: 'BookService');
      return null;
    } on Exception catch (e, st) {
      Logger.error('Error getting book content URL', error: e, stackTrace: st, tag: 'BookService');
      return null;
    }
  }

  /// Try to find book on Project Gutenberg
  Future<BookContent?> _tryProjectGutenberg(Book book) async {
    try {
      // Project Gutenberg catalog API
      // Search by title and author
      final searchQuery = '${book.title} ${book.authors.isNotEmpty ? book.authors.first : ''}'.trim();
      final catalogUrl = Uri.parse('https://gutendex.com/books/').replace(
        queryParameters: {
          'search': searchQuery,
          'languages': 'en',
        },
      );

      Logger.info('Searching Project Gutenberg: $catalogUrl', tag: 'BookService');
      final response = await http.get(catalogUrl);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        
        if (results != null && results.isNotEmpty) {
          // Find best match by title similarity
          for (final result in results) {
            final resultData = result as Map<String, dynamic>;
            final resultTitle = (resultData['title'] as String? ?? '').toLowerCase();
            final bookTitle = book.title.toLowerCase();
            
            // Simple title matching (can be improved)
            if (resultTitle.contains(bookTitle.substring(0, bookTitle.length > 10 ? 10 : bookTitle.length)) ||
                bookTitle.contains(resultTitle.substring(0, resultTitle.length > 10 ? 10 : resultTitle.length))) {
              
              // Get formats
              final formats = resultData['formats'] as Map<String, dynamic>?;
              if (formats != null) {
                // Prefer EPUB
                final epubUrl = formats['application/epub+zip'] as String?;
                if (epubUrl != null && epubUrl.isNotEmpty) {
                  Logger.info('Found Project Gutenberg EPUB: $epubUrl', tag: 'BookService');
                  return BookContent(url: epubUrl, format: BookFormat.epub);
                }
                
                // Fallback to text/HTML
                final htmlUrl = formats['text/html'] as String?;
                if (htmlUrl != null && htmlUrl.isNotEmpty) {
                  Logger.info('Found Project Gutenberg HTML: $htmlUrl', tag: 'BookService');
                  // Note: HTML can be converted to EPUB or displayed in WebView
                  return BookContent(url: htmlUrl, format: BookFormat.epub);
                }
              }
            }
          }
        }
      }
      
      return null;
    } catch (e, st) {
      Logger.warning('Error searching Project Gutenberg', error: e, stackTrace: st, tag: 'BookService');
      return null;
    }
  }

  /// Check if user has uploaded a book file for this book
  Future<BookContent?> getUserUploadedBook(String hubId, String bookId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      // Check Firestore for user-uploaded book references
      final sanitizedBookId = sanitizeBookId(bookId);
      final uploadsSnapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .collection('uploads')
          .where('uploadedBy', isEqualTo: userId)
          .orderBy('uploadedAt', descending: true)
          .limit(1)
          .get();

      if (uploadsSnapshot.docs.isNotEmpty) {
        final uploadData = uploadsSnapshot.docs.first.data();
        final downloadUrl = uploadData['downloadUrl'] as String?;
        final formatStr = uploadData['format'] as String?;
        
        if (downloadUrl != null && formatStr != null) {
          final format = formatStr == 'epub' ? BookFormat.epub : BookFormat.pdf;
          Logger.info('Found user-uploaded book: $downloadUrl', tag: 'BookService');
          return BookContent(url: downloadUrl, format: format);
        }
      }

      return null;
    } catch (e, st) {
      Logger.warning('Error checking user uploaded book', error: e, stackTrace: st, tag: 'BookService');
      return null;
    }
  }

  /// Save user-uploaded book reference to Firestore
  Future<void> saveUserUploadedBook(
    String hubId,
    String bookId,
    String downloadUrl,
    BookFormat format,
  ) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final sanitizedBookId = sanitizeBookId(bookId);
      final uploadId = DateTime.now().millisecondsSinceEpoch.toString();

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'books'))
          .doc(sanitizedBookId)
          .collection('uploads')
          .doc(uploadId)
          .set({
        'downloadUrl': downloadUrl,
        'format': format == BookFormat.epub ? 'epub' : 'pdf',
        'uploadedBy': userId,
        'uploadedAt': DateTime.now().toIso8601String(),
        'bookId': bookId,
      });

      Logger.info('Saved user-uploaded book reference', tag: 'BookService');
    } catch (e, st) {
      Logger.error('Error saving user uploaded book', error: e, stackTrace: st, tag: 'BookService');
      rethrow;
    }
  }
}

/// Book content information
class BookContent {
  final String url;
  final BookFormat format;

  BookContent({
    required this.url,
    required this.format,
  });
}

/// Book format enum
enum BookFormat {
  epub,
  pdf,
}

