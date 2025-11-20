import '../models/calendar_event.dart';

/// Service for handling recurring event expansion
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
    
    DateTime currentDate = event.startTime;
    int instanceCount = 0;
    const maxInstances = 100; // Safety limit

    while (currentDate.isBefore(endDate) && instanceCount < maxInstances) {
      final duration = event.endTime.difference(event.startTime);
      final instanceEnd = currentDate.add(duration);
      
      instances.add(event.copyWith(
        id: '${event.id}_${instanceCount}',
        startTime: currentDate,
        endTime: instanceEnd,
      ));

      // Calculate next occurrence based on recurrence rule
      currentDate = _getNextOccurrence(currentDate, event.recurrenceRule!);
      instanceCount++;
    }

    return instances;
  }

  /// Get the next occurrence date based on recurrence rule
  static DateTime _getNextOccurrence(DateTime current, String rule) {
    switch (rule.toLowerCase()) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        // Add one month, handling year rollover
        if (current.month == 12) {
          return DateTime(current.year + 1, 1, current.day);
        } else {
          return DateTime(current.year, current.month + 1, current.day);
        }
      case 'yearly':
        return DateTime(current.year + 1, current.month, current.day);
      default:
        // Default to weekly if unknown rule
        return current.add(const Duration(days: 7));
    }
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

