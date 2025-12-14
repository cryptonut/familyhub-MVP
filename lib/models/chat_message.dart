import 'message_reaction.dart';

/// Poll option for feed-style polls
class PollOption {
  final String id;
  final String text;
  final int voteCount;
  final List<String> voterIds; // Users who voted for this option

  PollOption({
    required this.id,
    required this.text,
    this.voteCount = 0,
    this.voterIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'voteCount': voteCount,
        'voterIds': voterIds,
      };

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
        id: json['id'] as String,
        text: json['text'] as String,
        voteCount: json['voteCount'] as int? ?? 0,
        voterIds: List<String>.from(json['voterIds'] as List? ?? []),
      );
}

/// URL preview metadata for link cards
class UrlPreview {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  UrlPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (siteName != null) 'siteName': siteName,
      };

  factory UrlPreview.fromJson(Map<String, dynamic> json) => UrlPreview(
        url: json['url'] as String,
        title: json['title'] as String?,
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        siteName: json['siteName'] as String?,
      );
}

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
  
  // Feed-style enhancements
  final PostType postType; // text, poll, media
  final List<PollOption>? pollOptions; // For poll posts
  final DateTime? pollExpiresAt; // Poll expiration
  final String? votedPollOptionId; // User's vote (if any)
  final int likeCount; // Engagement metrics
  final int shareCount;
  final int commentCount; // Total comments (including nested)
  final List<String> visibleHubIds; // Cross-hub visibility (empty = current hub only)
  final UrlPreview? urlPreview; // URL preview metadata
  final String? senderPhotoUrl; // Avatar URL for feed display
  
  // Encryption fields (Premium Feature)
  final bool isEncrypted; // Whether message is encrypted
  final DateTime? expiresAt; // Auto-destruct expiration time
  final Map<String, dynamic>? encryptedContent; // Encrypted message data (EncryptedMessage JSON)

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
    this.postType = PostType.text,
    this.pollOptions,
    this.pollExpiresAt,
    this.votedPollOptionId,
    this.likeCount = 0,
    this.shareCount = 0,
    this.commentCount = 0,
    this.visibleHubIds = const [],
    this.urlPreview,
    this.senderPhotoUrl,
    this.isEncrypted = false,
    this.expiresAt,
    this.encryptedContent,
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
        'postType': postType.name,
        if (pollOptions != null) 'pollOptions': pollOptions!.map((o) => o.toJson()).toList(),
        if (pollExpiresAt != null) 'pollExpiresAt': pollExpiresAt!.toIso8601String(),
        if (votedPollOptionId != null) 'votedPollOptionId': votedPollOptionId,
        'likeCount': likeCount,
        'shareCount': shareCount,
        'commentCount': commentCount,
        if (visibleHubIds.isNotEmpty) 'visibleHubIds': visibleHubIds,
        if (urlPreview != null) 'urlPreview': urlPreview!.toJson(),
        if (senderPhotoUrl != null) 'senderPhotoUrl': senderPhotoUrl,
        'isEncrypted': isEncrypted,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (encryptedContent != null) 'encryptedContent': encryptedContent,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final reactions = (json['reactions'] as List<dynamic>?)
            ?.map((r) => MessageReaction.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];
    
    final pollOptions = json['pollOptions'] != null
        ? (json['pollOptions'] as List<dynamic>)
            .map((o) => PollOption.fromJson(o as Map<String, dynamic>))
            .toList()
        : null;
    
    final urlPreview = json['urlPreview'] != null
        ? UrlPreview.fromJson(json['urlPreview'] as Map<String, dynamic>)
        : null;
    
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
      postType: json['postType'] != null
          ? PostType.values.firstWhere(
              (e) => e.name == json['postType'],
              orElse: () => PostType.text,
            )
          : PostType.text,
      pollOptions: pollOptions,
      pollExpiresAt: json['pollExpiresAt'] != null
          ? DateTime.parse(json['pollExpiresAt'] as String)
          : null,
      votedPollOptionId: json['votedPollOptionId'] as String?,
      likeCount: json['likeCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      visibleHubIds: List<String>.from(json['visibleHubIds'] as List? ?? []),
      urlPreview: urlPreview,
      senderPhotoUrl: json['senderPhotoUrl'] as String?,
      isEncrypted: json['isEncrypted'] as bool? ?? false,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      encryptedContent: json['encryptedContent'] != null
          ? Map<String, dynamic>.from(json['encryptedContent'] as Map)
          : null,
    );
  }
}

enum MessageType {
  text,
  image,
  location,
  voice,
}

/// Post type for feed-style messages
enum PostType {
  text,    // Regular text post
  poll,    // Poll post
  media,   // Media post (image/video)
  link,    // Link post with preview
}

