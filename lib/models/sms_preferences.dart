import 'package:cloud_firestore/cloud_firestore.dart';

/// SMS notification preferences for a user
class SmsPreferences {
  final String userId;
  final bool enabled; // Master toggle for SMS notifications
  final String? phoneNumber; // User's phone number (E.164 format)
  final bool phoneNumberVerified; // Whether phone number is verified
  
  // Granular controls per notification type
  final bool eventRemindersEnabled;
  final List<Duration> eventReminderTimes; // e.g., [15 min, 1 hour, 1 day]
  
  final bool taskDeadlinesEnabled;
  final bool taskApprovalsEnabled;
  
  final bool newMessagesEnabled; // Only when app is closed/offline
  final bool locationAlertsEnabled;
  final bool emergencyNotificationsEnabled; // Always enabled if SMS is enabled
  
  // Rate limiting
  final int maxSmsPerDay; // Maximum SMS per day (default: 10 for free, unlimited for premium)
  final int maxSmsPerHour; // Maximum SMS per hour (default: 3)
  
  // Quiet hours
  final bool quietHoursEnabled;
  final int? quietHoursStart; // Hour of day (0-23)
  final int? quietHoursEnd; // Hour of day (0-23)
  
  // Cost tracking
  final int smsCountThisMonth; // SMS sent this month
  final DateTime? lastSmsSentAt;
  final DateTime updatedAt;

  SmsPreferences({
    required this.userId,
    this.enabled = false,
    this.phoneNumber,
    this.phoneNumberVerified = false,
    this.eventRemindersEnabled = false,
    List<Duration>? eventReminderTimes,
    this.taskDeadlinesEnabled = false,
    this.taskApprovalsEnabled = false,
    this.newMessagesEnabled = false,
    this.locationAlertsEnabled = false,
    this.emergencyNotificationsEnabled = true, // Default to true
    this.maxSmsPerDay = 10, // Free tier default
    this.maxSmsPerHour = 3,
    this.quietHoursEnabled = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.smsCountThisMonth = 0,
    this.lastSmsSentAt,
    DateTime? updatedAt,
  }) : eventReminderTimes = eventReminderTimes ?? [const Duration(minutes: 15)],
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'enabled': enabled,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        'phoneNumberVerified': phoneNumberVerified,
        'eventRemindersEnabled': eventRemindersEnabled,
        'eventReminderTimes': eventReminderTimes.map((d) => d.inMinutes).toList(),
        'taskDeadlinesEnabled': taskDeadlinesEnabled,
        'taskApprovalsEnabled': taskApprovalsEnabled,
        'newMessagesEnabled': newMessagesEnabled,
        'locationAlertsEnabled': locationAlertsEnabled,
        'emergencyNotificationsEnabled': emergencyNotificationsEnabled,
        'maxSmsPerDay': maxSmsPerDay,
        'maxSmsPerHour': maxSmsPerHour,
        'quietHoursEnabled': quietHoursEnabled,
        if (quietHoursStart != null) 'quietHoursStart': quietHoursStart,
        if (quietHoursEnd != null) 'quietHoursEnd': quietHoursEnd,
        'smsCountThisMonth': smsCountThisMonth,
        if (lastSmsSentAt != null) 'lastSmsSentAt': lastSmsSentAt!.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SmsPreferences.fromJson(Map<String, dynamic> json) {
    // Parse event reminder times
    List<Duration> reminderTimes = [];
    if (json['eventReminderTimes'] != null && json['eventReminderTimes'] is List) {
      reminderTimes = (json['eventReminderTimes'] as List)
          .map((m) => Duration(minutes: m as int))
          .toList();
    }

    // Parse dates
    DateTime? lastSmsSentAt;
    if (json['lastSmsSentAt'] != null) {
      final value = json['lastSmsSentAt'];
      if (value is Timestamp) {
        lastSmsSentAt = value.toDate();
      } else if (value is String) {
        lastSmsSentAt = DateTime.parse(value);
      }
    }

    DateTime updatedAt = DateTime.now();
    if (json['updatedAt'] != null) {
      final value = json['updatedAt'];
      if (value is Timestamp) {
        updatedAt = value.toDate();
      } else if (value is String) {
        updatedAt = DateTime.parse(value);
      }
    }

    return SmsPreferences(
      userId: json['userId'] as String,
      enabled: json['enabled'] as bool? ?? false,
      phoneNumber: json['phoneNumber'] as String?,
      phoneNumberVerified: json['phoneNumberVerified'] as bool? ?? false,
      eventRemindersEnabled: json['eventRemindersEnabled'] as bool? ?? false,
      eventReminderTimes: reminderTimes,
      taskDeadlinesEnabled: json['taskDeadlinesEnabled'] as bool? ?? false,
      taskApprovalsEnabled: json['taskApprovalsEnabled'] as bool? ?? false,
      newMessagesEnabled: json['newMessagesEnabled'] as bool? ?? false,
      locationAlertsEnabled: json['locationAlertsEnabled'] as bool? ?? false,
      emergencyNotificationsEnabled: json['emergencyNotificationsEnabled'] as bool? ?? true,
      maxSmsPerDay: json['maxSmsPerDay'] as int? ?? 10,
      maxSmsPerHour: json['maxSmsPerHour'] as int? ?? 3,
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
      quietHoursStart: json['quietHoursStart'] as int?,
      quietHoursEnd: json['quietHoursEnd'] as int?,
      smsCountThisMonth: json['smsCountThisMonth'] as int? ?? 0,
      lastSmsSentAt: lastSmsSentAt,
      updatedAt: updatedAt,
    );
  }

  SmsPreferences copyWith({
    String? userId,
    bool? enabled,
    String? phoneNumber,
    bool? phoneNumberVerified,
    bool? eventRemindersEnabled,
    List<Duration>? eventReminderTimes,
    bool? taskDeadlinesEnabled,
    bool? taskApprovalsEnabled,
    bool? newMessagesEnabled,
    bool? locationAlertsEnabled,
    bool? emergencyNotificationsEnabled,
    int? maxSmsPerDay,
    int? maxSmsPerHour,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    int? smsCountThisMonth,
    DateTime? lastSmsSentAt,
    DateTime? updatedAt,
  }) {
    return SmsPreferences(
      userId: userId ?? this.userId,
      enabled: enabled ?? this.enabled,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneNumberVerified: phoneNumberVerified ?? this.phoneNumberVerified,
      eventRemindersEnabled: eventRemindersEnabled ?? this.eventRemindersEnabled,
      eventReminderTimes: eventReminderTimes ?? this.eventReminderTimes,
      taskDeadlinesEnabled: taskDeadlinesEnabled ?? this.taskDeadlinesEnabled,
      taskApprovalsEnabled: taskApprovalsEnabled ?? this.taskApprovalsEnabled,
      newMessagesEnabled: newMessagesEnabled ?? this.newMessagesEnabled,
      locationAlertsEnabled: locationAlertsEnabled ?? this.locationAlertsEnabled,
      emergencyNotificationsEnabled: emergencyNotificationsEnabled ?? this.emergencyNotificationsEnabled,
      maxSmsPerDay: maxSmsPerDay ?? this.maxSmsPerDay,
      maxSmsPerHour: maxSmsPerHour ?? this.maxSmsPerHour,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      smsCountThisMonth: smsCountThisMonth ?? this.smsCountThisMonth,
      lastSmsSentAt: lastSmsSentAt ?? this.lastSmsSentAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

