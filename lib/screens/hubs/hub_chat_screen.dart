import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat_widget.dart';

class HubChatScreen extends StatefulWidget {
  final String hubId;
  final String hubName;

  const HubChatScreen({
    super.key,
    required this.hubId,
    required this.hubName,
  });

  @override
  State<HubChatScreen> createState() => _HubChatScreenState();
}

class _HubChatScreenState extends State<HubChatScreen> {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hubName),
      ),
      body: SafeArea(
        child: ChatWidget(
          messagesStream: _chatService.getHubMessagesStream(widget.hubId),
          onSendMessage: (messageText) async {
            final currentUserId = _chatService.currentUserId;
            final currentUserName = _chatService.currentUserName ?? 'You';
            
            if (currentUserId == null) {
              throw Exception('User not authenticated');
            }

            final message = ChatMessage(
              id: const Uuid().v4(),
              senderId: currentUserId,
              senderName: currentUserName,
              content: messageText,
              timestamp: DateTime.now(),
              hubId: widget.hubId,
            );

            await _chatService.sendHubMessage(widget.hubId, message);
          },
          currentUserId: _chatService.currentUserId,
          currentUserName: _chatService.currentUserName,
          emptyStateMessage: 'No messages yet. Start the conversation!',
        ),
      ),
    );
  }
}

