import 'dart:convert';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/chat_message.dart';
import 'chat_service.dart';
import 'encryption_service.dart';
import 'message_expiration_service.dart';
import 'auth_service.dart';

/// Service wrapper that adds encryption functionality to ChatService
/// Only available for premium subscribers
class EncryptedChatService {
  final ChatService _chatService;
  final EncryptionService _encryptionService;
  final MessageExpirationService _expirationService;
  final AuthService _authService;
  
  EncryptedChatService({
    ChatService? chatService,
    EncryptionService? encryptionService,
    MessageExpirationService? expirationService,
    AuthService? authService,
  })  : _chatService = chatService ?? ChatService(),
        _encryptionService = encryptionService ?? EncryptionService(),
        _expirationService = expirationService ?? MessageExpirationService(),
        _authService = authService ?? AuthService();
  
  /// Check if user has premium subscription and encryption access
  Future<bool> _checkEncryptionAccess() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return false;
      
      // Check if user has active premium subscription
      return userModel.hasActivePremiumSubscription();
    } catch (e) {
      Logger.error('Error checking encryption access', error: e, tag: 'EncryptedChatService');
      return false;
    }
  }
  
  /// Get conversation ID for encryption key management
  String _getConversationId(String? hubId, String? recipientId) {
    if (hubId != null) {
      return 'hub_$hubId';
    } else if (recipientId != null) {
      // For private chats, use sorted user IDs
      final currentUserId = _chatService.currentUserId;
      if (currentUserId == null) return 'private_$recipientId';
      final sorted = [currentUserId, recipientId]..sort();
      return 'private_${sorted[0]}_${sorted[1]}';
    } else {
      // Family chat
      return 'family';
    }
  }
  
  /// Send an encrypted message
  Future<void> sendEncryptedMessage({
    required ChatMessage message,
    Duration? expirationDuration, // Optional auto-destruct duration
  }) async {
    // Check premium access
    final hasAccess = await _checkEncryptionAccess();
    if (!hasAccess) {
      throw PermissionException(
        'Encrypted chat requires Premium subscription',
        code: 'premium-required',
      );
    }
    
    try {
      // Initialize encryption service if needed
      await _encryptionService.initialize();
      
      // Get conversation ID
      final conversationId = _getConversationId(message.hubId, message.recipientId);
      
      // Encrypt the message content
      final encryptedContentJson = await _encryptionService.encryptMessage(
        message.content,
        conversationId,
      );
      
      // Parse encrypted content
      final encryptedContent = Map<String, dynamic>.from(
        jsonDecode(encryptedContentJson) as Map,
      );
      
      // Calculate expiration if provided
      DateTime? expiresAt;
      if (expirationDuration != null) {
        expiresAt = MessageExpirationService.calculateExpiration(
          DateTime.now(),
          expirationDuration,
        );
      }
      
      // Create encrypted message
      final encryptedMessage = ChatMessage(
        id: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        content: '[Encrypted]', // Placeholder - actual content is in encryptedContent
        timestamp: message.timestamp,
        type: message.type,
        recipientId: message.recipientId,
        hubId: message.hubId,
        audioUrl: message.audioUrl,
        reactions: message.reactions,
        threadId: message.threadId,
        parentMessageId: message.parentMessageId,
        replyCount: message.replyCount,
        postType: message.postType,
        pollOptions: message.pollOptions,
        pollExpiresAt: message.pollExpiresAt,
        votedPollOptionId: message.votedPollOptionId,
        likeCount: message.likeCount,
        shareCount: message.shareCount,
        commentCount: message.commentCount,
        visibleHubIds: message.visibleHubIds,
        urlPreview: message.urlPreview,
        senderPhotoUrl: message.senderPhotoUrl,
        isEncrypted: true,
        expiresAt: expiresAt,
        encryptedContent: encryptedContent,
      );
      
      // Send via ChatService - use sendPrivateMessage for private chats
      if (encryptedMessage.recipientId != null) {
        await _chatService.sendPrivateMessage(encryptedMessage, encryptedMessage.recipientId!);
      } else {
        await _chatService.sendMessage(encryptedMessage);
      }
      
      Logger.info('Encrypted message sent', tag: 'EncryptedChatService');
    } catch (e) {
      Logger.error('Error sending encrypted message', error: e, tag: 'EncryptedChatService');
      rethrow;
    }
  }
  
  /// Decrypt a message
  Future<String> decryptMessage(ChatMessage message) async {
    if (!message.isEncrypted || message.encryptedContent == null) {
      return message.content; // Not encrypted, return as-is
    }
    
    try {
      // Initialize encryption service if needed
      await _encryptionService.initialize();
      
      // Get conversation ID
      final conversationId = _getConversationId(message.hubId, message.recipientId);
      
      // Decrypt the message
      final encryptedContentJson = jsonEncode(message.encryptedContent);
      final decryptedContent = await _encryptionService.decryptMessage(
        encryptedContentJson,
        conversationId,
      );
      
      return decryptedContent;
    } catch (e) {
      Logger.error('Error decrypting message', error: e, tag: 'EncryptedChatService');
      return '[Unable to decrypt message]';
    }
  }
  
  /// Check if encryption is enabled for a conversation
  Future<bool> isEncryptionEnabled(String? hubId, String? recipientId) async {
    try {
      final conversationId = _getConversationId(hubId, recipientId);
      return await _encryptionService.isEncryptionEnabled(conversationId);
    } catch (e) {
      Logger.error('Error checking encryption status', error: e, tag: 'EncryptedChatService');
      return false;
    }
  }
  
  /// Enable encryption for a conversation
  Future<void> enableEncryption(String? hubId, String? recipientId) async {
    final hasAccess = await _checkEncryptionAccess();
    if (!hasAccess) {
      throw PermissionException(
        'Encrypted chat requires Premium subscription',
        code: 'premium-required',
      );
    }
    
    try {
      await _encryptionService.initialize();
      final conversationId = _getConversationId(hubId, recipientId);
      await _encryptionService.generateSharedKey(conversationId);
      Logger.info('Encryption enabled for conversation: $conversationId', tag: 'EncryptedChatService');
    } catch (e) {
      Logger.error('Error enabling encryption', error: e, tag: 'EncryptedChatService');
      rethrow;
    }
  }
  
  /// Disable encryption for a conversation
  Future<void> disableEncryption(String? hubId, String? recipientId) async {
    try {
      final conversationId = _getConversationId(hubId, recipientId);
      await _encryptionService.deleteConversationKeys(conversationId);
      Logger.info('Encryption disabled for conversation: $conversationId', tag: 'EncryptedChatService');
    } catch (e) {
      Logger.error('Error disabling encryption', error: e, tag: 'EncryptedChatService');
      rethrow;
    }
  }
  
  /// Get remaining time until message expiration
  Duration? getRemainingTime(ChatMessage message) {
    return MessageExpirationService.getRemainingTime(message.expiresAt);
  }
  
  /// Format remaining time as human-readable string
  String formatRemainingTime(ChatMessage message) {
    final remaining = getRemainingTime(message);
    return MessageExpirationService.formatRemainingTime(remaining);
  }
  
  /// Expose ChatService methods
  Stream<List<ChatMessage>> getMessagesStream() => _chatService.getMessagesStream();
  String? get currentUserId => _chatService.currentUserId;
  String? get currentUserName => _chatService.currentUserName;
}

