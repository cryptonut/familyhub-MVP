import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../services/encrypted_chat_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../widgets/linkable_text.dart';
import '../../widgets/message_reaction_widget.dart';
import '../../widgets/emoji_picker_bottom_sheet.dart';
import '../../services/message_reaction_service.dart';
import 'package:uuid/uuid.dart';

class PrivateChatScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;

  const PrivateChatScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  late final EncryptedChatService _encryptedChatService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _familyId;
  String? _chatId;
  bool _encryptMessage = false;

  @override
  void initState() {
    super.initState();
    _encryptedChatService = EncryptedChatService(chatService: _chatService);
    _loadFamilyAndChatId();
    // Mark messages as read when the chat screen is opened
    _markMessagesAsRead();
  }

  Future<void> _loadFamilyAndChatId() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel?.familyId != null) {
        setState(() {
          _familyId = userModel!.familyId;
          // For private messages, chatId is typically the sorted participant IDs
          final currentUserId = _chatService.currentUserId;
          if (currentUserId != null) {
            final participants = [currentUserId, widget.recipientId]..sort();
            _chatId = participants.join('_');
          }
        });
      }
    } catch (e) {
      Logger.warning('Error loading family/chat ID', error: e, tag: 'PrivateChatScreen');
    }
  }
  
  Future<void> _markMessagesAsRead() async {
    try {
      await _chatService.markMessagesAsRead(widget.recipientId);
    } catch (e) {
      Logger.warning('Error marking messages as read', error: e, tag: 'PrivateChatScreen');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!mounted) return;
    // Use a small delay to ensure window is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      
      try {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _scrollController.jumpTo(maxScroll);
        }
      } catch (e) {
        // Ignore scroll errors
        Logger.warning('Scroll error', error: e, tag: 'PrivateChatScreen');
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !mounted) return;

    final currentUserId = _chatService.currentUserId;
    final currentUserName = _chatService.currentUserName ?? 'You';

    if (currentUserId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to send messages'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final message = ChatMessage(
        id: const Uuid().v4(),
        senderId: currentUserId,
        senderName: currentUserName,
        content: text,
        timestamp: DateTime.now(),
        recipientId: widget.recipientId,
        isEncrypted: _encryptMessage,
      );

      if (_encryptMessage) {
        // Send encrypted message
        await _encryptedChatService.sendEncryptedMessage(
          message: message,
          expirationDuration: null, // No auto-destruct for now
        );
      } else {
        // Send regular message
        await _chatService.sendPrivateMessage(message, widget.recipientId);
      }
      if (mounted) {
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isCurrentUser(String senderId) {
    return senderId == _chatService.currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
              child: Text(
                widget.recipientName.isNotEmpty 
                    ? widget.recipientName[0].toUpperCase() 
                    : '?',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.recipientName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<ChatMessage>>(
          stream: _chatService.getPrivateMessagesStream(widget.recipientId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error: ${snapshot.error}'),
                ),
              );
            }

            final messages = snapshot.data ?? [];

            // Mark messages as read when new messages arrive while chat is open
            if (messages.isNotEmpty && mounted) {
              // Check if the latest message is from the recipient (not current user)
              final latestMessage = messages.last;
              final currentUserId = _chatService.currentUserId;
              if (latestMessage.senderId != currentUserId) {
                // Mark as read when new message from recipient arrives
                _markMessagesAsRead();
              }
              
              // Scroll to bottom
              Future.microtask(() {
                if (mounted) {
                  _scrollToBottom();
                }
              });
            }

            return Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start a conversation with ${widget.recipientName}!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isCurrentUser = _isCurrentUser(message.senderId);
                            return _buildMessageBubble(message, isCurrentUser);
                          },
                        ),
                ),
                _buildMessageInput(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isCurrentUser) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () {
              // Show emoji picker on long press
              if (_familyId != null && _chatId != null) {
                _showEmojiPickerForMessage(message.id);
              }
            },
            child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrentUser ? Colors.blue : Colors.grey[300]!,
              borderRadius: BorderRadius.circular(20),
            ),
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * 0.7,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCurrentUser ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    // Encryption indicator
                    if (message.isEncrypted) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.lock,
                        size: 12,
                        color: isCurrentUser
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ],
                    // Expiration indicator
                    if (message.expiresAt != null && message.expiresAt!.isAfter(DateTime.now())) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: isCurrentUser
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                LinkableText(
                  text: message.content,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  app_date_utils.AppDateUtils.formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isCurrentUser
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
                if (_familyId != null && _chatId != null) ...[
                  const SizedBox(height: 4),
                  MessageReactionWidget(
                    messageId: message.id,
                    familyId: _familyId!,
                    chatId: _chatId,
                    isCurrentUser: isCurrentUser,
                  ),
                ],
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  void _showEmojiPickerForMessage(String messageId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => EmojiPickerBottomSheet(
        onEmojiSelected: (emoji) async {
          Navigator.pop(context);
          if (_familyId != null && _chatId != null) {
            try {
              final reactionService = MessageReactionService();
              await reactionService.addReaction(
                messageId,
                emoji,
                _familyId!,
                chatId: _chatId,
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding reaction: $e')),
                );
              }
            }
          }
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Encryption toggle button
            IconButton(
              icon: Icon(
                _encryptMessage ? Icons.lock : Icons.lock_open,
                color: _encryptMessage
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _encryptMessage = !_encryptMessage;
                });
              },
              tooltip: _encryptMessage
                  ? 'Encryption enabled - tap to disable'
                  : 'Encryption disabled - tap to enable',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: _encryptMessage
                      ? 'Encrypted message...'
                      : 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

