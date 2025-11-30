import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/calendar_event.dart';
import 'auth_service.dart';
import 'recurrence_service.dart';
import 'notification_service.dart';

class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService = AuthService();
  
  String? _cachedFamilyId;
  
  // Maximum file size: 10MB
  static const int maxFileSizeBytes = 10 * 1024 * 1024;
  
  Future<String?> get _familyId async {
    if (_cachedFamilyId != null) return _cachedFamilyId;
    
    final userModel = await _authService.getCurrentUserModel();
    _cachedFamilyId = userModel?.familyId;
    return _cachedFamilyId;
  }

  Future<String> get _collectionPath async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    return 'families/$familyId/events';
  }

  Future<List<CalendarEvent>> getEvents() async {
    final familyId = await _familyId;
    if (familyId == null) return [];
    
    try {
      final snapshot = await _firestore.collection('families/$familyId/events').get();
      final events = <CalendarEvent>[];
      
      for (var doc in snapshot.docs) {
        try {
          final event = CalendarEvent.fromJson({
            'id': doc.id,
            ...doc.data(),
          });
          events.add(event);
        } catch (e) {
          Logger.warning('Error parsing event ${doc.id}', error: e, tag: 'CalendarService');
          // Skip invalid events but continue loading others
        }
      }
      
      return events;
    } catch (e) {
      Logger.error('Error loading events', error: e, tag: 'CalendarService');
      rethrow;
    }
  }

  Stream<List<CalendarEvent>> getEventsStream() {
    return Stream.fromFuture(_familyId).asyncExpand((familyId) {
      if (familyId == null) {
        return Stream.value(<CalendarEvent>[]);
      }
      
      return _firestore
          .collection('families/$familyId/events')
          .orderBy('startTime')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => CalendarEvent.fromJson({
                    'id': doc.id,
                    ...doc.data(),
                  }))
              .toList());
    });
  }

  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final allEvents = await getEvents();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    // Use recurrence service to expand recurring events
    final expandedEvents = RecurrenceService.getAllEventsForRange(
      allEvents,
      startOfDay,
      endOfDay,
    );
    
    // Filter to exact date
    return expandedEvents.where((event) {
      return event.startTime.year == date.year &&
          event.startTime.month == date.month &&
          event.startTime.day == date.day;
    }).toList();
  }

  /// Update RSVP status for an event
  Future<void> updateRsvpStatus(String eventId, String memberId, String status) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    final eventRef = _firestore.collection('families/$familyId/events').doc(eventId);
    final eventDoc = await eventRef.get();
    
    if (!eventDoc.exists) {
      throw FirestoreException('Event not found', code: 'not-found');
    }
    
    final eventData = eventDoc.data() as Map<String, dynamic>;
    final rsvpStatus = Map<String, String>.from(eventData['rsvpStatus'] as Map? ?? {});
    rsvpStatus[memberId] = status;
    
    await eventRef.update({'rsvpStatus': rsvpStatus});
  }

  Future<void> addEvent(CalendarEvent event, {String? sourceCalendar}) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final userId = _auth.currentUser?.uid;
      
      // Remove 'id' from the data since it's used as the document ID
      final data = event.toJson();
      data.remove('id');
      
      // Ensure createdBy is set if not already set
      if (data['createdBy'] == null && userId != null) {
        data['createdBy'] = userId;
      }
      
      // Set sourceCalendar if not already set (default to FamilyHub for manually created events)
      if (data['sourceCalendar'] == null) {
        data['sourceCalendar'] = sourceCalendar ?? 'Created in FamilyHub';
      }
      
      // Use set() with the event.id as document ID to ensure consistent IDs
      await _firestore
          .collection('families/$familyId/events')
          .doc(event.id)
          .set(data);
      
      // Trigger calendar sync notification for family members
      try {
        final notificationService = NotificationService();
        await notificationService.notifyCalendarSyncTrigger(familyId);
      } catch (e) {
        Logger.warning('Error triggering calendar sync notification', error: e, tag: 'CalendarService');
        // Don't fail event creation if notification fails
      }
    } catch (e) {
      // Log the actual error for debugging
      Logger.error('addEvent error', error: e, tag: 'CalendarService');
      Logger.debug('Family ID: $familyId', tag: 'CalendarService');
      Logger.debug('Event ID: ${event.id}', tag: 'CalendarService');
      rethrow;
    }
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      // Remove 'id' from the data since it's used as the document ID
      final data = event.toJson();
      data.remove('id');
      
      // Use set with merge instead of update to handle cases where document might not exist
      await _firestore
          .collection('families/$familyId/events')
          .doc(event.id)
          .set(data, SetOptions(merge: true));
      
      // Trigger calendar sync notification for family members
      try {
        final notificationService = NotificationService();
        await notificationService.notifyCalendarSyncTrigger(familyId);
      } catch (e) {
        Logger.warning('Error triggering calendar sync notification', error: e, tag: 'CalendarService');
        // Don't fail event update if notification fails
      }
    } catch (e) {
      Logger.error('updateEvent error', error: e, tag: 'CalendarService');
      Logger.debug('Family ID: $familyId', tag: 'CalendarService');
      Logger.debug('Event ID: ${event.id}', tag: 'CalendarService');
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    await _firestore.collection('families/$familyId/events').doc(eventId).delete();
  }

  /// Upload a photo for an event (mobile - uses File)
  Future<String> uploadEventPhoto({
    required File imageFile,
    required String eventId,
  }) async {
    if (kIsWeb) {
      throw ValidationException('Use uploadEventPhotoWeb for web platform');
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      // Check file size
      final fileSize = await imageFile.length();
      if (fileSize > maxFileSizeBytes) {
        throw ValidationException(
          'File size exceeds 10MB limit',
          code: 'file-too-large',
        );
      }

      // Generate unique file name
      final photoId = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = 'eventPhotos/$familyId/$eventId/$photoId.jpg';

      // Upload to Firebase Storage
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'familyId': familyId,
            'eventId': eventId,
          },
        ),
      );

      await uploadTask;
      final imageUrl = await ref.getDownloadURL();

      // Update event with photo URL
      final eventRef = _firestore.collection('families/$familyId/events').doc(eventId);
      final eventDoc = await eventRef.get();

      if (!eventDoc.exists) {
        throw FirestoreException('Event not found', code: 'not-found');
      }

      final eventData = eventDoc.data()!;
      final photoUrls = List<String>.from(eventData['photoUrls'] as List? ?? []);
      photoUrls.add(imageUrl);

      await eventRef.update({'photoUrls': photoUrls});

      return imageUrl;
    } catch (e) {
      Logger.error('Error uploading event photo', error: e, tag: 'CalendarService');
      rethrow;
    }
  }

  /// Upload a photo for an event (web - uses Uint8List)
  Future<String> uploadEventPhotoWeb({
    required Uint8List imageBytes,
    required String eventId,
  }) async {
    if (!kIsWeb) {
      throw ValidationException('Use uploadEventPhoto for mobile platforms');
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      // Check file size
      if (imageBytes.length > maxFileSizeBytes) {
        throw ValidationException(
          'File size exceeds 10MB limit',
          code: 'file-too-large',
        );
      }

      // Generate unique file name
      final photoId = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = 'eventPhotos/$familyId/$eventId/$photoId.jpg';

      // Upload to Firebase Storage
      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'familyId': familyId,
            'eventId': eventId,
          },
        ),
      );

      await uploadTask;
      final imageUrl = await ref.getDownloadURL();

      // Update event with photo URL
      final eventRef = _firestore.collection('families/$familyId/events').doc(eventId);
      final eventDoc = await eventRef.get();

      if (!eventDoc.exists) {
        throw FirestoreException('Event not found', code: 'not-found');
      }

      final eventData = eventDoc.data()!;
      final photoUrls = List<String>.from(eventData['photoUrls'] as List? ?? []);
      photoUrls.add(imageUrl);

      await eventRef.update({'photoUrls': photoUrls});

      return imageUrl;
    } catch (e) {
      Logger.error('Error uploading event photo', error: e, tag: 'CalendarService');
      rethrow;
    }
  }

  /// Delete a photo from an event
  Future<void> deleteEventPhoto(String eventId, String photoUrl) async {
    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      // Update event to remove photo URL
      final eventRef = _firestore.collection('families/$familyId/events').doc(eventId);
      final eventDoc = await eventRef.get();

      if (!eventDoc.exists) {
        throw FirestoreException('Event not found', code: 'not-found');
      }

      final eventData = eventDoc.data()!;
      final photoUrls = List<String>.from(eventData['photoUrls'] as List? ?? []);
      photoUrls.remove(photoUrl);

      await eventRef.update({'photoUrls': photoUrls});

      // Optionally delete from Storage (for now, we'll just remove the URL)
      // In production, you might want to delete the file from Storage too
    } catch (e) {
      Logger.error('Error deleting event photo', error: e, tag: 'CalendarService');
      rethrow;
    }
  }
}
