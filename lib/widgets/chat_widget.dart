import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../core/services/logger_service.dart';
import 'linkable_text.dart';

/// A reusable chat widget that can be embedded in pages
/// Supports both hub chat and family chat
class ChatWidget extends StatefulWidget {
  final Stream<List<ChatMessage>> messagesStream;
  final Future<void> Function(String message) onSendMessage;
  final String? currentUserId;
  final String? currentUserName;
  final double? maxHeight; // Max height when embedded (null = full height)
  final VoidCallback? onViewFullChat; // Callback to navigate to full chat screen
  final String emptyStateMessage;

  const ChatWidget({
    super.key,
    required this.messagesStream,
    required this.onSendMessage,
    this.currentUserId,
    this.currentUserName,
    this.maxHeight,
    this.onViewFullChat,
    this.emptyStateMessage = 'No messages yet. Start the conversation!',
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isExpanded = false;
  List<ChatMessage> _messages = [];
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Subscribe to the stream once and cache messages
    _messagesSubscription = widget.messagesStream.listen(
      (messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
          // Scroll to bottom when new messages arrive
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      },
      onError: (error) {
        Logger.error('ChatWidget stream error', error: error, tag: 'ChatWidget');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      
      try {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _scrollController.jumpTo(maxScroll);
        }
      } catch (e) {
        Logger.warning('Scroll error', error: e, tag: 'ChatWidget');
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || !mounted) return;

    if (widget.currentUserId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to send messages')),
      );
      return;
    }

    try {
      await widget.onSendMessage(text);
      if (mounted) {
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  bool _isCurrentUser(String senderId) {
    return widget.currentUserId != null && senderId == widget.currentUserId;
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).primaryColor
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),
                  if (!isMe) const SizedBox(height: 4),
                  LinkableText(
                    text: message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app_date_utils.AppDateUtils.formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.emptyStateMessage,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = _isCurrentUser(message.senderId);
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildLastMessageRow() {
    if (_messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final message = _messages.last;
    final isMe = _isCurrentUser(message.senderId);
    final maxLength = 60;
    final messageText = message.content;
    final truncatedText = messageText.length > maxLength
        ? '${messageText.substring(0, maxLength)}...'
        : messageText;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.grey.shade900.withOpacity(0.5)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? Colors.grey.shade800
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isMe 
                  ? theme.primaryColor.withOpacity(0.2)
                  : Colors.grey.shade300.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isMe 
                      ? theme.primaryColor
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isMe ? 'You' : message.senderName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark 
                            ? Colors.grey.shade200
                            : Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      app_date_utils.AppDateUtils.formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  truncatedText,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark 
                        ? Colors.grey.shade400
                        : Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Last message preview - always show if messages exist
          _buildLastMessageRow(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade600
                            : Colors.grey.shade300,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade600
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.send,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: _sendMessage,
                      tooltip: 'Send message',
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmbedded = widget.maxHeight != null;
    
    // If embedded with max height, make it collapsible
    if (isEmbedded) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade700
                : Theme.of(context).primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with expand/collapse and view full chat
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade800.withOpacity(0.8)
                      : Theme.of(context).primaryColor.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.onViewFullChat != null)
                      Flexible(
                        child: TextButton(
                          onPressed: widget.onViewFullChat,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('View Full', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            // Chat content - animated expand/collapse
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _isExpanded
                    ? SizedBox(
                        height: widget.maxHeight,
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildMessagesList(),
                            ),
                            _buildMessageInput(),
                          ],
                        ),
                      )
                    : _buildMessageInput(), // Show last message and input even when minimized
              ),
            ),
          ],
        ),
      );
    }

    // Full height (for full screen)
    return Column(
      children: [
        Expanded(child: _buildMessagesList()),
        _buildMessageInput(),
      ],
    );
  }
}
