import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

import '../core/services/logger_service.dart';
import '../models/book.dart';
import '../services/book_service.dart';

/// Widget for displaying EPUB and PDF books
/// Uses flutter_epub_viewer for EPUB (native implementation)
/// Uses flutter_pdfview for PDF
class BookViewer extends StatefulWidget {
  const BookViewer({
    super.key,
    required this.book,
    required this.content,
    this.initialPage,
    this.onPageChanged,
    this.onTotalPagesChanged,
  });

  final Book book;
  final BookContent content;
  final int? initialPage;
  final Function(int page)? onPageChanged;
  final Function(int totalPages)? onTotalPagesChanged;

  @override
  State<BookViewer> createState() => _BookViewerState();
}

class _BookViewerState extends State<BookViewer> {
  String? _localFilePath;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;
  late EpubController _epubController;
  List<dynamic>? _chapters; // Store chapters list (spine entries) - these are the real navigation units
  int _currentChapterIndex = 0; // Track current chapter index (0-based)
  String? _previousLocation; // Track previous location string to detect direction
  DateTime? _lastRelocationTime; // Debounce rapid relocations

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage ?? 1; // Start at page 1, not 0
    _currentChapterIndex = 0; // Chapter index starts at 0
    _epubController = EpubController();
    _loadBook();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Logger.info('Starting book download from: ${widget.content.url}', tag: 'BookViewer');
      // Download book to local storage
      final file = await _downloadBook(widget.content.url);
      
      if (file == null) {
        throw Exception('Failed to download book');
      }

      Logger.info('Book downloaded successfully to: ${file.path}', tag: 'BookViewer');
      
      setState(() {
        _localFilePath = file.path;
        _isLoading = false;
      });
    } on Exception catch (e, st) {
      Logger.error('Error loading book', error: e, stackTrace: st, tag: 'BookViewer');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<File?> _downloadBook(String url) async {
    try {
      Logger.info('Downloading book from URL: $url', tag: 'BookViewer');
      final dio = Dio();
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      // Generate filename from URL
      final uri = Uri.parse(url);
      final filename = uri.pathSegments.last;
      final ext = widget.content.format == BookFormat.epub ? 'epub' : 'pdf';
      final bookId = widget.book.id.replaceAll('/', '_').replaceAll('gutenberg_', '');
      final finalFilename = filename.isNotEmpty && filename.contains('.') 
          ? filename 
          : '$bookId.$ext';
      final file = File('${booksDir.path}/$finalFilename');
      
      Logger.info('Target file path: ${file.path}', tag: 'BookViewer');
      
      // Download if file doesn't exist
      if (!await file.exists()) {
        Logger.info('File does not exist, starting download...', tag: 'BookViewer');
        await dio.download(
          url, 
          file.path,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final progress = (received / total * 100).toStringAsFixed(0);
              Logger.info('Download progress: $progress%', tag: 'BookViewer');
            }
          },
        );
        Logger.info('Download completed', tag: 'BookViewer');
      } else {
        Logger.info('File already exists, skipping download', tag: 'BookViewer');
      }
      
      // Verify file exists and has content
      if (await file.exists()) {
        final fileSize = await file.length();
        Logger.info('File verified: $fileSize bytes', tag: 'BookViewer');
        if (fileSize == 0) {
          throw Exception('Downloaded file is empty');
        }
      } else {
        throw Exception('File was not created');
      }
      
      return file;
    } on Exception catch (e, st) {
      Logger.error('Error downloading book from $url', error: e, stackTrace: st, tag: 'BookViewer');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading book...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              Text(
                'Error loading book',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBook,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_localFilePath == null) {
      return const Center(child: Text('No book file available'));
    }

    // Display based on format
    if (widget.content.format == BookFormat.epub) {
      // Wrap in GestureDetector to track swipes directly
      // This is more reliable than relying on onRelocated which may not fire on every swipe
      return GestureDetector(
        onHorizontalDragEnd: (details) {
          // Track swipe direction
          if (details.primaryVelocity != null) {
            setState(() {
              if (details.primaryVelocity! < -500) {
                // Swiped left = forward (next page/chapter)
                if (_chapters != null && _chapters!.isNotEmpty) {
                  if (_currentChapterIndex < _chapters!.length - 1) {
                    _currentChapterIndex++;
                    _currentPage = _currentChapterIndex + 1;
                    widget.onPageChanged?.call(_currentPage);
                    Logger.info('Swipe forward - chapter: ${_currentChapterIndex + 1} / ${_chapters!.length}', tag: 'BookViewer');
                  }
                } else {
                  if (_totalPages > 0) {
                    _currentPage = (_currentPage + 1).clamp(1, _totalPages);
                  } else {
                    _currentPage++;
                  }
                  widget.onPageChanged?.call(_currentPage);
                  Logger.info('Swipe forward - page: $_currentPage', tag: 'BookViewer');
                }
              } else if (details.primaryVelocity! > 500) {
                // Swiped right = backward (previous page/chapter)
                if (_chapters != null && _chapters!.isNotEmpty) {
                  if (_currentChapterIndex > 0) {
                    _currentChapterIndex--;
                    _currentPage = _currentChapterIndex + 1;
                    widget.onPageChanged?.call(_currentPage);
                    Logger.info('Swipe backward - chapter: ${_currentChapterIndex + 1} / ${_chapters!.length}', tag: 'BookViewer');
                  }
                } else {
                  if (_currentPage > 1) {
                    _currentPage--;
                    widget.onPageChanged?.call(_currentPage);
                    Logger.info('Swipe backward - page: $_currentPage', tag: 'BookViewer');
                  }
                }
              }
            });
          }
        },
        child: EpubViewer(
        epubSource: EpubSource.fromFile(File(_localFilePath!)),
        epubController: _epubController,
        displaySettings: EpubDisplaySettings(
          flow: EpubFlow.paginated,
          snap: true,
        ),
        onChaptersLoaded: (chapters) {
          Logger.info('EPUB chapters (spine entries) loaded: ${chapters.length}', tag: 'BookViewer');
          // Store chapters list - these are the spine entries (real navigation units)
          // Each chapter = one swipe/navigation unit
          setState(() {
            _chapters = chapters;
            // If we don't have page count from metadata, use chapter count
            // This is more accurate than a random estimate
            if (widget.book.pageCount == null || widget.book.pageCount == 0) {
              _totalPages = chapters.length;
              widget.onTotalPagesChanged?.call(_totalPages);
              Logger.info('Using chapter count as total navigation units: $_totalPages', tag: 'BookViewer');
            }
          });
        },
        onEpubLoaded: () {
          Logger.info('EPUB loaded successfully', tag: 'BookViewer');
          // CRITICAL: Use book's pageCount from metadata (most accurate source)
          // This comes from Open Library API or Project Gutenberg metadata
          // DO NOT use chapter count as page count - they're completely different!
          if (widget.book.pageCount != null && widget.book.pageCount! > 0) {
            setState(() {
              _totalPages = widget.book.pageCount!;
              widget.onTotalPagesChanged?.call(_totalPages);
              Logger.info('Set total pages from metadata: $_totalPages', tag: 'BookViewer');
            });
          } else {
            // If no page count available, we'll still track navigation
            // Use a default estimate so progress can be shown
            // This is approximate but better than nothing
            setState(() {
              _totalPages = 200; // Default estimate for progress tracking
              widget.onTotalPagesChanged?.call(_totalPages);
              Logger.info('No page count available - using default estimate: $_totalPages', tag: 'BookViewer');
            });
          }
        },
        onRelocated: (relocationData) {
          // Log relocation for debugging, but use gesture detection for page tracking
          Logger.info('EPUB relocated to: ${relocationData.toString()}', tag: 'BookViewer');
        },
        onTextSelected: (selection) {
          Logger.info('Text selected', tag: 'BookViewer');
        },
        ),
      );
    } else if (widget.content.format == BookFormat.pdf) {
      return PDFView(
        filePath: _localFilePath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        defaultPage: _currentPage,
        fitPolicy: FitPolicy.BOTH,
        preventLinkNavigation: false,
        onRender: (pages) {
          setState(() {
            _totalPages = pages ?? 0;
            widget.onTotalPagesChanged?.call(_totalPages);
          });
        },
        onError: (error) {
          setState(() {
            _error = error.toString();
          });
        },
        onPageChanged: (int? page, int? total) {
          if (page != null) {
            setState(() {
              _currentPage = page;
            });
            widget.onPageChanged?.call(page);
          }
        },
        onViewCreated: (PDFViewController pdfViewController) {
          // Controller available for future use
        },
      );
    }

    return const Center(child: Text('Unsupported book format'));
  }
}
