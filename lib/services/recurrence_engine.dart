import '../core/services/logger_service.dart';

/// Service for handling calendar event recurrence
/// Supports both simple formats ("daily", "weekly", "monthly", "yearly") and RRULE format
class RecurrenceEngine {
  /// Generate recurring instances for an event
  /// Returns list of DateTime instances up to endDate
  static List<DateTime> generateInstances({
    required DateTime startDate,
    required DateTime endDate,
    required String recurrenceRule,
    DateTime? untilDate,
    int? count,
    List<DateTime>? exceptions, // Dates to exclude
  }) {
    try {
      final instances = <DateTime>[];
      final until = untilDate ?? (count != null ? null : endDate);
      final maxDate = until ?? endDate;
      final excludedDates = exceptions?.map((e) => _dateOnly(e)).toSet() ?? {};

      // Parse recurrence rule
      if (recurrenceRule.toLowerCase().startsWith('rrule:')) {
        // RRULE format - parse it
        return _parseRRULE(
          startDate: startDate,
          endDate: endDate,
          rrule: recurrenceRule.substring(6), // Remove "RRULE:" prefix
          until: until,
          count: count,
          exceptions: excludedDates,
        );
      } else {
        // Simple format: "daily", "weekly", "monthly", "yearly"
        return _parseSimpleRecurrence(
          startDate: startDate,
          endDate: maxDate,
          rule: recurrenceRule.toLowerCase(),
          count: count,
          exceptions: excludedDates,
        );
      }
    } catch (e, st) {
      Logger.error('Error generating recurrence instances', error: e, stackTrace: st, tag: 'RecurrenceEngine');
      return [];
    }
  }

  /// Parse simple recurrence format
  static List<DateTime> _parseSimpleRecurrence({
    required DateTime startDate,
    required DateTime endDate,
    required String rule,
    int? count,
    required Set<DateTime> exceptions,
  }) {
    final instances = <DateTime>[];
    var current = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    int instanceCount = 0;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      if (count != null && instanceCount >= count) break;
      if (!exceptions.contains(current)) {
        instances.add(current);
        instanceCount++;
      }

      // Increment based on rule
      switch (rule) {
        case 'daily':
          current = current.add(const Duration(days: 1));
          break;
        case 'weekly':
          current = current.add(const Duration(days: 7));
          break;
        case 'monthly':
          current = _addMonths(current, 1);
          break;
        case 'yearly':
          current = _addYears(current, 1);
          break;
        default:
          Logger.warning('Unknown recurrence rule: $rule', tag: 'RecurrenceEngine');
          return instances;
      }
    }

    return instances;
  }

  /// Parse RRULE format (simplified - handles common cases)
  static List<DateTime> _parseRRULE({
    required DateTime startDate,
    required DateTime endDate,
    required String rrule,
    DateTime? until,
    int? count,
    required Set<DateTime> exceptions,
  }) {
    // Parse RRULE parameters
    final params = <String, String>{};
    for (final part in rrule.split(';')) {
      final keyValue = part.split('=');
      if (keyValue.length == 2) {
        params[keyValue[0].toUpperCase()] = keyValue[1];
      }
    }

    final freq = params['FREQ']?.toUpperCase();
    if (freq == null) {
      Logger.warning('RRULE missing FREQ parameter', tag: 'RecurrenceEngine');
      return [];
    }

    final interval = int.tryParse(params['INTERVAL'] ?? '1') ?? 1;
    final untilDate = until ?? (params['UNTIL'] != null ? DateTime.tryParse(params['UNTIL']!) : null);
    final countLimit = count ?? (params['COUNT'] != null ? int.tryParse(params['COUNT']!) : null);
    final byDay = params['BYDAY']; // e.g., "MO,WE,FR"
    final byMonthDay = params['BYMONTHDAY']; // e.g., "1,15"

    final instances = <DateTime>[];
    var current = _dateOnly(startDate);
    final end = untilDate != null ? _dateOnly(untilDate) : _dateOnly(endDate);
    int instanceCount = 0;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      if (countLimit != null && instanceCount >= countLimit) break;
      if (!exceptions.contains(current)) {
        instances.add(current);
        instanceCount++;
      }

      // Increment based on frequency
      switch (freq) {
        case 'DAILY':
          current = current.add(Duration(days: interval));
          break;
        case 'WEEKLY':
          if (byDay != null) {
            // Handle specific days of week
            current = _nextWeekday(current, byDay.split(','), interval);
          } else {
            current = current.add(Duration(days: 7 * interval));
          }
          break;
        case 'MONTHLY':
          if (byMonthDay != null) {
            // Handle specific days of month
            current = _nextMonthDay(current, byMonthDay.split(',').map(int.parse).toList(), interval);
          } else {
            current = _addMonths(current, interval);
          }
          break;
        case 'YEARLY':
          current = _addYears(current, interval);
          break;
        default:
          Logger.warning('Unsupported RRULE FREQ: $freq', tag: 'RecurrenceEngine');
          return instances;
      }
    }

    return instances;
  }

  /// Add months to a date, handling month-end edge cases
  static DateTime _addMonths(DateTime date, int months) {
    var year = date.year;
    var month = date.month + months;
    var day = date.day;

    // Handle year overflow
    while (month > 12) {
      month -= 12;
      year++;
    }
    while (month < 1) {
      month += 12;
      year--;
    }

    // Handle day overflow (e.g., Jan 31 + 1 month = Feb 28/29)
    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (day > daysInMonth) {
      day = daysInMonth;
    }

    return DateTime(year, month, day);
  }

  /// Add years to a date
  static DateTime _addYears(DateTime date, int years) {
    var year = date.year + years;
    var month = date.month;
    var day = date.day;

    // Handle leap year edge case (Feb 29)
    if (month == 2 && day == 29) {
      final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      if (!isLeapYear) {
        day = 28;
      }
    }

    return DateTime(year, month, day);
  }

  /// Get next weekday occurrence
  static DateTime _nextWeekday(DateTime current, List<String> weekdays, int interval) {
    final weekdayMap = {
      'SU': 7, 'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6,
    };
    final targetWeekdays = weekdays.map((w) => weekdayMap[w.toUpperCase()]).whereType<int>().toSet();

    var next = current.add(const Duration(days: 1));
    int weeksPassed = 0;

    while (weeksPassed < interval * 10) { // Safety limit
      if (targetWeekdays.contains(next.weekday)) {
        return next;
      }
      next = next.add(const Duration(days: 1));
      if (next.weekday == 1) { // Monday - new week
        weeksPassed++;
      }
    }

    return current.add(Duration(days: 7 * interval));
  }

  /// Get next month day occurrence
  static DateTime _nextMonthDay(DateTime current, List<int> monthDays, int interval) {
    var next = _addMonths(current, interval);
    final targetDay = monthDays.first; // Use first day for simplicity
    final daysInMonth = DateTime(next.year, next.month + 1, 0).day;
    final day = targetDay > daysInMonth ? daysInMonth : targetDay;
    return DateTime(next.year, next.month, day);
  }

  /// Convert DateTime to date-only (midnight)
  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Check if a date matches a recurrence pattern
  static bool isRecurringInstance({
    required DateTime eventStart,
    required DateTime checkDate,
    required String recurrenceRule,
    List<DateTime>? exceptions,
  }) {
    try {
      final instances = generateInstances(
        startDate: eventStart,
        endDate: checkDate.add(const Duration(days: 365)), // Check up to a year ahead
        recurrenceRule: recurrenceRule,
        exceptions: exceptions,
      );

      final checkDateOnly = _dateOnly(checkDate);
      return instances.any((instance) => _dateOnly(instance).isAtSameMomentAs(checkDateOnly));
    } catch (e) {
      Logger.warning('Error checking if date is recurring instance', error: e, tag: 'RecurrenceEngine');
      return false;
    }
  }

  /// Get the next occurrence after a given date
  static DateTime? getNextOccurrence({
    required DateTime eventStart,
    required DateTime afterDate,
    required String recurrenceRule,
    List<DateTime>? exceptions,
  }) {
    try {
      final instances = generateInstances(
        startDate: eventStart,
        endDate: afterDate.add(const Duration(days: 365)),
        recurrenceRule: recurrenceRule,
        exceptions: exceptions,
      );

      for (final instance in instances) {
        if (instance.isAfter(afterDate)) {
          return instance;
        }
      }
      return null;
    } catch (e) {
      Logger.warning('Error getting next occurrence', error: e, tag: 'RecurrenceEngine');
      return null;
    }
  }
}

