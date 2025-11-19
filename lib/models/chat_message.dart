class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final String? recipientId; // For private chats - null means family chat

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.recipientId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'type': type.toString().split('.').last,
        if (recipientId != null) 'recipientId': recipientId,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
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
      );
}

enum MessageType {
  text,
  image,
  location,
}

