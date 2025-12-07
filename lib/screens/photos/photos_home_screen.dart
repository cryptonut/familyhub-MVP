import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/services/logger_service.dart';
import '../../services/photo_service.dart';
import '../../services/auth_service.dart';
import '../../models/family_photo.dart';
import '../../models/photo_album.dart';
import '../../models/user_model.dart';
import 'photo_detail_screen.dart';
import 'album_photos_screen.dart';
import 'upload_photo_dialog.dart';
import 'create_album_dialog.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/skeletons/skeleton_widgets.dart';

class PhotosHomeScreen extends StatefulWidget {
  const PhotosHomeScreen({super.key});

  @override
  State<PhotosHomeScreen> createState() => _PhotosHomeScreenState();
}

class _PhotosHomeScreenState extends State<PhotosHomeScreen>
    with TickerProviderStateMixin {
  final PhotoService _photoService = PhotoService();
  final AuthService _authService = AuthService();

  TabController? _tabController;
  List<PhotoAlbum> _albums = [];
  List<FamilyPhoto> _allPhotos = [];
  String? _familyId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel?.familyId != null) {
        _familyId = userModel!.familyId;
        _albums = await _photoService.getAlbums(_familyId!);
        _allPhotos = await _photoService.getPhotos(_familyId!);
      }
    } catch (e) {
      Logger.error('Error loading photos data', error: e, tag: 'PhotosHomeScreen');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadPhoto({String? albumId}) async {
    if (_familyId == null) return;

    final result = await showDialog<FamilyPhoto>(
      context: context,
      builder: (context) => UploadPhotoDialog(
        familyId: _familyId!,
        albumId: albumId,
      ),
    );

    if (result != null && mounted) {
      await _loadData();
    }
  }

  Future<void> _createAlbum() async {
    if (_familyId == null) return;

    final result = await showDialog<PhotoAlbum>(
      context: context,
      builder: (context) => CreateAlbumDialog(familyId: _familyId!),
    );

    if (result != null && mounted) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 9,
          itemBuilder: (context, index) => const SkeletonPhotoGridItem(),
        ),
      );
    }

    if (_familyId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Photos')),
        body: const Center(
          child: Text('Join a family to view photos'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Photos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: () => _uploadPhoto(),
            tooltip: 'Upload Photo',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.photo_library), text: 'Albums'),
            Tab(icon: Icon(Icons.grid_on), text: 'All Photos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlbumsTab(),
          _buildAllPhotosTab(),
        ],
      ),
    );
  }

  Widget _buildAlbumsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: StreamBuilder<List<PhotoAlbum>>(
        stream: _photoService.getAlbumsStream(_familyId!),
        builder: (context, snapshot) {
          final albums = snapshot.data ?? _albums;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _createAlbum,
                    icon: const Icon(Icons.create_new_folder),
                    label: const Text('Create Album'),
                  ),
                ),
              ),
              if (albums.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('No albums yet. Create one to get started!'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final album = albums[index];
                        return _buildAlbumCard(album);
                      },
                      childCount: albums.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlbumCard(PhotoAlbum album) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumPhotosScreen(
              album: album,
              familyId: _familyId!,
            ),
          ),
        ).then((_) => _loadData());
      },
      child: ModernCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FutureBuilder<List<FamilyPhoto>>(
                // Fetch up to 4 photos for preview
                future: _photoService.getPhotos(_familyId!, albumId: album.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  
                  final photos = snapshot.data!;
                  if (photos.isEmpty) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.folder_open, size: 48, color: Colors.grey),
                    );
                  }
                  
                  // Take up to 4 photos
                  final previewPhotos = photos.take(4).toList();
                  
                  if (previewPhotos.length == 1) {
                    return _buildPreviewImage(previewPhotos[0]);
                  } else {
                    return Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: _buildPreviewImage(previewPhotos[0])),
                              const SizedBox(width: 1),
                              Expanded(child: previewPhotos.length > 1 ? _buildPreviewImage(previewPhotos[1]) : Container(color: Colors.grey[200])),
                            ],
                          ),
                        ),
                        const SizedBox(height: 1),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: previewPhotos.length > 2 ? _buildPreviewImage(previewPhotos[2]) : Container(color: Colors.grey[200])),
                              const SizedBox(width: 1),
                              Expanded(child: previewPhotos.length > 3 ? _buildPreviewImage(previewPhotos[3]) : Container(color: Colors.grey[200])),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${album.photoCount} photo${album.photoCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewImage(FamilyPhoto photo) {
    return CachedNetworkImage(
      imageUrl: photo.thumbnailUrl ?? photo.imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[200],
        child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
      ),
    );
  }

  Widget _buildAllPhotosTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: StreamBuilder<List<FamilyPhoto>>(
        stream: _photoService.getPhotosStream(_familyId!),
        builder: (context, snapshot) {
          final photos = snapshot.data ?? _allPhotos;

          if (photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No photos yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _uploadPhoto(),
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Upload First Photo'),
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
              return _buildPhotoThumbnail(photo);
            },
          );
        },
      ),
    );
  }

  Widget _buildPhotoThumbnail(FamilyPhoto photo) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoDetailScreen(
              photo: photo,
              familyId: _familyId!,
            ),
          ),
        ).then((_) => _loadData());
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
  }
}

