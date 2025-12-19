import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/logger_service.dart';
import '../../services/shopping_service.dart';
import '../../widgets/toast_notification.dart';
import '../../utils/app_theme.dart';

class ReceiptUploadScreen extends StatefulWidget {
  final String listId;

  const ReceiptUploadScreen({super.key, required this.listId});

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  final ShoppingService _shoppingService = ShoppingService();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;

  @override
  void dispose() {
    // Clean up the selected image file reference
    _selectedImage = null;
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e, st) {
      Logger.error('Error picking image', error: e, stackTrace: st, tag: 'ReceiptUploadScreen');
      if (mounted) {
        ToastNotification.error(context, 'Failed to pick image');
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
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e, st) {
      Logger.error('Error taking photo', error: e, stackTrace: st, tag: 'ReceiptUploadScreen');
      if (mounted) {
        ToastNotification.error(context, 'Failed to take photo');
      }
    }
  }

  Future<void> _uploadReceipt() async {
    if (_selectedImage == null) {
      ToastNotification.error(context, 'Please select an image first');
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
        ToastNotification.error(context, 'Failed to upload receipt');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return PopScope(
      canPop: !_isUploading,
      onPopInvoked: (didPop) {
        if (!didPop && _isUploading) {
          // Show warning if trying to go back during upload
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait for upload to complete'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Upload Receipt'),
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null) ...[
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _selectedImage != null && _selectedImage!.existsSync()
                      ? Image.file(
                          _selectedImage!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Error loading image',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Text('Image file not found'),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No image selected',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isUploading || _selectedImage == null ? null : _uploadReceipt,
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upload Receipt'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

