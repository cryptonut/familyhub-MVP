import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';

/// Service for uploading and managing user profile photos/bitmojis
class ProfilePhotoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Upload profile photo (mobile - uses File)
  Future<String> uploadProfilePhoto(File imageFile) async {
    if (kIsWeb) {
      throw ValidationException('Use uploadProfilePhotoWeb for web platform');
    }
    
    final userId = _currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      // Generate unique file name
      final photoId = _uuid.v4();
      final fileName = 'profile_photos/$userId/$photoId.jpg';
      
      // Upload to Firebase Storage
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      await uploadTask;
      final imageUrl = await ref.getDownloadURL();

      // Update user document with photoUrl
      await _firestore.collection('users').doc(userId).update({
        'photoUrl': imageUrl,
      });

      Logger.info('Profile photo uploaded successfully', tag: 'ProfilePhotoService');
      return imageUrl;
    } catch (e) {
      Logger.error('Error uploading profile photo', error: e, tag: 'ProfilePhotoService');
      rethrow;
    }
  }

  /// Upload profile photo (web - uses Uint8List)
  Future<String> uploadProfilePhotoWeb(Uint8List imageBytes, String fileName) async {
    if (!kIsWeb) {
      throw ValidationException('Use uploadProfilePhoto for mobile platforms');
    }
    
    final userId = _currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      // Generate unique file name
      final photoId = _uuid.v4();
      final storageFileName = 'profile_photos/$userId/$photoId.jpg';
      
      // Upload to Firebase Storage
      final ref = _storage.ref().child(storageFileName);
      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      await uploadTask;
      final imageUrl = await ref.getDownloadURL();

      // Update user document with photoUrl
      await _firestore.collection('users').doc(userId).update({
        'photoUrl': imageUrl,
      });

      Logger.info('Profile photo uploaded successfully', tag: 'ProfilePhotoService');
      return imageUrl;
    } catch (e) {
      Logger.error('Error uploading profile photo', error: e, tag: 'ProfilePhotoService');
      rethrow;
    }
  }

  /// Update photo URL directly (for bitmoji URLs)
  Future<void> updatePhotoUrl(String photoUrl) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        'photoUrl': photoUrl,
      });

      Logger.info('Profile photo URL updated successfully', tag: 'ProfilePhotoService');
    } catch (e) {
      Logger.error('Error updating profile photo URL', error: e, tag: 'ProfilePhotoService');
      rethrow;
    }
  }

  /// Delete profile photo
  Future<void> deleteProfilePhoto() async {
    final userId = _currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      // Get current photoUrl
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final photoUrl = userDoc.data()?['photoUrl'] as String?;

      // Delete from Storage if exists
      if (photoUrl != null) {
        try {
          final ref = _storage.refFromURL(photoUrl);
          await ref.delete();
        } catch (e) {
          Logger.warning('Error deleting photo from storage (may not exist)', error: e, tag: 'ProfilePhotoService');
        }
      }

      // Remove photoUrl from user document
      await _firestore.collection('users').doc(userId).update({
        'photoUrl': FieldValue.delete(),
      });

      Logger.info('Profile photo deleted successfully', tag: 'ProfilePhotoService');
    } catch (e) {
      Logger.error('Error deleting profile photo', error: e, tag: 'ProfilePhotoService');
      rethrow;
    }
  }
}

