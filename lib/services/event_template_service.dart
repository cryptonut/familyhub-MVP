import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../models/event_template.dart';
import '../models/calendar_event.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'package:uuid/uuid.dart';

class EventTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  /// Get all templates for the current family
  Future<List<EventTemplate>> getTemplates() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      if (familyId == null) {
        Logger.warning('No family ID found', tag: 'EventTemplateService');
        return [];
      }

      final snapshot = await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection('eventTemplates')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => EventTemplate.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e, st) {
      Logger.error('Error getting templates', error: e, stackTrace: st, tag: 'EventTemplateService');
      return [];
    }
  }

  /// Create a new template
  Future<EventTemplate> createTemplate(EventTemplate template) async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      if (familyId == null) {
        throw Exception('No family ID found');
      }

      final templateId = template.id.isEmpty ? const Uuid().v4() : template.id;
      final templateData = template.toJson();
      templateData.remove('id');

      await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection('eventTemplates')
          .doc(templateId)
          .set(templateData);

      Logger.info('Template created: $templateId', tag: 'EventTemplateService');
      return template.copyWith(id: templateId);
    } catch (e, st) {
      Logger.error('Error creating template', error: e, stackTrace: st, tag: 'EventTemplateService');
      rethrow;
    }
  }

  /// Update an existing template
  Future<void> updateTemplate(EventTemplate template) async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      if (familyId == null) {
        throw Exception('No family ID found');
      }

      final templateData = template.toJson();
      templateData.remove('id');

      await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection('eventTemplates')
          .doc(template.id)
          .update(templateData);

      Logger.info('Template updated: ${template.id}', tag: 'EventTemplateService');
    } catch (e, st) {
      Logger.error('Error updating template', error: e, stackTrace: st, tag: 'EventTemplateService');
      rethrow;
    }
  }

  /// Delete a template
  Future<void> deleteTemplate(String templateId) async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      if (familyId == null) {
        throw Exception('No family ID found');
      }

      await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection('eventTemplates')
          .doc(templateId)
          .delete();

      Logger.info('Template deleted: $templateId', tag: 'EventTemplateService');
    } catch (e, st) {
      Logger.error('Error deleting template', error: e, stackTrace: st, tag: 'EventTemplateService');
      rethrow;
    }
  }

  /// Create an event from a template
  Future<CalendarEvent> createEventFromTemplate(String templateId, DateTime date) async {
    try {
      final templates = await getTemplates();
      final template = templates.firstWhere((t) => t.id == templateId);

      final startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        template.startTime?.hour ?? 9,
        template.startTime?.minute ?? 0,
      );

      final endDateTime = template.endTime != null
          ? DateTime(
              date.year,
              date.month,
              date.day,
              template.endTime!.hour,
              template.endTime!.minute,
            )
          : startDateTime.add(const Duration(hours: 1));

      return CalendarEvent(
        id: const Uuid().v4(),
        title: template.title,
        description: template.description ?? '',
        startTime: startDateTime,
        endTime: endDateTime,
        location: template.location,
        color: template.color != null 
            ? '#${template.color!.value.toRadixString(16).substring(2)}'
            : '#2196F3',
        isRecurring: template.recurrenceRule != null,
        recurrenceRule: template.recurrenceRule,
        invitedMemberIds: template.defaultInvitees,
        createdBy: _auth.currentUser?.uid ?? '',
        eventOwnerId: _auth.currentUser?.uid,
      );
    } catch (e, st) {
      Logger.error('Error creating event from template', error: e, stackTrace: st, tag: 'EventTemplateService');
      rethrow;
    }
  }
}

