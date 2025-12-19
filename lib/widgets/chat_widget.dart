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
  final String? hubId; // For like functionality
  final Future<void> Function(String messageId)? onLike; // Like callback

  const ChatWidget({
    super.key,
    required this.messagesStream,
    required this.onSendMessage,
    this.currentUserId,
    this.currentUserName,
    this.maxHeight,
    this.onViewFullChat,
    this.emptyStateMessage = 'No messages yet. Start the conversation!',
    this.hubId,
    this.onLike,
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
    _subscribeToStream();
  }

  @override
  void didUpdateWidget(ChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If stream changed, resubscribe (but preserve state like _isExpanded)
    if (oldWidget.messagesStream != widget.messagesStream) {
      _messagesSubscription?.cancel();
      _subscribeToStream();
    }
  }

  void _subscribeToStream() {
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
    final theme = Theme.of(context);
    
    // X-style feed layout (no chat bubbles)
    return InkWell(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar (always on left, X-style)
            CircleAvatar(
              radius: 23,
              backgroundImage: message.senderPhotoUrl != null
                  ? NetworkImage(message.senderPhotoUrl!)
                  : null,
              backgroundColor: theme.colorScheme.primary,
              child: message.senderPhotoUrl == null
                  ? Text(
                      message.senderName.isNotEmpty
                          ? message.senderName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author info row
                  Row(
                    children: [
                      Text(
                        message.senderName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        app_date_utils.AppDateUtils.getRelativeTime(message.timestamp),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Message content
                  LinkableText(
                    text: message.content,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      height: 1.4,
                      color: theme.colorScheme.onSurface, // Ensure text is visible in dark mode
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Engagement row (like button only for feed-style posts)
                  if (widget.onLike != null && message.parentMessageId == null)
                    Row(
                      children: [
                        _buildLikeButton(message, theme),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikeButton(ChatMessage message, ThemeData theme) {
    final isLiked = message.reactions.any((r) => r.userId == widget.currentUserId && r.emoji == '❤️');
    final likeCount = message.likeCount > 0 ? message.likeCount : (isLiked ? 1 : 0);

    return InkWell(
      onTap: () async {
        if (widget.onLike != null) {
          try {
            await widget.onLike!(message.id);
            // Refresh UI by triggering rebuild
            if (mounted) {
              setState(() {});
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error liking: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              size: 18.75,
              color: isLiked 
                  ? theme.colorScheme.error 
                  : theme.brightness == Brightness.dark
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            if (likeCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                _formatCount(likeCount),
                style: TextStyle(
                  fontSize: 13,
                  color: isLiked 
                      ? theme.colorScheme.error 
                      : theme.brightness == Brightness.dark
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.emptyStateMessage,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
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
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
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
                  ? theme.colorScheme.primary.withOpacity(0.2)
                  : isDark
                      ? theme.colorScheme.surfaceContainerHigh
                      : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
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
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      app_date_utils.AppDateUtils.formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  truncatedText,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
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
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.send,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: _sendMessage,
                      tooltip: 'Send message',
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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
      // Seamless design - no outer box, matches inner content style
      return Container(
        decoration: BoxDecoration(
          // No border, no shadow - seamless integration
          color: Colors.transparent,
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
                  // Seamless design - transparent background, subtle border
                  color: Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.chat,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
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
                            foregroundColor: Theme.of(context).colorScheme.primary,
                          ),
                          child: const Text(
                            'View Full',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.primary,
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
