import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../services/photo_service.dart';
import '../../models/family_photo.dart';

class UploadPhotoDialog extends StatefulWidget {
  final String familyId;
  final String? albumId;

  const UploadPhotoDialog({
    super.key,
    required this.familyId,
    this.albumId,
  });

  @override
  State<UploadPhotoDialog> createState() => _UploadPhotoDialogState();
}

class _UploadPhotoDialogState extends State<UploadPhotoDialog> {
  final PhotoService _photoService = PhotoService();
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _selectedImage;
  Uint8List? _selectedImageBytes; // For web
  String? _selectedImageName; // For web
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          // For web, read as bytes
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageName = pickedFile.name;
            _selectedImage = null;
          });
        } else {
          // For mobile, use File
          setState(() {
            _selectedImage = File(pickedFile.path);
            _selectedImageBytes = null;
            _selectedImageName = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadPhoto() async {
    if (_selectedImage == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final photo = kIsWeb
          ? await _photoService.uploadPhotoWeb(
              imageBytes: _selectedImageBytes!,
              fileName: _selectedImageName ?? 'photo.jpg',
              familyId: widget.familyId,
              albumId: widget.albumId,
              caption: _captionController.text.trim().isEmpty
                  ? null
                  : _captionController.text.trim(),
            )
          : await _photoService.uploadPhoto(
              imageFile: _selectedImage!,
              familyId: widget.familyId,
              albumId: widget.albumId,
              caption: _captionController.text.trim().isEmpty
                  ? null
                  : _captionController.text.trim(),
            );

      if (mounted) {
        Navigator.pop(context, photo);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Upload Photo'),
              automaticallyImplyLeading: false,
              actions: [
                if (!_isUploading)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Image Preview
                    if (_selectedImage != null || _selectedImageBytes != null)
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: kIsWeb && _selectedImageBytes != null
                                ? MemoryImage(_selectedImageBytes!)
                                : FileImage(_selectedImage!) as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.photo, size: 64, color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Image Picker Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (!kIsWeb)
                          ElevatedButton.icon(
                            onPressed: _isUploading ? null : () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: Text(kIsWeb ? 'Choose File' : 'Gallery'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Caption
                    TextField(
                      controller: _captionController,
                      decoration: const InputDecoration(
                        labelText: 'Caption (optional)',
                        border: OutlineInputBorder(),
                        hintText: 'Add a caption...',
                      ),
                      maxLines: 3,
                      enabled: !_isUploading,
                    ),
                  ],
                ),
              ),
            ),
            // Upload Button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading || (_selectedImage == null && _selectedImageBytes == null)
                      ? null
                      : _uploadPhoto,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isUploading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Uploading...'),
                          ],
                        )
                      : const Text('Upload Photo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

