import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/sms_message.dart';
import '../../services/sms_service.dart';
import '../../services/contact_sync_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../widgets/ui_components.dart';

/// Individual SMS conversation screen (Android only)
class SmsConversationScreen extends StatefulWidget {
  final String phoneNumber;
  final String? contactName;

  const SmsConversationScreen({
    super.key,
    required this.phoneNumber,
    this.contactName,
  });

  @override
  State<SmsConversationScreen> createState() => _SmsConversationScreenState();
}

class _SmsConversationScreenState extends State<SmsConversationScreen> {
  final SmsService _smsService = SmsService();
  final ContactSyncService _contactService = ContactSyncService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<SmsMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _contactName;

  @override
  void initState() {
    super.initState();
    _contactName = widget.contactName;
    if (Platform.isAndroid) {
      _initialize();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Set up SMS received callback
    _smsService.setOnSmsReceived((message) {
      final normalizedPhone = _smsService.getNormalizedPhone(widget.phoneNumber);
      if (message.normalizedPhoneNumber == normalizedPhone) {
        _loadMessages();
      }
    });

    await _loadContactName();
    await _loadMessages();
  }

  Future<void> _loadContactName() async {
    if (_contactName != null) return;
    
    try {
      final contact = await _contactService.getContactByPhoneNumber(widget.phoneNumber);
      if (contact != null && mounted) {
        setState(() {
          _contactName = contact.displayName;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadMessages() async {
    if (!Platform.isAndroid) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await _smsService.getSmsMessages(widget.phoneNumber);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final success = await _smsService.sendSms(widget.phoneNumber, text);
      if (success && mounted) {
        _messageController.clear();
        await _loadMessages();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
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

  void _scrollToBottom() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;
      try {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _scrollController.jumpTo(maxScroll);
        }
      } catch (e) {
        // Ignore scroll errors
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: Text(_contactName ?? widget.phoneNumber)),
        body: const Center(
          child: Text('SMS feature is only available on Android devices'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_contactName ?? widget.phoneNumber),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? EmptyState(
                        icon: Icons.sms_outlined,
                        title: 'No messages yet',
                        message: 'Start the conversation!',
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppTheme.spacingSM),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessageBubble(message);
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(SmsMessage message) {
    final theme = Theme.of(context);
    final isSent = message.isSent;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: AppTheme.spacingXS,
          horizontal: AppTheme.spacingSM,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMD,
          vertical: AppTheme.spacingSM,
        ),
        decoration: BoxDecoration(
          color: isSent
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppTheme.radiusMD),
            topRight: const Radius.circular(AppTheme.radiusMD),
            bottomLeft: Radius.circular(isSent ? AppTheme.radiusMD : AppTheme.radiusSM),
            bottomRight: Radius.circular(isSent ? AppTheme.radiusSM : AppTheme.radiusMD),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isSent
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                color: isSent
                    ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMD,
                    vertical: AppTheme.spacingSM,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSM),
            IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${app_date_utils.AppDateUtils.getDayName(timestamp.weekday)} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

