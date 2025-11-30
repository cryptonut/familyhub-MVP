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
  final String? createdBy; // User ID of event creator
  final List<String> photoUrls; // URLs of photos attached to event
  final String? sourceCalendar; // Calendar name/account where event originated (e.g., "Gmail", "Samsung Calendar", "FamilyHub")

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
    this.createdBy,
    List<String>? photoUrls,
    this.sourceCalendar,
  }) : invitedMemberIds = invitedMemberIds ?? const [],
       rsvpStatus = rsvpStatus ?? const {},
       photoUrls = photoUrls ?? const [];

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
        if (createdBy != null) 'createdBy': createdBy,
        'photoUrls': photoUrls,
        if (sourceCalendar != null) 'sourceCalendar': sourceCalendar,
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
      description: (json['description'] as String?) ?? '',
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      location: json['location'] as String?,
      participants: List<String>.from(json['participants'] as List? ?? []),
      color: json['color'] as String? ?? '#2196F3',
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurrenceRule: json['recurrenceRule'] as String?,
      invitedMemberIds: List<String>.from(json['invitedMemberIds'] as List? ?? []),
      rsvpStatus: rsvpStatus,
      createdBy: json['createdBy'] as String?,
      photoUrls: List<String>.from(json['photoUrls'] as List? ?? []),
      sourceCalendar: json['sourceCalendar'] as String?,
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
    String? createdBy,
    List<String>? photoUrls,
    String? sourceCalendar,
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
        createdBy: createdBy ?? this.createdBy,
        photoUrls: photoUrls ?? this.photoUrls,
        sourceCalendar: sourceCalendar ?? this.sourceCalendar,
      );
}

