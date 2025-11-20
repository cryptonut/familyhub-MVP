class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final List<String> participants;
  final String color;
  final bool isRecurring;
  final String? recurrenceRule; // Simple format: "daily", "weekly", "monthly", "yearly" or RRULE format
  final List<String> invitedMemberIds;
  final Map<String, String> rsvpStatus; // memberId -> "going"/"maybe"/"declined"

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.participants = const [],
    this.color = '#2196F3',
    this.isRecurring = false,
    this.recurrenceRule,
    List<String>? invitedMemberIds,
    Map<String, String>? rsvpStatus,
  }) : invitedMemberIds = invitedMemberIds ?? const [],
       rsvpStatus = rsvpStatus ?? const {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'location': location,
        'participants': participants,
        'color': color,
        'isRecurring': isRecurring,
        if (recurrenceRule != null) 'recurrenceRule': recurrenceRule,
        'invitedMemberIds': invitedMemberIds,
        'rsvpStatus': rsvpStatus,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    // Handle rsvpStatus - could be Map<String, dynamic> or Map<String, String>
    Map<String, String> rsvpStatus = {};
    if (json['rsvpStatus'] != null) {
      final rsvpData = json['rsvpStatus'] as Map;
      rsvpStatus = rsvpData.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      location: json['location'] as String?,
      participants: List<String>.from(json['participants'] as List? ?? []),
      color: json['color'] as String? ?? '#2196F3',
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurrenceRule: json['recurrenceRule'] as String?,
      invitedMemberIds: List<String>.from(json['invitedMemberIds'] as List? ?? []),
      rsvpStatus: rsvpStatus,
    );
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    List<String>? participants,
    String? color,
    bool? isRecurring,
    String? recurrenceRule,
    List<String>? invitedMemberIds,
    Map<String, String>? rsvpStatus,
  }) =>
      CalendarEvent(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        location: location ?? this.location,
        participants: participants ?? this.participants,
        color: color ?? this.color,
        isRecurring: isRecurring ?? this.isRecurring,
        recurrenceRule: recurrenceRule ?? this.recurrenceRule,
        invitedMemberIds: invitedMemberIds ?? this.invitedMemberIds,
        rsvpStatus: rsvpStatus ?? this.rsvpStatus,
      );
}

