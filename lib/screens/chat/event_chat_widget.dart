import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/event_chat_message.dart';
import '../../services/auth_service.dart';
import '../../services/event_chat_service.dart';
import '../../widgets/linkable_text.dart';

/// Widget for displaying and interacting with event-specific chat
class EventChatWidget extends StatefulWidget {
  final String eventId;

  const EventChatWidget({
    super.key,
    required this.eventId,
  });

  @override
  State<EventChatWidget> createState() => _EventChatWidgetState();
}

class _EventChatWidgetState extends State<EventChatWidget> {
  final EventChatService _chatService = EventChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Uuid _uuid = const Uuid();
  bool _isSending = false;
  String? _editingMessageId;
  String? _replyingToMessageId;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    final userId = _auth.currentUser?.uid;
    final userName = _auth.currentUser?.displayName ?? 'Unknown User';

    if (userId == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Get user's display name from AuthService to ensure we have it
      final authService = AuthService();
      final userModel = await authService.getCurrentUserModel();
      final displayName = userModel?.displayName.isNotEmpty == true
          ? userModel!.displayName
          : (userModel?.email ?? userName);

      final message = EventChatMessage(
        id: _uuid.v4(),
        eventId: widget.eventId,
        senderId: userId,
        senderName: displayName,
        content: content,
        timestamp: DateTime.now(),
        parentMessageId: _replyingToMessageId,
      );

      await _chatService.sendMessage(message);

      _messageController.clear();
      _replyingToMessageId = null;

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _editMessage(String messageId, String currentContent) async {
    _messageController.text = currentContent;
    _editingMessageId = messageId;

    if (mounted) {
      _messageController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: currentContent.length,
      );
    }
  }

  Future<void> _saveEdit() async {
    if (_editingMessageId == null) return;

    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      await _chatService.editMessage(widget.eventId, _editingMessageId!, content);
      _messageController.clear();
      _editingMessageId = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error editing message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMessage(String messageId, {bool isAdmin = false}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _chatService.deleteMessage(widget.eventId, messageId, isAdmin: isAdmin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;

    return Column(
      children: [
        // Messages List
        StreamBuilder<List<EventChatMessage>>(
          stream: _chatService.getEventChatMessagesStream(widget.eventId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text('Error loading messages: ${snapshot.error}'),
                ),
              );
            }

            final messages = snapshot.data ?? [];

            if (messages.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text('No messages yet. Start the conversation!'),
                ),
              );
            }

            return Container(
              height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isOwnMessage = message.senderId == userId;
                  final isDeleted = message.isDeleted;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: isOwnMessage
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!isOwnMessage) ...[
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue,
                            child: Text(
                              message.senderName.isNotEmpty
                                  ? message.senderName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 12,
                              ),
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
                              color: isOwnMessage ? Colors.blue : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isOwnMessage)
                                  Text(
                                    message.senderName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isOwnMessage
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                LinkableText(
                                  text: isDeleted
                                      ? message.content
                                      : message.content,
                                  style: TextStyle(
                                    color: isOwnMessage
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
                                  ),
                                ),
                                if (message.editedAt != null)
                                  Text(
                                    'edited',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isOwnMessage
                                          ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (isOwnMessage) ...[
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.blue,
                            child: Text(
                              message.senderName.isNotEmpty
                                  ? message.senderName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        if (isOwnMessage && !isDeleted)
                          PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 16),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editMessage(message.id, message.content);
                              } else if (value == 'delete') {
                                _deleteMessage(message.id);
                              }
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        // Message Input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: _editingMessageId != null
                      ? 'Edit message...'
                      : _replyingToMessageId != null
                          ? 'Reply to message...'
                          : 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (_editingMessageId != null) {
                    _saveEdit();
                  } else {
                    _sendMessage();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(_editingMessageId != null ? Icons.save : Icons.send),
              onPressed: _isSending
                  ? null
                  : () {
                      if (_editingMessageId != null) {
                        _saveEdit();
                      } else {
                        _sendMessage();
                      }
                    },
            ),
          ],
        ),
      ],
    );
  }
}

