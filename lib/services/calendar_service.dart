import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/calendar_event.dart';
import 'auth_service.dart';
import 'recurrence_service.dart';
import 'notification_service.dart';

class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  
  String? _cachedFamilyId;
  
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
    
    final snapshot = await _firestore.collection('families/$familyId/events').get();
    return snapshot.docs
        .map((doc) => CalendarEvent.fromJson({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
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

  Future<void> addEvent(CalendarEvent event) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      // Remove 'id' from the data since it's used as the document ID
      final data = event.toJson();
      data.remove('id');
      
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
}
