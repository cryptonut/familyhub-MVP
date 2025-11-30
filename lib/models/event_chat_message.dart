/// Model for event-specific chat messages
class EventChatMessage {
  final String id;
  final String eventId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final DateTime? editedAt;
  final String? parentMessageId; // For threaded replies
  final List<String> mentionedUserIds; // For @mentions
  final bool isDeleted;
  final String? deletedBy; // Admin who deleted (for moderation)

  EventChatMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.editedAt,
    this.parentMessageId,
    List<String>? mentionedUserIds,
    this.isDeleted = false,
    this.deletedBy,
  }) : mentionedUserIds = mentionedUserIds ?? const [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
        if (parentMessageId != null) 'parentMessageId': parentMessageId,
        'mentionedUserIds': mentionedUserIds,
        'isDeleted': isDeleted,
        if (deletedBy != null) 'deletedBy': deletedBy,
      };

  factory EventChatMessage.fromJson(Map<String, dynamic> json) =>
      EventChatMessage(
        id: json['id'] as String,
        eventId: json['eventId'] as String,
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        editedAt: json['editedAt'] != null
            ? DateTime.parse(json['editedAt'] as String)
            : null,
        parentMessageId: json['parentMessageId'] as String?,
        mentionedUserIds: List<String>.from(
          json['mentionedUserIds'] as List? ?? [],
        ),
        isDeleted: json['isDeleted'] as bool? ?? false,
        deletedBy: json['deletedBy'] as String?,
      );

  EventChatMessage copyWith({
    String? id,
    String? eventId,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    DateTime? editedAt,
    String? parentMessageId,
    List<String>? mentionedUserIds,
    bool? isDeleted,
    String? deletedBy,
  }) =>
      EventChatMessage(
        id: id ?? this.id,
        eventId: eventId ?? this.eventId,
        senderId: senderId ?? this.senderId,
        senderName: senderName ?? this.senderName,
        content: content ?? this.content,
        timestamp: timestamp ?? this.timestamp,
        editedAt: editedAt ?? this.editedAt,
        parentMessageId: parentMessageId ?? this.parentMessageId,
        mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedBy: deletedBy ?? this.deletedBy,
      );
}


