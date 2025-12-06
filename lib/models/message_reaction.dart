class MessageReaction {
  final String id;
  final String messageId;
  final String emoji; // Unicode emoji
  final String userId;
  final DateTime createdAt;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.emoji,
    required this.userId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'messageId': messageId,
        'emoji': emoji,
        'userId': userId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      id: json['id'] as String,
      messageId: json['messageId'] as String,
      emoji: json['emoji'] as String,
      userId: json['userId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

