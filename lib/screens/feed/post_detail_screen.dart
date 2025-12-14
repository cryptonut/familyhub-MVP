import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_message.dart';
import '../../services/feed_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'post_card.dart';
import 'poll_card.dart';

/// Screen for viewing a post with its full thread of comments
class PostDetailScreen extends StatefulWidget {
  final ChatMessage post;
  final String? hubId;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.hubId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FeedService _feedService = FeedService();
  final TextEditingController _commentController = TextEditingController();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    // Get current user ID
    setState(() {
      _currentUserId = _feedService.currentUserId;
    });
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      final comment = ChatMessage(
        id: const Uuid().v4(),
        senderId: _currentUserId ?? '',
        senderName: _feedService.currentUserName ?? 'You',
        content: text,
        timestamp: DateTime.now(),
        parentMessageId: widget.post.id,
        threadId: widget.post.threadId ?? widget.post.id,
      );

      await _feedService.sendMessage(comment);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main post
                  if (widget.post.postType == PostType.poll && widget.post.pollOptions != null)
                    PollCard(
                      post: widget.post,
                      currentUserId: _currentUserId,
                      onVote: (optionId) async {
                        try {
                          await _feedService.voteOnPoll(
                            messageId: widget.post.id,
                            optionId: optionId,
                            hubId: widget.hubId,
                          );
                          setState(() {});
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error voting: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    )
                  else
                    PostCard(
                      post: widget.post,
                      currentUserId: _currentUserId,
                      onLike: () async {
                        try {
                          await _feedService.toggleLike(
                            messageId: widget.post.id,
                            hubId: widget.hubId,
                          );
                          setState(() {});
                        } catch (e) {
                          // Error handling
                        }
                      },
                      onComment: () {},
                      onShare: () {},
                    ),
                  const SizedBox(height: AppTheme.spacingLG),
                  // Comments section
                  Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  // TODO: Load and display comments
                  Text(
                    'Comments will be displayed here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                  ),
                ],
              ),
            ),
          ),
          // Comment input
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSM,
                        vertical: AppTheme.spacingSM,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _postComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

