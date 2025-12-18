import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/hub.dart';
import '../../models/book.dart';
import '../../services/book_service.dart';
import '../../widgets/ui_components.dart';
import '../../core/services/logger_service.dart';

/// Bottom sheet for uploading EPUB/PDF files
class UploadBookFileSheet extends StatefulWidget {
  final Hub hub;
  final Book book;
  final VoidCallback onUploaded;

  const UploadBookFileSheet({
    super.key,
    required this.hub,
    required this.book,
    required this.onUploaded,
  });

  @override
  State<UploadBookFileSheet> createState() => _UploadBookFileSheetState();
}

class _UploadBookFileSheetState extends State<UploadBookFileSheet> {
  final BookService _bookService = BookService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _error;
  String? _selectedFilePath;
  String? _selectedFileName;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error picking file: $e';
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFilePath == null) {
      setState(() {
        _error = 'Please select a file first';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
      _uploadProgress = 0.0;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final file = File(_selectedFilePath!);
      final fileExtension = _selectedFileName!.split('.').last.toLowerCase();
      final sanitizedBookId = BookService.sanitizeBookId(widget.book.id);
      
      // Upload to Firebase Storage
      final storagePath = 'hubs/${widget.hub.id}/books/$sanitizedBookId/uploads/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final storageRef = _storage.ref(storagePath);
      
      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: fileExtension == 'epub' 
              ? 'application/epub+zip' 
              : 'application/pdf',
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
            'bookTitle': widget.book.title,
            'bookId': widget.book.id,
          },
        ),
      );

      // Track upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        if (mounted) {
          setState(() {
            _uploadProgress = progress;
          });
        }
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save upload reference to Firestore
      await _bookService.saveUserUploadedBook(
        widget.hub.id,
        widget.book.id,
        downloadUrl,
        fileExtension == 'epub' ? BookFormat.epub : BookFormat.pdf,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book uploaded successfully!')),
        );
        widget.onUploaded();
        Navigator.pop(context);
      }
    } catch (e, st) {
      Logger.error('Error uploading book file', error: e, stackTrace: st, tag: 'UploadBookFileSheet');
      if (mounted) {
        setState(() {
          _error = 'Failed to upload: ${e.toString()}';
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Upload Book File',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Upload your own EPUB or PDF file for "${widget.book.title}"',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            
            // File selection
            if (_selectedFileName == null)
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Select EPUB or PDF File'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              )
            else
              ModernCard(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        _selectedFileName!.endsWith('.epub') 
                            ? Icons.book 
                            : Icons.picture_as_pdf,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFileName!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Ready to upload',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedFileName = null;
                            _selectedFilePath = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Upload progress
            if (_isUploading) ...[
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 8),
              Text(
                'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ],
            
            // Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Upload button
            if (_selectedFileName != null && !_isUploading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploadFile,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload Book'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

