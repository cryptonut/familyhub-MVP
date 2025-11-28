import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/calendar_event.dart';
import 'auth_service.dart';
import 'calendar_service.dart';
import 'recurrence_service.dart';

/// Service for two-way calendar synchronization between FamilyHub and device calendars
class CalendarSyncService {
  final DeviceCalendarPlugin _deviceCalendar = DeviceCalendarPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final CalendarService _calendarService = CalendarService();

  // Extended property key for tracking FamilyHub events in device calendar
  // We'll store this in the event description as a workaround since extendedProperties
  // may not be available in all device_calendar versions
  static const String _fhEventIdKey = 'fh_event_id';
  static const String _fhEventIdPrefix = '[FamilyHub:';

  /// Request calendar permissions
  Future<bool> requestPermissions() async {
    // device_calendar has limited web support
    if (kIsWeb) {
      Logger.warning('Calendar permissions on web are not fully supported by device_calendar', tag: 'CalendarSyncService');
      throw PermissionException(
        'Calendar sync is not available on web platform. '
        'Please use the mobile app (Android/iOS) to enable calendar sync.',
        code: 'web-not-supported',
      );
    }

    try {
      final result = await _deviceCalendar.requestPermissions();
      if (!result.isSuccess) {
        final errorMsg = result.errors.map((e) => e.toString()).join(', ');
        Logger.warning('Permission request failed: $errorMsg', tag: 'CalendarSyncService');
        throw PermissionException('Failed to request calendar permissions: $errorMsg', code: 'permission-denied');
      }
      return result.data ?? false;
    } catch (e, st) {
      Logger.error('Error requesting calendar permissions', error: e, stackTrace: st, tag: 'CalendarSyncService');
      rethrow;
    }
  }

  /// Check if calendar permissions are granted
  Future<bool> hasPermissions() async {
    // device_calendar has limited web support
    if (kIsWeb) {
      return false;
    }

    try {
      final result = await _deviceCalendar.hasPermissions();
      if (!result.isSuccess) {
        return false;
      }
      return result.data ?? false;
    } catch (e) {
      Logger.warning('Error checking calendar permissions', error: e, tag: 'CalendarSyncService');
      return false;
    }
  }

  /// Get list of available device calendars
  Future<List<Calendar>> getDeviceCalendars() async {
    // device_calendar has limited web support
    if (kIsWeb) {
      Logger.warning('Calendar access on web is not fully supported by device_calendar', tag: 'CalendarSyncService');
      throw PermissionException(
        'Calendar sync is not available on web platform. '
        'Please use the mobile app (Android/iOS) to access calendars.',
        code: 'web-not-supported',
      );
    }

    try {
      if (!await hasPermissions()) {
        final granted = await requestPermissions();
        if (!granted) {
          throw PermissionException('Calendar permissions not granted', code: 'permission-denied');
        }
      }

      final calendarsResult = await _deviceCalendar.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        return calendarsResult.data!;
      }
      
      if (!calendarsResult.isSuccess) {
        final errorMsg = calendarsResult.errors.map((e) => e.toString()).join(', ');
        throw PermissionException('Failed to retrieve calendars: $errorMsg', code: 'retrieve-failed');
      }
      
      return [];
    } catch (e) {
      Logger.error('Error getting device calendars', error: e, tag: 'CalendarSyncService');
      rethrow;
    }
  }

  /// Find or create a dedicated FamilyHub calendar on the device
  Future<String?> findOrCreateFamilyHubCalendar() async {
    try {
      if (!await hasPermissions()) {
        final granted = await requestPermissions();
        if (!granted) {
          throw PermissionException('Calendar permissions not granted', code: 'permission-denied');
        }
      }

      final calendarsResult = await _deviceCalendar.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data == null) {
        throw PermissionException('Failed to retrieve calendars', code: 'retrieve-failed');
      }

      // Check if FamilyHub calendar already exists
      final existingCalendar = calendarsResult.data!.firstWhere(
        (cal) => cal.name == 'FamilyHub',
        orElse: () => Calendar(),
      );

      if (existingCalendar.id != null && existingCalendar.id!.isNotEmpty) {
        return existingCalendar.id;
      }

      // Create new calendar
      final calendar = Calendar();
      calendar.name = 'FamilyHub';
      final colorInt = int.tryParse('2196F3', radix: 16) ?? 0x2196F3;
      calendar.color = colorInt;

      final createResult = await _deviceCalendar.createCalendar(calendar.name!);
      if (createResult.isSuccess && createResult.data != null) {
        return createResult.data;
      }
      return null;
    } catch (e) {
      Logger.error('Error creating FamilyHub calendar', error: e, tag: 'CalendarSyncService');
      return null;
    }
  }

  /// Update user's calendar sync settings
  Future<void> updateSyncSettings({
    required bool enabled,
    String? localCalendarId,
    String? googleCalendarId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('User not logged in', code: 'not-authenticated');

    final updateData = <String, dynamic>{
      'calendarSyncEnabled': enabled,
      if (localCalendarId != null) 'localCalendarId': localCalendarId,
      if (googleCalendarId != null) 'googleCalendarId': googleCalendarId,
      if (!enabled) 'localCalendarId': FieldValue.delete(),
      if (!enabled) 'googleCalendarId': FieldValue.delete(),
    };

    await _firestore.collection('users').doc(user.uid).update(updateData);
  }

  /// Update last synced timestamp
  Future<void> updateLastSyncedAt() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'lastSyncedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Extract FamilyHub event ID from event description
  String? _extractFhEventId(String? description) {
    if (description == null || !description.contains(_fhEventIdPrefix)) {
      return null;
    }
    final startIndex = description.indexOf(_fhEventIdPrefix);
    final endIndex = description.indexOf(']', startIndex);
    if (endIndex == -1) return null;
    return description.substring(startIndex + _fhEventIdPrefix.length, endIndex);
  }

  /// Add FamilyHub event ID to description
  String _addFhEventIdToDescription(String description, String fhEventId) {
    // Remove existing FamilyHub marker if present
    final cleaned = description.replaceAll(RegExp(r'\[FamilyHub:[^\]]+\]'), '').trim();
    return '$cleaned\n$_fhEventIdPrefix$fhEventId]';
  }

  /// Convert DateTime to TZDateTime
  tz.TZDateTime _toTZDateTime(DateTime dateTime) {
    final location = tz.local;
    return tz.TZDateTime.from(dateTime, location);
  }

  /// Convert TZDateTime to DateTime
  DateTime _fromTZDateTime(tz.TZDateTime? tzDateTime) {
    if (tzDateTime == null) return DateTime.now();
    return tzDateTime.toLocal();
  }

  /// Convert FamilyHub CalendarEvent to device_calendar Event
  Event _familyHubEventToDeviceEvent(CalendarEvent fhEvent, String calendarId, {String? deviceEventId}) {
    final event = Event(calendarId);
    event.eventId = deviceEventId;
    event.title = fhEvent.title;
    event.description = _addFhEventIdToDescription(fhEvent.description, fhEvent.id);
    event.start = _toTZDateTime(fhEvent.startTime);
    event.end = _toTZDateTime(fhEvent.endTime);
    event.location = fhEvent.location;
    
    if (fhEvent.invitedMemberIds.isNotEmpty) {
      event.attendees = fhEvent.invitedMemberIds.map((id) {
        final attendee = Attendee();
        attendee.name = id;
        return attendee;
      }).toList();
    }

    // Handle recurrence - Note: device_calendar recurrence support may vary by platform
    // For now, we'll skip recurrence and sync individual instances
    // TODO: Add proper recurrence support when device_calendar API is stable

    return event;
  }

  /// Convert device_calendar RecurrenceRule to FamilyHub format
  /// Note: Recurrence support is limited - we sync individual instances instead
  String? _deviceRecurrenceToFamilyHub(dynamic recurrence) {
    // Recurrence support is complex and varies by platform
    // For now, return null and sync individual instances
    return null;
  }

  /// Convert device_calendar Event to FamilyHub CalendarEvent
  Future<CalendarEvent?> _deviceEventToFamilyHub(Event deviceEvent) async {
    try {
      // Extract FamilyHub event ID from description
      final fhEventId = _extractFhEventId(deviceEvent.description);

      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      if (familyId == null) return null;

      // Clean description (remove FamilyHub marker)
      String description = deviceEvent.description ?? '';
      if (description.contains(_fhEventIdPrefix)) {
        description = description.replaceAll(RegExp(r'\[FamilyHub:[^\]]+\]'), '').trim();
      }

      final event = CalendarEvent(
        id: fhEventId ?? const Uuid().v4(),
        title: deviceEvent.title ?? 'Untitled Event',
        description: description,
        startTime: _fromTZDateTime(deviceEvent.start),
        endTime: _fromTZDateTime(deviceEvent.end),
        location: deviceEvent.location,
        participants: deviceEvent.attendees?.where((a) => a != null && a.name != null).map((a) => a!.name!).toList() ?? [],
        color: '#2196F3',
        isRecurring: false, // Recurrence detection from device events is complex
        recurrenceRule: null,
        invitedMemberIds: [],
        rsvpStatus: {},
      );

      return event;
    } catch (e) {
      Logger.warning('Error converting device event to FamilyHub', error: e, tag: 'CalendarSyncService');
      return null;
    }
  }

  /// Sync FamilyHub events to device calendar (PUSH)
  Future<void> syncToDevice(String calendarId) async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

      // Get all FamilyHub events
      final fhEvents = await _calendarService.getEvents();

      // Expand recurring events for next 180 days
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 180));
      final allInstances = RecurrenceService.getAllEventsForRange(
        fhEvents,
        now,
        endDate,
      );

      // Get existing events from device calendar to check for updates
      final deviceEventsResult = await _deviceCalendar.retrieveEvents(
        calendarId,
        RetrieveEventsParams(
          startDate: _toTZDateTime(now.subtract(const Duration(days: 30))),
          endDate: _toTZDateTime(endDate),
        ),
      );

      final existingDeviceEvents = <String, Event>{};
      if (deviceEventsResult.isSuccess && deviceEventsResult.data != null) {
        for (var deviceEvent in deviceEventsResult.data!) {
          final fhId = _extractFhEventId(deviceEvent.description);
          if (fhId != null && deviceEvent.eventId != null) {
            existingDeviceEvents[fhId] = deviceEvent;
          }
        }
      }

      // Push all FamilyHub events to device
      final fhEventIds = <String>{};
      for (var fhEvent in allInstances) {
        fhEventIds.add(fhEvent.id);
        final existingEvent = existingDeviceEvents[fhEvent.id];
        final deviceEvent = _familyHubEventToDeviceEvent(
          fhEvent,
          calendarId,
          deviceEventId: existingEvent?.eventId,
        );

        final result = await _deviceCalendar.createOrUpdateEvent(deviceEvent);
        if (result != null && !result.isSuccess) {
          final errorMessages = result.errors.map((e) => e.toString()).join(', ');
          Logger.warning('Failed to sync event ${fhEvent.id} to device: $errorMessages', tag: 'CalendarSyncService');
        } else if (result == null) {
          Logger.warning('Failed to sync event ${fhEvent.id} to device: Result is null', tag: 'CalendarSyncService');
        }
      }

      // Delete device events that no longer exist in FamilyHub
      if (deviceEventsResult.isSuccess && deviceEventsResult.data != null) {
        for (var deviceEvent in deviceEventsResult.data!) {
          final fhId = _extractFhEventId(deviceEvent.description);
          if (fhId != null && !fhEventIds.contains(fhId) && deviceEvent.eventId != null) {
            // Event was deleted in FamilyHub, remove from device
            await _deviceCalendar.deleteEvent(calendarId, deviceEvent.eventId!);
          }
        }
      }

      await updateLastSyncedAt();
      Logger.info('Successfully synced ${allInstances.length} events to device calendar', tag: 'CalendarSyncService');
    } catch (e, st) {
      Logger.error('Error syncing to device', error: e, stackTrace: st, tag: 'CalendarSyncService');
      rethrow;
    }
  }

  /// Sync device calendar events to FamilyHub (PULL)
  Future<void> syncFromDevice(String calendarId, DateTime? lastSyncedAt) async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      if (userModel == null || familyId == null) {
        throw AuthException('User not part of a family', code: 'no-family');
      }

      // Get events from device calendar since last sync
      final startDate = lastSyncedAt ?? DateTime.now().subtract(const Duration(days: 30));
      final endDate = DateTime.now().add(const Duration(days: 180));

      final deviceEventsResult = await _deviceCalendar.retrieveEvents(
        calendarId,
        RetrieveEventsParams(
          startDate: _toTZDateTime(startDate),
          endDate: _toTZDateTime(endDate),
        ),
      );

      if (!deviceEventsResult.isSuccess || deviceEventsResult.data == null) {
        Logger.warning('Failed to retrieve device events', tag: 'CalendarSyncService');
        return;
      }

      final deviceEvents = deviceEventsResult.data!;
      final batch = _firestore.batch();
      int importedCount = 0;

      for (var deviceEvent in deviceEvents) {
        // Check if this is a FamilyHub event (has fh_event_id in description)
        final fhEventId = _extractFhEventId(deviceEvent.description);
        
        if (fhEventId != null) {
          // This is a FamilyHub event - FamilyHub wins on conflicts, so skip
          continue;
        }

        // This is an external event - import it
        final fhEvent = await _deviceEventToFamilyHub(deviceEvent);
        if (fhEvent == null) continue;

        final eventRef = _firestore
            .collection('families')
            .doc(familyId)
            .collection('events')
            .doc(fhEvent.id);

        batch.set(eventRef, {
          'title': fhEvent.title,
          'description': fhEvent.description,
          'startTime': fhEvent.startTime.toIso8601String(),
          'endTime': fhEvent.endTime.toIso8601String(),
          'location': fhEvent.location,
          'participants': fhEvent.participants,
          'color': fhEvent.color,
          'isRecurring': fhEvent.isRecurring,
          if (fhEvent.recurrenceRule != null) 'recurrenceRule': fhEvent.recurrenceRule,
          'invitedMemberIds': fhEvent.invitedMemberIds,
          'rsvpStatus': fhEvent.rsvpStatus,
          'importedFromDevice': true, // Mark as imported
          'deviceEventId': deviceEvent.eventId, // Store device event ID for future updates
        }, SetOptions(merge: true));

        importedCount++;
      }

      if (importedCount > 0) {
        await batch.commit();
        Logger.info('Imported $importedCount events from device calendar', tag: 'CalendarSyncService');
      }

      await updateLastSyncedAt();
    } catch (e) {
      Logger.error('Error syncing from device', error: e, tag: 'CalendarSyncService');
      rethrow;
    }
  }

  /// Perform full two-way sync
  Future<void> performSync() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null || !userModel.calendarSyncEnabled) {
        Logger.debug('Calendar sync is disabled', tag: 'CalendarSyncService');
        return;
      }

      final calendarId = userModel.localCalendarId;
      if (calendarId == null || calendarId.isEmpty) {
        Logger.debug('No calendar selected for sync', tag: 'CalendarSyncService');
        return;
      }

      if (!await hasPermissions()) {
        Logger.warning('Calendar permissions not granted', tag: 'CalendarSyncService');
        return;
      }

      // Pull from device first (import external events)
      // Only import events that don't have fh_event_id (external events)
      await syncFromDevice(calendarId, userModel.lastSyncedAt);

      // Push to device (sync FamilyHub events)
      // This will create/update all FamilyHub events in device calendar
      await syncToDevice(calendarId);

      Logger.info('Calendar sync completed successfully', tag: 'CalendarSyncService');
    } catch (e, st) {
      Logger.error('Error performing calendar sync', error: e, stackTrace: st, tag: 'CalendarSyncService');
      // Don't rethrow - sync failures shouldn't crash the app
    }
  }

  /// Check if an event exists in device calendar
  Future<bool> eventExistsInDevice(String calendarId, String fhEventId) async {
    try {
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 180));
      
      final deviceEventsResult = await _deviceCalendar.retrieveEvents(
        calendarId,
        RetrieveEventsParams(
          startDate: _toTZDateTime(now.subtract(const Duration(days: 30))),
          endDate: _toTZDateTime(endDate),
        ),
      );

      if (!deviceEventsResult.isSuccess || deviceEventsResult.data == null) {
        return false;
      }

      return deviceEventsResult.data!.any(
        (event) => _extractFhEventId(event.description) == fhEventId,
      );
    } catch (e) {
      Logger.warning('Error checking if event exists in device', error: e, tag: 'CalendarSyncService');
      return false;
    }
  }
}
