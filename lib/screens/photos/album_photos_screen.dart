import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/logger_service.dart';
import '../../models/photo_album.dart';
import '../../models/family_photo.dart';
import '../../services/photo_service.dart';
import 'photo_detail_screen.dart';
import 'upload_photo_dialog.dart';

class AlbumPhotosScreen extends StatefulWidget {
  final PhotoAlbum album;
  final String familyId;

  const AlbumPhotosScreen({
    super.key,
    required this.album,
    required this.familyId,
  });

  @override
  State<AlbumPhotosScreen> createState() => _AlbumPhotosScreenState();
}

class _AlbumPhotosScreenState extends State<AlbumPhotosScreen> {
  final PhotoService _photoService = PhotoService();
  List<FamilyPhoto> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final photos = await _photoService.getPhotos(
        widget.familyId,
        albumId: widget.album.id,
      );
      setState(() {
        _photos = photos;
      });
    } catch (e) {
      Logger.error('Error loading album photos', error: e, tag: 'AlbumPhotosScreen');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadPhoto() async {
    final result = await showDialog<FamilyPhoto>(
      context: context,
      builder: (context) => UploadPhotoDialog(
        familyId: widget.familyId,
        albumId: widget.album.id,
      ),
    );

    if (result != null && mounted) {
      await _loadPhotos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.album.name),
            if (widget.album.description != null)
              Text(
                widget.album.description!,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _uploadPhoto,
            tooltip: 'Add Photo',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPhotos,
              child: StreamBuilder<List<FamilyPhoto>>(
                stream: _photoService.getPhotosStream(
                  widget.familyId,
                  albumId: widget.album.id,
                ),
                builder: (context, snapshot) {
                  final photos = snapshot.data ?? _photos;

                  if (photos.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No photos in this album',
                            style: TextStyle(color: Colors.grey[600], fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _uploadPhoto,
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Add First Photo'),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PhotoDetailScreen(
                                photo: photo,
                                familyId: widget.familyId,
                              ),
                            ),
                          ).then((_) => _loadPhotos());
                        },
                        child: CachedNetworkImage(
                          imageUrl: photo.thumbnailUrl ?? photo.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.photo),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

