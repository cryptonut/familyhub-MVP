import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/educational_resource.dart';
import '../../utils/app_theme.dart';
import '../../core/services/logger_service.dart';
import '../../widgets/ui_components.dart';

/// Screen for viewing educational resources
class ResourceViewerScreen extends StatefulWidget {
  final EducationalResource resource;

  const ResourceViewerScreen({
    super.key,
    required this.resource,
  });

  @override
  State<ResourceViewerScreen> createState() => _ResourceViewerScreenState();
}

class _ResourceViewerScreenState extends State<ResourceViewerScreen> {
  String? _localFilePath;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadResource();
  }

  Future<void> _loadResource() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Handle different resource types
      if (widget.resource.type == ResourceType.link && widget.resource.url != null) {
        // For links, just open in browser
        final uri = Uri.parse(widget.resource.url!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          Navigator.pop(context); // Close viewer, browser opened
          return;
        } else {
          throw Exception('Could not launch URL: ${widget.resource.url}');
        }
      } else if (widget.resource.fileUrl != null) {
        // Download file for viewing
        final file = await _downloadFile(widget.resource.fileUrl!);
        if (file == null) {
          throw Exception('Failed to download file');
        }

        setState(() {
          _localFilePath = file.path;
          _isLoading = false;
        });
      } else {
        throw Exception('No URL or file available for this resource');
      }
    } catch (e, st) {
      Logger.error('Error loading resource', error: e, stackTrace: st, tag: 'ResourceViewerScreen');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<File?> _downloadFile(String url) async {
    try {
      Logger.info('Downloading resource from URL: $url', tag: 'ResourceViewerScreen');
      final dio = Dio();
      final appDir = await getApplicationDocumentsDirectory();
      final resourcesDir = Directory('${appDir.path}/resources');
      if (!await resourcesDir.exists()) {
        await resourcesDir.create(recursive: true);
      }

      // Generate filename from URL
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;
      final filePath = '${resourcesDir.path}/$fileName';

      // Download file
      await dio.download(url, filePath);
      Logger.info('Resource downloaded successfully to: $filePath', tag: 'ResourceViewerScreen');

      return File(filePath);
    } catch (e, st) {
      Logger.error('Error downloading resource file', error: e, stackTrace: st, tag: 'ResourceViewerScreen');
      rethrow;
    }
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                'Error loading resource',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              ElevatedButton(
                onPressed: _loadResource,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_localFilePath == null) {
      return const Center(child: Text('No file available'));
    }

    // Determine file type from extension
    final fileExtension = _localFilePath!.split('.').last.toLowerCase();

    // Handle PDFs
    if (fileExtension == 'pdf' || widget.resource.type == ResourceType.document) {
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
          }
        },
        onViewCreated: (PDFViewController pdfViewController) {
          // Controller available for future use
        },
      );
    }

    // Handle images
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(fileExtension) ||
        widget.resource.type == ResourceType.image) {
      return InteractiveViewer(
        child: Image.file(
          File(_localFilePath!),
          fit: BoxFit.contain,
        ),
      );
    }

    // Handle videos - try to open with external app
    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(fileExtension) ||
        widget.resource.type == ResourceType.video) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library, size: 64),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              'Video file',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            const Text('Tap to open in external player'),
            const SizedBox(height: AppTheme.spacingMD),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.file(_localFilePath!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open video file')),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Open Video'),
            ),
          ],
        ),
      );
    }

    // For other file types, try to open with external app
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file, size: 64),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            'Document file',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spacingSM),
          const Text('Tap to open in external app'),
          const SizedBox(height: AppTheme.spacingMD),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.file(_localFilePath!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open file')),
                );
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open File'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resource.title),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: Text(
                  'Page $_currentPage / $_totalPages',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
      body: _buildContent(),
    );
  }
}

