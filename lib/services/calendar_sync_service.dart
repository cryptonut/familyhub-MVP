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
      
      // Enhanced logging for release build debugging
      Logger.info(
        'retrieveCalendars result: isSuccess=${calendarsResult.isSuccess}, data=${calendarsResult.data != null ? calendarsResult.data!.length : "null"}, errors=${calendarsResult.errors.length}',
        tag: 'CalendarSyncService',
      );
      
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        Logger.info(
          'Retrieved ${calendarsResult.data!.length} calendars from device',
          tag: 'CalendarSyncService',
        );
        // Log calendar details for debugging (critical for release builds)
        for (var cal in calendarsResult.data!) {
          Logger.info(
            'Calendar details: name="${cal.name}" (null: ${cal.name == null}), accountName="${cal.accountName}" (null: ${cal.accountName == null}), id="${cal.id}" (null: ${cal.id == null}), readOnly=${cal.isReadOnly}',
            tag: 'CalendarSyncService',
          );
          
          // Warn if critical properties are null (indicates R8/obfuscation issue)
          if (cal.name == null && cal.accountName == null) {
            Logger.warning(
              'Calendar has both name and accountName as null! This may indicate R8 obfuscation issue. ID: "${cal.id}"',
              tag: 'CalendarSyncService',
            );
          }
        }
        return calendarsResult.data!;
      }
      
      if (!calendarsResult.isSuccess) {
        final errorMsg = calendarsResult.errors.map((e) => e.toString()).join(', ');
        Logger.error(
          'Failed to retrieve calendars. Errors: $errorMsg',
          tag: 'CalendarSyncService',
        );
        throw PermissionException('Failed to retrieve calendars: $errorMsg', code: 'retrieve-failed');
      }
      
      Logger.warning(
        'retrieveCalendars returned success but data is null',
        tag: 'CalendarSyncService',
      );
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
  /// [existingEventId] - If provided, use this ID instead of generating a new one (for updates)
  Future<CalendarEvent?> _deviceEventToFamilyHub(Event deviceEvent, {String? existingEventId}) async {
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

      // Use existing event ID if provided (for updates), otherwise use extracted ID or generate new one
      final eventId = existingEventId ?? fhEventId ?? const Uuid().v4();

      final event = CalendarEvent(
        id: eventId,
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
      // For first sync or if lastSync was very recent (< 1 hour), look back 90 days
      // For subsequent syncs, only get events since last sync
      final now = DateTime.now();
      DateTime startDate;
      if (lastSyncedAt == null) {
        // First sync - look back 90 days
        startDate = now.subtract(const Duration(days: 90));
      } else {
        final timeSinceLastSync = now.difference(lastSyncedAt);
        if (timeSinceLastSync.inHours < 1) {
          // Last sync was very recent - likely a retry or first sync after setup
          // Look back 90 days to catch existing events
          startDate = now.subtract(const Duration(days: 90));
          Logger.info(
            'Last sync was recent (${timeSinceLastSync.inMinutes} min ago), looking back 90 days for existing events',
            tag: 'CalendarSyncService',
          );
        } else {
          // Normal sync - only get events since last sync
          startDate = lastSyncedAt;
        }
      }
      final endDate = now.add(const Duration(days: 180));
      
      Logger.info(
        'Syncing events from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
        tag: 'CalendarSyncService',
      );

      Logger.info(
        'Attempting to retrieve events from calendar ID: $calendarId',
        tag: 'CalendarSyncService',
      );
      
      // Verify calendar is accessible and get its properties
      Calendar? selectedCalendar;
      String? verifiedCalendarId = calendarId;
      try {
        final calendarsResult = await _deviceCalendar.retrieveCalendars();
        if (calendarsResult.isSuccess && calendarsResult.data != null) {
          // Normalize comparison to handle whitespace and type issues
          selectedCalendar = calendarsResult.data!.firstWhere(
            (cal) => cal.id?.trim() == calendarId?.trim(),
            orElse: () => Calendar(),
          );
          if (selectedCalendar.id == null || selectedCalendar.id!.isEmpty) {
            Logger.error(
              'Calendar ID "$calendarId" not found in available calendars',
              tag: 'CalendarSyncService',
            );
            // Log all available calendars for debugging
            Logger.info(
              'Available calendars: ${calendarsResult.data!.map((c) => '${c.name} (ID: "${c.id}", Type: ${c.id.runtimeType})').join(', ')}',
              tag: 'CalendarSyncService',
            );
            return;
          }
          // Use the verified calendar ID from the actual calendar object
          verifiedCalendarId = selectedCalendar.id;
          Logger.info(
            'Calendar found: ${selectedCalendar.name} (ID: "$verifiedCalendarId", ReadOnly: ${selectedCalendar.isReadOnly}, Account: ${selectedCalendar.accountName})',
            tag: 'CalendarSyncService',
          );
          
          // If calendar is read-only, warn but continue (we can still read events)
          if (selectedCalendar.isReadOnly == true) {
            Logger.warning(
              'Calendar ${selectedCalendar.name} is read-only. Events can be read but not modified.',
              tag: 'CalendarSyncService',
            );
          }
        }
      } catch (e) {
        Logger.warning('Could not verify calendar before retrieving events', error: e, tag: 'CalendarSyncService');
      }
      
      // Re-check permissions before retrieving events
      if (!await hasPermissions()) {
        Logger.error('Calendar permissions revoked during sync', tag: 'CalendarSyncService');
        return;
      }
      
      Logger.info(
        'Calling retrieveEvents with verified calendarId: "$verifiedCalendarId" (original: "$calendarId")',
        tag: 'CalendarSyncService',
      );
      
      final deviceEventsResult = await _deviceCalendar.retrieveEvents(
        verifiedCalendarId ?? calendarId,
        RetrieveEventsParams(
          startDate: _toTZDateTime(startDate),
          endDate: _toTZDateTime(endDate),
        ),
      );

      if (!deviceEventsResult.isSuccess) {
        final errorMessages = deviceEventsResult.errors.map((e) => e.toString()).join(', ');
        Logger.error(
          'Failed to retrieve device events. Errors: $errorMessages',
          tag: 'CalendarSyncService',
        );
        return;
      }
      
      if (deviceEventsResult.data == null) {
        Logger.warning(
          'retrieveEvents returned null data (but was successful). Calendar might be empty or have permission issues.',
          tag: 'CalendarSyncService',
        );
        // Try to diagnose: check if we can retrieve events from a wider date range as a test
        Logger.info(
          'Attempting diagnostic: checking if calendar has ANY events in a wider range (1 year back, 1 year forward)',
          tag: 'CalendarSyncService',
        );
        final diagnosticResult = await _deviceCalendar.retrieveEvents(
          calendarId,
          RetrieveEventsParams(
            startDate: _toTZDateTime(now.subtract(const Duration(days: 365))),
            endDate: _toTZDateTime(now.add(const Duration(days: 365))),
          ),
        );
        if (diagnosticResult.isSuccess && diagnosticResult.data != null) {
          Logger.info(
            'Diagnostic: Found ${diagnosticResult.data!.length} events in wider date range (1 year back/forward)',
            tag: 'CalendarSyncService',
          );
          if (diagnosticResult.data!.isEmpty) {
            Logger.warning(
              'Calendar appears to be empty - no events found even in 1-year range',
              tag: 'CalendarSyncService',
            );
          } else {
            Logger.warning(
              'Calendar has events but not in the requested date range (${startDate.toIso8601String()} to ${endDate.toIso8601String()})',
              tag: 'CalendarSyncService',
            );
          }
        }
        return;
      }

      final deviceEvents = deviceEventsResult.data!;
      Logger.info('Retrieved ${deviceEvents.length} events from device calendar', tag: 'CalendarSyncService');
      
      // If no events found, run diagnostic to check if calendar has events at all
      if (deviceEvents.isEmpty) {
        Logger.warning(
          'No events found in calendar ${selectedCalendar?.name ?? calendarId} for date range ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
          tag: 'CalendarSyncService',
        );
        
        // Diagnostic: Check if calendar has ANY events in a wider range
        Logger.info(
          'Running diagnostic: Checking if calendar has events in wider date range (1 year back/forward)',
          tag: 'CalendarSyncService',
        );
        final diagnosticResult = await _deviceCalendar.retrieveEvents(
          calendarId,
          RetrieveEventsParams(
            startDate: _toTZDateTime(now.subtract(const Duration(days: 365))),
            endDate: _toTZDateTime(now.add(const Duration(days: 365))),
          ),
        );
        if (diagnosticResult.isSuccess && diagnosticResult.data != null) {
          Logger.info(
            'Diagnostic result: Found ${diagnosticResult.data!.length} events in 1-year range',
            tag: 'CalendarSyncService',
          );
          if (diagnosticResult.data!.isEmpty) {
            Logger.warning(
              'Calendar "${selectedCalendar?.name ?? calendarId}" appears to be completely empty (no events in 1-year range)',
              tag: 'CalendarSyncService',
            );
            // Try checking other calendars to see if they have events
            Logger.info(
              'Checking other calendars for events...',
              tag: 'CalendarSyncService',
            );
            try {
              final allCalendarsResult = await _deviceCalendar.retrieveCalendars();
              if (allCalendarsResult.isSuccess && allCalendarsResult.data != null) {
                for (var cal in allCalendarsResult.data!) {
                  if (cal.id == null || cal.id == calendarId) continue; // Skip null IDs and the selected calendar
                  final testResult = await _deviceCalendar.retrieveEvents(
                    cal.id!,
                    RetrieveEventsParams(
                      startDate: _toTZDateTime(now.subtract(const Duration(days: 90))),
                      endDate: _toTZDateTime(now.add(const Duration(days: 180))),
                    ),
                  );
                  if (testResult.isSuccess && testResult.data != null && testResult.data!.isNotEmpty) {
                    Logger.info(
                      'Found ${testResult.data!.length} events in calendar "${cal.name}" (ID: "${cal.id}")',
                      tag: 'CalendarSyncService',
                    );
                  }
                }
              }
            } catch (e) {
              Logger.warning('Error checking other calendars', error: e, tag: 'CalendarSyncService');
            }
          } else {
            Logger.warning(
              'Calendar has ${diagnosticResult.data!.length} events but they are outside the requested date range. '
              'Requested: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
              tag: 'CalendarSyncService',
            );
          }
        }
      }
      
      final batch = _firestore.batch();
      int importedCount = 0;
      int skippedFamilyHubCount = 0;
      int failedConversionCount = 0;
      int updatedCount = 0;

      // Get calendar name for source tracking
      String? calendarName;
      try {
        final calendarsResult = await _deviceCalendar.retrieveCalendars();
        if (calendarsResult.isSuccess && calendarsResult.data != null) {
          final calendar = calendarsResult.data!.firstWhere(
            (cal) => cal.id == calendarId,
            orElse: () => Calendar(),
          );
          calendarName = calendar.name ?? calendar.accountName ?? 'Device Calendar';
          Logger.info('Syncing from calendar: $calendarName (ID: $calendarId)', tag: 'CalendarSyncService');
        }
      } catch (e) {
        Logger.warning('Could not get calendar name', error: e, tag: 'CalendarSyncService');
        calendarName = 'Device Calendar';
      }

      // Get existing imported events to check for duplicates by deviceEventId
      final existingEventsQuery = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('events')
          .where('deviceEventId', isEqualTo: null) // This won't work, we need a different approach
          .get();
      
      // Better approach: Query all events and filter in memory (deviceEventId might not be indexed)
      // Or check each event individually - more efficient for small datasets
      final eventsCollection = _firestore
          .collection('families')
          .doc(familyId)
          .collection('events');
      
      // Build a map of deviceEventId -> Firestore document ID for quick lookup
      final deviceEventIdMap = <String, String>{};
      try {
        final allEventsSnapshot = await eventsCollection
            .where('importedFromDevice', isEqualTo: true)
            .get();
        for (var doc in allEventsSnapshot.docs) {
          final data = doc.data();
          final storedDeviceEventId = data['deviceEventId'] as String?;
          if (storedDeviceEventId != null) {
            deviceEventIdMap[storedDeviceEventId] = doc.id;
          }
        }
      } catch (e) {
        Logger.warning('Error loading existing imported events for duplicate check', error: e, tag: 'CalendarSyncService');
      }

      for (var deviceEvent in deviceEvents) {
        // Check if this is a FamilyHub event (has fh_event_id in description)
        final fhEventId = _extractFhEventId(deviceEvent.description);
        
        if (fhEventId != null) {
          // This is a FamilyHub event - FamilyHub wins on conflicts, so skip
          skippedFamilyHubCount++;
          Logger.debug('Skipping FamilyHub event: ${deviceEvent.title} (ID: $fhEventId)', tag: 'CalendarSyncService');
          continue;
        }

        // Check if this device event was already imported (by deviceEventId)
        String? existingEventId;
        if (deviceEvent.eventId != null && deviceEventIdMap.containsKey(deviceEvent.eventId)) {
          existingEventId = deviceEventIdMap[deviceEvent.eventId];
          Logger.debug(
            'Found existing imported event for deviceEventId "${deviceEvent.eventId}": $existingEventId',
            tag: 'CalendarSyncService',
          );
        }

        // This is an external event - import it
        final fhEvent = await _deviceEventToFamilyHub(deviceEvent, existingEventId: existingEventId);
        if (fhEvent == null) {
          failedConversionCount++;
          Logger.warning('Failed to convert device event to FamilyHub: ${deviceEvent.title}', tag: 'CalendarSyncService');
          continue;
        }
        
        final isUpdate = existingEventId != null;
        Logger.debug(
          '${isUpdate ? 'Updating' : 'Importing'} event: ${fhEvent.title} (${fhEvent.startTime})',
          tag: 'CalendarSyncService',
        );

        final eventRef = eventsCollection.doc(fhEvent.id);

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
          'sourceCalendar': calendarName != null ? 'Synced from $calendarName' : 'Synced from Device Calendar',
          'createdBy': userModel.uid, // Set creator to current user for imported events
        }, SetOptions(merge: true));

        if (isUpdate) {
          updatedCount++;
        } else {
          importedCount++;
        }
      }

      if (importedCount > 0 || updatedCount > 0) {
        await batch.commit();
        Logger.info(
          'Successfully ${importedCount > 0 ? "imported $importedCount new events" : ""}${importedCount > 0 && updatedCount > 0 ? " and " : ""}${updatedCount > 0 ? "updated $updatedCount existing events" : ""} from device calendar',
          tag: 'CalendarSyncService',
        );
        // Only update lastSyncedAt if we actually imported or updated events
        await updateLastSyncedAt();
      } else {
        Logger.warning(
          'No events imported or updated. Total: ${deviceEvents.length}, Skipped (FamilyHub): $skippedFamilyHubCount, Failed conversion: $failedConversionCount',
          tag: 'CalendarSyncService',
        );
        // Don't update lastSyncedAt if no events were imported - allows retry with same date range
        if (deviceEvents.isEmpty) {
          Logger.info(
            'No events found in device calendar. This might be normal if the calendar is empty or date range has no events.',
            tag: 'CalendarSyncService',
          );
        }
      }
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

  /// Remove all synced calendar events (for testing/cleanup)
  /// Returns the number of events deleted
  Future<int> removeAllSyncedEvents({bool resetLastSyncedAt = false}) async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      if (userModel == null || familyId == null) {
        throw AuthException('User not part of a family', code: 'no-family');
      }

      // Get all events with importedFromDevice = true
      final eventsRef = _firestore
          .collection('families')
          .doc(familyId)
          .collection('events');

      final snapshot = await eventsRef
          .where('importedFromDevice', isEqualTo: true)
          .get();

      final syncedEvents = snapshot.docs;
      Logger.info('Found ${syncedEvents.length} synced events to delete', tag: 'CalendarSyncService');

      if (syncedEvents.isEmpty) {
        Logger.info('No synced events to delete', tag: 'CalendarSyncService');
        return 0;
      }

      // Delete events in batches (Firestore batch limit is 500)
      int deletedCount = 0;
      const batchSize = 500;

      for (int i = 0; i < syncedEvents.length; i += batchSize) {
        final batch = _firestore.batch();
        final batchEnd = (i + batchSize < syncedEvents.length)
            ? i + batchSize
            : syncedEvents.length;

        for (int j = i; j < batchEnd; j++) {
          batch.delete(syncedEvents[j].reference);
        }

        await batch.commit();
        deletedCount += batchEnd - i;
        Logger.info('Deleted $deletedCount / ${syncedEvents.length} events...', tag: 'CalendarSyncService');
      }

      // Optionally reset lastSyncedAt
      if (resetLastSyncedAt) {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'lastSyncedAt': FieldValue.delete(),
          });
          Logger.info('Reset lastSyncedAt timestamp', tag: 'CalendarSyncService');
        }
      }

      Logger.info('Successfully deleted $deletedCount synced events', tag: 'CalendarSyncService');
      return deletedCount;
    } catch (e, st) {
      Logger.error('Error removing synced events', error: e, stackTrace: st, tag: 'CalendarSyncService');
      rethrow;
    }
  }
}
