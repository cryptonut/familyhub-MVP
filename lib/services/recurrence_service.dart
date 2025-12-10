import '../models/calendar_event.dart';
import 'recurrence_engine.dart';

/// Service for handling recurring event expansion
/// Uses RecurrenceEngine for robust recurrence calculation
class RecurrenceService {
  /// Expand a recurring event into individual instances
  /// Returns a list of CalendarEvent instances for the next N months
  static List<CalendarEvent> expandRecurringEvent(
    CalendarEvent event,
    {int monthsAhead = 6}
  ) {
    if (!event.isRecurring || event.recurrenceRule == null) {
      return [event];
    }

    final instances = <CalendarEvent>[];
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month + monthsAhead, now.day);
    
    // Use RecurrenceEngine to generate instances
    final occurrenceDates = RecurrenceEngine.generateInstances(
      startDate: event.startTime,
      endDate: endDate,
      recurrenceRule: event.recurrenceRule!,
    );

    // Create CalendarEvent instances for each occurrence
    final duration = event.endTime.difference(event.startTime);
    for (int i = 0; i < occurrenceDates.length; i++) {
      final occurrenceDate = occurrenceDates[i];
      final instanceEnd = occurrenceDate.add(duration);
      
      instances.add(event.copyWith(
        id: '${event.id}_instance_$i',
        startTime: occurrenceDate,
        endTime: instanceEnd,
      ));
    }

    return instances;
  }

  /// Get all events (including expanded recurring ones) for a date range
  static List<CalendarEvent> getAllEventsForRange(
    List<CalendarEvent> events,
    DateTime startDate,
    DateTime endDate,
  ) {
    final allInstances = <CalendarEvent>[];
    
    for (var event in events) {
      if (event.isRecurring) {
        // Expand recurring events
        final instances = expandRecurringEvent(event, monthsAhead: 12);
        // Filter to date range
        allInstances.addAll(
          instances.where((instance) =>
            instance.startTime.isAfter(startDate.subtract(const Duration(days: 1))) &&
            instance.startTime.isBefore(endDate.add(const Duration(days: 1)))
          )
        );
      } else {
        // Add non-recurring events if in range
        if (event.startTime.isAfter(startDate.subtract(const Duration(days: 1))) &&
            event.startTime.isBefore(endDate.add(const Duration(days: 1)))) {
          allInstances.add(event);
        }
      }
    }
    
    // Sort by start time
    allInstances.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    return allInstances;
  }
}

