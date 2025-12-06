import 'message_reaction.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final String? recipientId; // For private chats - null means family/hub chat
  final String? hubId; // For hub chats - null means family chat
  final String? audioUrl; // For voice messages
  final List<MessageReaction> reactions; // Emoji reactions
  final String? threadId; // If this is part of a thread
  final String? parentMessageId; // Message being replied to
  final int replyCount; // Number of replies in thread

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.recipientId,
    this.hubId,
    this.audioUrl,
    this.reactions = const [],
    this.threadId,
    this.parentMessageId,
    this.replyCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'type': type.toString().split('.').last,
        if (recipientId != null) 'recipientId': recipientId,
        if (hubId != null) 'hubId': hubId,
        if (audioUrl != null) 'audioUrl': audioUrl,
        'reactions': reactions.map((r) => r.toJson()).toList(),
        if (threadId != null) 'threadId': threadId,
        if (parentMessageId != null) 'parentMessageId': parentMessageId,
        'replyCount': replyCount,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final reactions = (json['reactions'] as List<dynamic>?)
            ?.map((r) => MessageReaction.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];
    
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MessageType.text,
      ),
      recipientId: json['recipientId'] as String?,
      hubId: json['hubId'] as String?,
      audioUrl: json['audioUrl'] as String?,
      reactions: reactions,
      threadId: json['threadId'] as String?,
      parentMessageId: json['parentMessageId'] as String?,
      replyCount: json['replyCount'] as int? ?? 0,
    );
  }
}

enum MessageType {
  text,
  image,
  location,
  voice,
}

