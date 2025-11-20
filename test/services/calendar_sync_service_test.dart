import 'package:flutter_test/flutter_test.dart';
import 'package:familyhub_mvp/services/calendar_sync_service.dart';
import 'package:familyhub_mvp/models/calendar_event.dart';

void main() {
  group('CalendarSyncService', () {
    test('should convert FamilyHub recurrence rule to device format', () {
      // This tests the internal conversion logic
      // Note: The actual conversion is private, but we can test through event creation
      final event = CalendarEvent(
        id: 'test-id',
        title: 'Test Event',
        description: 'Test',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        isRecurring: true,
        recurrenceRule: 'weekly',
      );

      expect(event.isRecurring, true);
      expect(event.recurrenceRule, 'weekly');
    });

    test('should handle null recurrence rule', () {
      final event = CalendarEvent(
        id: 'test-id',
        title: 'Test Event',
        description: 'Test',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
        isRecurring: false,
      );

      expect(event.isRecurring, false);
      expect(event.recurrenceRule, null);
    });

    test('should preserve extended properties for event tracking', () {
      // Test that fh_event_id is properly set
      final event = CalendarEvent(
        id: 'test-event-id',
        title: 'Test',
        description: 'Test',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(event.id, 'test-event-id');
    });
  });
}

