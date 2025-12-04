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
      
      // Set eventOwnerId from createdBy if not already set (initial owner is the creator)
      if (data['eventOwnerId'] == null && data['createdBy'] != null) {
        data['eventOwnerId'] = data['createdBy'];
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

  /// Update event owner (can be done by current owner or admin)
  Future<void> updateEventOwner(String eventId, String newOwnerId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      await _firestore
          .collection('families/$familyId/events')
          .doc(eventId)
          .update({'eventOwnerId': newOwnerId});
    } catch (e) {
      Logger.error('Error updating event owner', error: e, tag: 'CalendarService');
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

  /// Check if two events are duplicates based on title, start time, end time, and location
  /// Allows for small time differences (up to 1 minute) to account for timezone/rounding issues
  bool _areEventsDuplicates(CalendarEvent event1, CalendarEvent event2) {
    // Must have same title (case-insensitive, trimmed)
    if (event1.title.trim().toLowerCase() != event2.title.trim().toLowerCase()) {
      return false;
    }

    // Must have same start time (within 1 minute tolerance)
    final startDiff = event1.startTime.difference(event2.startTime).abs();
    if (startDiff.inMinutes > 1) {
      return false;
    }

    // Must have same end time (within 1 minute tolerance)
    final endDiff = event1.endTime.difference(event2.endTime).abs();
    if (endDiff.inMinutes > 1) {
      return false;
    }

    // Must have same location (both null or both same, case-insensitive)
    final loc1 = (event1.location ?? '').trim().toLowerCase();
    final loc2 = (event2.location ?? '').trim().toLowerCase();
    if (loc1 != loc2) {
      return false;
    }

    return true;
  }

  /// Find all duplicate events grouped by their matching characteristics
  /// Returns a map where each key is a "signature" and value is list of duplicate event IDs
  Future<Map<String, List<String>>> findDuplicateEvents() async {
    final familyId = await _familyId;
    if (familyId == null) return {};

    try {
      final allEvents = await getEvents();
      final duplicateGroups = <String, List<String>>{};

      // Compare all events pairwise
      for (int i = 0; i < allEvents.length; i++) {
        for (int j = i + 1; j < allEvents.length; j++) {
          final event1 = allEvents[i];
          final event2 = allEvents[j];

          if (_areEventsDuplicates(event1, event2)) {
            // Create a signature key for this duplicate group
            final signature = '${event1.title.trim().toLowerCase()}_'
                '${event1.startTime.toIso8601String()}_'
                '${event1.endTime.toIso8601String()}_'
                '${(event1.location ?? '').trim().toLowerCase()}';

            if (!duplicateGroups.containsKey(signature)) {
              duplicateGroups[signature] = [];
            }

            // Add both event IDs if not already in the list
            if (!duplicateGroups[signature]!.contains(event1.id)) {
              duplicateGroups[signature]!.add(event1.id);
            }
            if (!duplicateGroups[signature]!.contains(event2.id)) {
              duplicateGroups[signature]!.add(event2.id);
            }
          }
        }
      }

      return duplicateGroups;
    } catch (e) {
      Logger.error('Error finding duplicate events', error: e, tag: 'CalendarService');
      rethrow;
    }
  }

  /// Determine which event to keep when merging duplicates
  /// Priority: 1) Not imported from device, 2) Has more data (photos, participants), 3) Older created date
  String _selectBestEvent(List<CalendarEvent> duplicates) {
    if (duplicates.isEmpty) throw ArgumentError('Cannot select from empty list');

    // Sort by priority
    duplicates.sort((a, b) {
      // Priority 1: Prefer events NOT imported from device (FamilyHub-created)
      final aIsImported = a.sourceCalendar?.toLowerCase().contains('synced') ?? false;
      final bIsImported = b.sourceCalendar?.toLowerCase().contains('synced') ?? false;
      if (aIsImported != bIsImported) {
        return aIsImported ? 1 : -1; // Non-imported comes first
      }

      // Priority 2: Prefer events with more data (photos, participants, description)
      final aDataScore = (a.photoUrls.length * 10) +
          (a.participants.length * 5) +
          (a.invitedMemberIds.length * 3) +
          ((a.description.isNotEmpty) ? 2 : 0);
      final bDataScore = (b.photoUrls.length * 10) +
          (b.participants.length * 5) +
          (b.invitedMemberIds.length * 3) +
          ((b.description.isNotEmpty) ? 2 : 0);
      if (aDataScore != bDataScore) {
        return bDataScore.compareTo(aDataScore); // Higher score first
      }

      // Priority 3: Prefer older event (earlier createdBy timestamp if available)
      // Since we don't have created timestamp, use event ID (UUIDs are time-based-ish)
      // Actually, just keep the first one in the list as a tiebreaker
      return 0;
    });

    return duplicates.first.id;
  }

  /// Merge duplicate events by keeping the best one and merging data from others
  /// Returns the number of events merged/deleted
  Future<int> mergeDuplicateEvents() async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    try {
      final duplicateGroups = await findDuplicateEvents();
      if (duplicateGroups.isEmpty) {
        Logger.info('No duplicate events found', tag: 'CalendarService');
        return 0;
      }

      Logger.info('Found ${duplicateGroups.length} duplicate groups', tag: 'CalendarService');

      final allEvents = await getEvents();
      final eventsMap = {for (var e in allEvents) e.id: e};

      int mergedCount = 0;
      final batch = _firestore.batch();

      for (var duplicateIds in duplicateGroups.values) {
        if (duplicateIds.length < 2) continue; // Need at least 2 to merge

        // Get the actual events
        final duplicates = duplicateIds
            .map((id) => eventsMap[id])
            .where((e) => e != null)
            .cast<CalendarEvent>()
            .toList();

        if (duplicates.length < 2) continue;

        // Select the best event to keep
        final keepEventId = _selectBestEvent(duplicates);
        final keepEvent = eventsMap[keepEventId]!;
        final eventsToDelete = duplicates.where((e) => e.id != keepEventId).toList();

        // Merge data from duplicates into the kept event
        final mergedEvent = keepEvent.copyWith(
          // Merge photo URLs (unique)
          photoUrls: [
            ...keepEvent.photoUrls,
            ...eventsToDelete.expand((e) => e.photoUrls),
          ].toSet().toList(),
          // Merge participants (unique)
          participants: [
            ...keepEvent.participants,
            ...eventsToDelete.expand((e) => e.participants),
          ].toSet().toList(),
          // Merge invited member IDs (unique)
          invitedMemberIds: [
            ...keepEvent.invitedMemberIds,
            ...eventsToDelete.expand((e) => e.invitedMemberIds),
          ].toSet().toList(),
          // Merge RSVP status (keep most recent/conflicting values from kept event)
          rsvpStatus: Map.fromEntries([
            ...eventsToDelete.expand((e) => e.rsvpStatus.entries),
            ...keepEvent.rsvpStatus.entries,
          ]),
          // Use description from kept event (or first non-empty)
          description: keepEvent.description.isNotEmpty
              ? keepEvent.description
              : eventsToDelete.firstWhere((e) => e.description.isNotEmpty,
                      orElse: () => keepEvent)
                  .description,
        );

        // Update the kept event with merged data
        final keepEventRef = _firestore
            .collection('families/$familyId/events')
            .doc(keepEventId);
        final keepEventData = mergedEvent.toJson();
        keepEventData.remove('id');
        batch.set(keepEventRef, keepEventData, SetOptions(merge: true));

        // Delete duplicate events
        for (var eventToDelete in eventsToDelete) {
          final deleteRef = _firestore
              .collection('families/$familyId/events')
              .doc(eventToDelete.id);
          batch.delete(deleteRef);
          mergedCount++;
        }

        Logger.info(
          'Merging ${eventsToDelete.length} duplicates into event "${keepEvent.title}" (${keepEvent.id})',
          tag: 'CalendarService',
        );
      }

      if (mergedCount > 0) {
        await batch.commit();
        Logger.info('Successfully merged $mergedCount duplicate events', tag: 'CalendarService');
      }

      return mergedCount;
    } catch (e, st) {
      Logger.error('Error merging duplicate events', error: e, stackTrace: st, tag: 'CalendarService');
      rethrow;
    }
  }

  /// Check if an event is a duplicate of any existing event
  /// Used during sync to prevent importing duplicates
  Future<CalendarEvent?> findDuplicateEvent(CalendarEvent newEvent) async {
    try {
      final allEvents = await getEvents();
      for (var existingEvent in allEvents) {
        if (_areEventsDuplicates(newEvent, existingEvent)) {
          return existingEvent;
        }
      }
      return null;
    } catch (e) {
      Logger.warning('Error checking for duplicate event', error: e, tag: 'CalendarService');
      return null;
    }
  }
}
