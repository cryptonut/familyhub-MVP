import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/logger_service.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../services/voice_recording_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/voice_player_widget.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  VoiceRecordingService? _voiceService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  Timer? _recordingTimer;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  
  VoiceRecordingService get voiceService {
    _voiceService ??= VoiceRecordingService();
    return _voiceService!;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _voiceService?.dispose();
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
        Logger.warning('Scroll error', error: e, tag: 'ChatScreen');
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

  Future<void> _startRecording() async {
    final path = await voiceService.startRecording();
    if (path != null) {
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration = Duration(seconds: timer.tick);
          });
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start recording. Please check microphone permissions.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await voiceService.stopRecording();
    
    setState(() {
      _isRecording = false;
    });
    
    if (path != null) {
      // Show dialog to confirm sending
      final shouldSend = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send Voice Message?'),
          content: Text('Recording duration: ${_formatDuration(_recordingDuration)}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send'),
            ),
          ],
        ),
      );
      
      if (shouldSend == true && mounted) {
        await _sendVoiceMessage(path);
      } else {
        // Cancel recording
        await voiceService.cancelRecording();
      }
    }
    
    setState(() {
      _recordingDuration = Duration.zero;
    });
  }

  Future<void> _sendVoiceMessage(String localFilePath) async {
    try {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading voice message...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      final audioUrl = await voiceService.uploadVoiceMessage(localFilePath);
      
      if (audioUrl == null || !mounted) return;
      
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
      
      final message = ChatMessage(
        id: const Uuid().v4(),
        senderId: currentUserId,
        senderName: currentUserName,
        content: 'Voice message',
        timestamp: DateTime.now(),
        type: MessageType.voice,
        audioUrl: audioUrl,
      );
      
      await _chatService.sendMessage(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending voice message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSM),
      color: Colors.red.shade50,
      child: Row(
        children: [
          Icon(Icons.mic, color: Colors.red, size: 20),
          const SizedBox(width: AppTheme.spacingSM),
          Text(
            'Recording: ${_formatDuration(_recordingDuration)}',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePlayer(String audioUrl, bool isCurrentUser, ThemeData theme) {
    return VoicePlayerWidget(
      audioUrl: audioUrl,
      isCurrentUser: isCurrentUser,
      theme: theme,
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      Text(
                        'Error loading messages',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      Text(
                        '${snapshot.error}',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
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
                      ? EmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: 'No messages yet',
                          message: 'Start the conversation!',
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(AppTheme.spacingSM),
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
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
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
              color: isCurrentUser
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppTheme.radiusMD),
                topRight: const Radius.circular(AppTheme.radiusMD),
                bottomLeft: Radius.circular(isCurrentUser ? AppTheme.radiusMD : AppTheme.radiusSM),
                bottomRight: Radius.circular(isCurrentUser ? AppTheme.radiusSM : AppTheme.radiusMD),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * 0.75,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser) ...[
                  Text(
                    message.senderName,
                    style: theme.textTheme.labelMedium?.copyWith(
                    color: isCurrentUser
                        ? Colors.white.withValues(alpha: 0.9)
                        : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                ],
                if (message.type == MessageType.voice && message.audioUrl != null)
                  _buildVoicePlayer(message.audioUrl!, isCurrentUser, theme)
                else
                  Text(
                    message.content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isCurrentUser
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  app_date_utils.AppDateUtils.formatTime(message.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isCurrentUser
                        ? Colors.white.withValues(alpha: 0.7)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_isRecording) _buildRecordingIndicator(),
            Row(
              children: [
                // Voice recording button
                IconButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording ? Colors.red : theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isRecording,
                    decoration: InputDecoration(
                      hintText: _isRecording ? 'Recording...' : 'Type a message...',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                        borderSide: BorderSide.none,
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
                if (!_isRecording)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
                      padding: const EdgeInsets.all(AppTheme.spacingSM),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
