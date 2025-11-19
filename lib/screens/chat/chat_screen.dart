import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
        debugPrint('Scroll error: $e');
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
      );

      await _chatService.sendMessage(message);
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
        title: const Text('Family Chat'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<ChatMessage>>(
          stream: _chatService.getMessagesStream(),
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

            // Only scroll if we have new messages and widget is mounted
            if (messages.isNotEmpty && mounted) {
              // Use a delayed callback to avoid window access issues
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
                                'Start the conversation!',
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
            Text(
              message.senderName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCurrentUser ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.content,
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
          ],
        ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Builder(
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(8),
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
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (btnContext) {
                  return IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                    color: Theme.of(btnContext).primaryColor,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(btnContext).primaryColor.withValues(alpha: 0.1),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
