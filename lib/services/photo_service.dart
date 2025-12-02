import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/family_photo.dart';
import '../models/photo_album.dart';
import '../models/photo_comment.dart';
import '../services/image_compression_service.dart';
import 'auth_service.dart';

/// Service for managing family photos and albums
class PhotoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService = AuthService();
  final ImageCompressionService _compressionService = ImageCompressionService();
  final Uuid _uuid = const Uuid();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Upload a photo (mobile - uses File)
  Future<FamilyPhoto> uploadPhoto({
    required File imageFile,
    required String familyId,
    String? albumId,
    String? caption,
    List<String>? taggedMemberIds,
  }) async {
    if (kIsWeb) {
      throw ValidationException('Use uploadPhotoWeb for web platform');
    }
    final userId = _currentUserId;
    if (userId == null) throw AuthException('User not authenticated', code: 'not-authenticated');

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw AuthException('User model not found', code: 'user-not-found');

    try {
      // Generate unique file name
      final photoId = _uuid.v4();
      final fileName = 'photos/$familyId/$photoId.jpg';
      
      // Upload to Firebase Storage
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'familyId': familyId,
          },
        ),
      );

      await uploadTask;
      final imageUrl = await ref.getDownloadURL();

      // Create thumbnail (simplified - in production, generate actual thumbnail)
      // For now, we'll use the same image as thumbnail (can be optimized later)
      String? thumbnailUrl;
      try {
        final thumbnailRef = _storage.ref().child('thumbnails/$familyId/$photoId.jpg');
        final thumbnailTask = thumbnailRef.putFile(
          imageFile,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        await thumbnailTask;
        thumbnailUrl = await thumbnailRef.getDownloadURL();
      } catch (e) {
        Logger.warning('Error creating thumbnail', error: e, tag: 'PhotoService');
        // Continue without thumbnail - will use full image
      }

      // Create photo document
      final photo = FamilyPhoto(
        id: photoId,
        familyId: familyId,
        uploadedBy: userId,
        uploadedByName: userModel.displayName,
        albumId: albumId,
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        caption: caption,
        uploadedAt: DateTime.now(),
        taggedMemberIds: taggedMemberIds ?? [],
      );

      final photoData = photo.toJson();
      photoData.remove('id');

      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('photos')
          .doc(photoId)
          .set(photoData);

      // Update album photo count if in album
      if (albumId != null) {
        await _updateAlbumPhotoCount(familyId, albumId, 1);
      }

      return photo;
    } catch (e) {
      Logger.error('Error uploading photo', error: e, tag: 'PhotoService');
      rethrow;
    }
  }

  /// Upload a photo (web - uses Uint8List)
  Future<FamilyPhoto> uploadPhotoWeb({
    required Uint8List imageBytes,
    required String fileName,
    required String familyId,
    String? albumId,
    String? caption,
    List<String>? taggedMemberIds,
  }) async {
    if (!kIsWeb) {
      throw ValidationException('Use uploadPhoto for mobile platforms');
    }

    final userId = _currentUserId;
    if (userId == null) throw AuthException('User not authenticated', code: 'not-authenticated');

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw AuthException('User model not found', code: 'user-not-found');

    try {
      // Generate unique file name
      final photoId = _uuid.v4();
      final storageFileName = 'photos/$familyId/$photoId.jpg';
      
      // Upload to Firebase Storage (web uses putData)
      final ref = _storage.ref().child(storageFileName);
      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'familyId': familyId,
          },
        ),
      );

      await uploadTask;
      final imageUrl = await ref.getDownloadURL();

      // Create thumbnail (simplified - in production, generate actual thumbnail)
      String? thumbnailUrl;
      try {
        final thumbnailRef = _storage.ref().child('thumbnails/$familyId/$photoId.jpg');
        final thumbnailTask = thumbnailRef.putData(
          imageBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        await thumbnailTask;
        thumbnailUrl = await thumbnailRef.getDownloadURL();
      } catch (e) {
        Logger.warning('Error creating thumbnail', error: e, tag: 'PhotoService');
        // Continue without thumbnail - will use full image
      }

      // Create photo document
      final photo = FamilyPhoto(
        id: photoId,
        familyId: familyId,
        uploadedBy: userId,
        uploadedByName: userModel.displayName,
        albumId: albumId,
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        caption: caption,
        uploadedAt: DateTime.now(),
        taggedMemberIds: taggedMemberIds ?? [],
      );

      final photoData = photo.toJson();
      photoData.remove('id');

      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('photos')
          .doc(photoId)
          .set(photoData);

      // Update album photo count if in album
      if (albumId != null) {
        await _updateAlbumPhotoCount(familyId, albumId, 1);
      }

      return photo;
    } catch (e) {
      Logger.error('Error uploading photo', error: e, tag: 'PhotoService');
      rethrow;
    }
  }

  /// Get all photos for a family
  Future<List<FamilyPhoto>> getPhotos(String familyId, {String? albumId}) async {
    try {
      Query query = _firestore
          .collection('families')
          .doc(familyId)
          .collection('photos')
          .orderBy('uploadedAt', descending: true);

      if (albumId != null) {
        query = query.where('albumId', isEqualTo: albumId);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => FamilyPhoto.fromJson({
                'id': doc.id,
                ...(doc.data() as Map<String, dynamic>),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting photos', error: e, tag: 'PhotoService');
      return [];
    }
  }

  /// Get photos stream for real-time updates
  Stream<List<FamilyPhoto>> getPhotosStream(String familyId, {String? albumId}) {
    Query query = _firestore
        .collection('families')
        .doc(familyId)
        .collection('photos')
        .orderBy('uploadedAt', descending: true);

    if (albumId != null) {
      query = query.where('albumId', isEqualTo: albumId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => FamilyPhoto.fromJson({
                'id': doc.id,
                ...(doc.data() as Map<String, dynamic>),
              }))
          .toList();
    });
  }

  /// Get a single photo
  Future<FamilyPhoto?> getPhoto(String familyId, String photoId) async {
    try {
      final doc = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('photos')
          .doc(photoId)
          .get();

      if (!doc.exists) return null;

      return FamilyPhoto.fromJson({
        'id': doc.id,
        ...(doc.data()! as Map<String, dynamic>),
      });
    } catch (e) {
      Logger.error('Error getting photo', error: e, tag: 'PhotoService');
      return null;
    }
  }

  /// Delete a photo
  Future<void> deletePhoto(String familyId, String photoId, String? albumId) async {
    final userId = _currentUserId;
    if (userId == null) throw AuthException('User not authenticated', code: 'not-authenticated');

    try {
      // Get photo to check ownership
      final photo = await getPhoto(familyId, photoId);
      if (photo == null) throw FirestoreException('Photo not found', code: 'not-found');
      if (photo.uploadedBy != userId) {
        throw PermissionException('Only the uploader can delete this photo', code: 'permission-denied');
      }

      // Delete from Storage
      try {
        await _storage.ref().child('photos/$familyId/$photoId.jpg').delete();
        await _storage.ref().child('thumbnails/$familyId/$photoId.jpg').delete();
      } catch (e) {
        Logger.warning('Error deleting from storage', error: e, tag: 'PhotoService');
      }

      // Delete from Firestore
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('photos')
          .doc(photoId)
          .delete();

      // Delete comments
      final commentsSnapshot = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('photos')
          .doc(photoId)
          .collection('comments')
          .get();

      final batch = _firestore.batch();
      for (var doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Update album photo count if in album
      if (albumId != null) {
        await _updateAlbumPhotoCount(familyId, albumId, -1);
      }
    } catch (e) {
      Logger.error('Error deleting photo', error: e, tag: 'PhotoService');
      rethrow;
    }
  }

  /// Create an album
  Future<PhotoAlbum> createAlbum({
    required String familyId,
    required String name,
    String? description,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw AuthException('User not authenticated', code: 'not-authenticated');

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw AuthException('User model not found', code: 'user-not-found');

    try {
      final albumId = _uuid.v4();
      final album = PhotoAlbum(
        id: albumId,
        familyId: familyId,
        name: name,
        description: description,
        createdBy: userId,
        createdByName: userModel.displayName,
        createdAt: DateTime.now(),
      );

      final albumData = album.toJson();
      albumData.remove('id');

      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('albums')
          .doc(albumId)
          .set(albumData);

      return album;
    } catch (e) {
      Logger.error('Error creating album', error: e, tag: 'PhotoService');
      rethrow;
    }
  }

  /// Get all albums for a family
  Future<List<PhotoAlbum>> getAlbums(String familyId) async {
    try {
      final snapshot = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('albums')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PhotoAlbum.fromJson({
                'id': doc.id,
                ...(doc.data() as Map<String, dynamic>),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting albums', error: e, tag: 'PhotoService');
      return [];
    }
  }

  /// Get albums stream for real-time updates
  Stream<List<PhotoAlbum>> getAlbumsStream(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('albums')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PhotoAlbum.fromJson({
                'id': doc.id,
                ...(doc.data() as Map<String, dynamic>),
              }))
          .toList();
    });
  }

  /// Add comment to a photo
  Future<PhotoComment> addComment({
    required String familyId,
    required String photoId,
    required String content,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw AuthException('User not authenticated', code: 'not-authenticated');

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw AuthException('User model not found', code: 'user-not-found');

    try {
      final commentId = _uuid.v4();
      final comment = PhotoComment(
        id: commentId,
        photoId: photoId,
        authorId: userId,
        authorName: userModel.displayName,
        content: content,
        createdAt: DateTime.now(),
      );

      final commentData = comment.toJson();
      commentData.remove('id');

      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('photos')
          .doc(photoId)
          .collection('comments')
          .doc(commentId)
          .set(commentData);

      return comment;
    } catch (e) {
      Logger.error('Error adding comment', error: e, tag: 'PhotoService');
      rethrow;
    }
  }

  /// Get comments for a photo
  Future<List<PhotoComment>> getComments(String familyId, String photoId) async {
    try {
      final snapshot = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('photos')
          .doc(photoId)
          .collection('comments')
          .orderBy('createdAt')
          .get();

      return snapshot.docs
          .map((doc) => PhotoComment.fromJson({
                'id': doc.id,
                ...(doc.data() as Map<String, dynamic>),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting comments', error: e, tag: 'PhotoService');
      return [];
    }
  }

  /// Get comments stream for real-time updates
  Stream<List<PhotoComment>> getCommentsStream(String familyId, String photoId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('photos')
        .doc(photoId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PhotoComment.fromJson({
                'id': doc.id,
                ...(doc.data() as Map<String, dynamic>),
              }))
          .toList();
    });
  }

  /// Update photo view count
  Future<void> recordPhotoView(String familyId, String photoId) async {
    try {
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('photos')
          .doc(photoId)
          .update({
        'viewCount': FieldValue.increment(1),
        'lastViewedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      Logger.warning('Error recording photo view', error: e, tag: 'PhotoService');
    }
  }

  /// Update album photo count
  Future<void> _updateAlbumPhotoCount(String familyId, String albumId, int delta) async {
    try {
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('albums')
          .doc(albumId)
          .update({
        'photoCount': FieldValue.increment(delta),
        'lastPhotoAddedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      Logger.warning('Error updating album photo count', error: e, tag: 'PhotoService');
    }
  }

  /// Update album cover photo
  Future<void> updateAlbumCover(String familyId, String albumId, String photoId) async {
    try {
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('albums')
          .doc(albumId)
          .update({
        'coverPhotoId': photoId,
      });
    } catch (e) {
      Logger.warning('Error updating album cover', error: e, tag: 'PhotoService');
      rethrow;
    }
  }
}

