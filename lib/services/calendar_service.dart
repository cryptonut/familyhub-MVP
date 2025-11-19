import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/calendar_event.dart';
import 'auth_service.dart';

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
    if (familyId == null) throw Exception('User not part of a family');
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
    return allEvents.where((event) {
      return event.startTime.year == date.year &&
          event.startTime.month == date.month &&
          event.startTime.day == date.day;
    }).toList();
  }

  Future<void> addEvent(CalendarEvent event) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      // Remove 'id' from the data since it's used as the document ID
      final data = event.toJson();
      data.remove('id');
      
      // Use set() with the event.id as document ID to ensure consistent IDs
      await _firestore
          .collection('families/$familyId/events')
          .doc(event.id)
          .set(data);
    } catch (e) {
      // Log the actual error for debugging
      debugPrint('CalendarService.addEvent error: $e');
      debugPrint('Family ID: $familyId');
      debugPrint('Event ID: ${event.id}');
      rethrow;
    }
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      // Remove 'id' from the data since it's used as the document ID
      final data = event.toJson();
      data.remove('id');
      
      // Use set with merge instead of update to handle cases where document might not exist
      await _firestore
          .collection('families/$familyId/events')
          .doc(event.id)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('CalendarService.updateEvent error: $e');
      debugPrint('Family ID: $familyId');
      debugPrint('Event ID: ${event.id}');
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    await _firestore.collection('families/$familyId/events').doc(eventId).delete();
  }
}
