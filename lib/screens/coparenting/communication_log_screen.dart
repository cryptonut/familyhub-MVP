import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

class CommunicationLogScreen extends StatefulWidget {
  final String hubId;

  const CommunicationLogScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<CommunicationLogScreen> createState() => _CommunicationLogScreenState();
}

class _CommunicationLogScreenState extends State<CommunicationLogScreen> {
  final ChatService _chatService = ChatService();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      // Get all messages for the hub (read-only view)
      final messagesStream = _chatService.getHubMessagesStream(widget.hubId);
      await for (final messages in messagesStream) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
          break; // Get first snapshot
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communication Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportLog,
            tooltip: 'Export Log',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMessages,
              child: _messages.isEmpty
                  ? EmptyState(
                      icon: Icons.message,
                      title: 'No Messages Yet',
                      message: 'Communication log will appear here',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return ModernCard(
                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    message.senderName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, yyyy HH:mm')
                                        .format(message.timestamp),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingSM),
                              Text(
                                message.content,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Future<void> _exportLog() async {
    // Export functionality - would generate PDF or CSV
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality coming soon'),
      ),
    );
  }
}

