import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/shopping_service.dart';
import '../../widgets/toast_notification.dart';
import '../../core/services/logger_service.dart';
import '../../utils/app_theme.dart';

class ReceiptUploadScreen extends StatefulWidget {
  final String? listId;

  const ReceiptUploadScreen({super.key, this.listId});

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  final ShoppingService _shoppingService = ShoppingService();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e, st) {
      Logger.error('Error picking image', error: e, stackTrace: st, tag: 'ReceiptUploadScreen');
      if (mounted) {
        ToastNotification.error(context, 'Error picking image: $e');
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e, st) {
      Logger.error('Error taking photo', error: e, stackTrace: st, tag: 'ReceiptUploadScreen');
      if (mounted) {
        ToastNotification.error(context, 'Error taking photo: $e');
      }
    }
  }

  Future<void> _uploadReceipt() async {
    if (_selectedImage == null) {
      ToastNotification.warning(context, 'Please select an image first');
      return;
    }

    setState(() => _isUploading = true);

    try {
      await _shoppingService.uploadReceipt(
        listId: widget.listId,
        imageFile: _selectedImage!,
      );

      if (mounted) {
        ToastNotification.success(context, 'Receipt uploaded successfully');
        Navigator.pop(context);
      }
    } catch (e, st) {
      Logger.error('Error uploading receipt', error: e, stackTrace: st, tag: 'ReceiptUploadScreen');
      if (mounted) {
        ToastNotification.error(context, 'Error uploading receipt: $e');
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Receipt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview
            if (_selectedImage != null)
              Card(
                child: Column(
                  children: [
                    Image.file(
                      _selectedImage!,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _isUploading ? null : () {
                              setState(() => _selectedImage = null);
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text('Remove'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Card(
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No image selected',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choose from Gallery'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Upload button
            ElevatedButton.icon(
              onPressed: _selectedImage != null && !_isUploading ? _uploadReceipt : null,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: Text(_isUploading ? 'Uploading...' : 'Upload Receipt'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            // Info text
            Text(
              'Note: Receipt processing and OCR will be available in a future update.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
