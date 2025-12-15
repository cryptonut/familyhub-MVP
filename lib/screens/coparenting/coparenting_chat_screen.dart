import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_message.dart';
import '../../models/coparenting_message_template.dart';
import '../../services/chat_service.dart';
import '../../services/coparenting_service.dart';
import '../../widgets/chat_widget.dart';
import 'message_templates_screen.dart';

class CoparentingChatScreen extends StatefulWidget {
  final String hubId;
  final String hubName;

  const CoparentingChatScreen({
    super.key,
    required this.hubId,
    required this.hubName,
  });

  @override
  State<CoparentingChatScreen> createState() => _CoparentingChatScreenState();
}

class _CoparentingChatScreenState extends State<CoparentingChatScreen> {
  final ChatService _chatService = ChatService();
  final CoparentingService _coparentingService = CoparentingService();
  final TextEditingController _messageController = TextEditingController();

  Future<void> _useTemplate() async {
    final templateContent = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => MessageTemplatesScreen(hubId: widget.hubId),
      ),
    );

    if (templateContent != null && mounted) {
      _messageController.text = templateContent;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hubName),
        actions: [
          IconButton(
            icon: const Icon(Icons.article),
            onPressed: _useTemplate,
            tooltip: 'Use Template',
          ),
        ],
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

