import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/shopping_service.dart';
import '../../models/shopping_list_item.dart';
import 'dart:async';

class ItemNotesDialog extends StatefulWidget {
  final ShoppingListItem item;
  final ShoppingService shoppingService;

  const ItemNotesDialog({
    super.key,
    required this.item,
    required this.shoppingService,
  });

  @override
  State<ItemNotesDialog> createState() => _ItemNotesDialogState();
}

class _ItemNotesDialogState extends State<ItemNotesDialog> {
  final _notesController = TextEditingController();
  List<String> _attachmentUrls = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.item.notes ?? '';
    _attachmentUrls = List.from(widget.item.attachmentUrls);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _uploadImage(File(image.path));
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      await _uploadImage(File(image.path));
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    setState(() => _isUploading = true);
    try {
      final url = await widget.shoppingService.uploadReceiptImage(
        imageFile,
        widget.item.listId,
      );
      setState(() {
        _attachmentUrls.add(url);
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final updatedItem = widget.item.copyWith(
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        attachmentUrls: _attachmentUrls,
      );
      await widget.shoppingService.updateItem(updatedItem);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachmentUrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                hintText: 'Add any notes about this item...',
              ),
              maxLines: 5,
              enabled: !_isLoading && !_isUploading,
            ),
            const SizedBox(height: 16),
            const Text(
              'Attachments',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (_isLoading || _isUploading) ? null : _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: (_isLoading || _isUploading) ? null : _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(),
              ),
            if (_attachmentUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _attachmentUrls.asMap().entries.map((entry) {
                  final index = entry.key;
                  final url = entry.value;
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(url),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          color: Colors.red,
                          onPressed: () => _removeAttachment(index),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: (_isLoading || _isUploading) ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isLoading || _isUploading) ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
