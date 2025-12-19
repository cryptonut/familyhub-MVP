import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../services/feed_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/date_utils.dart' as date_utils;
import '../../widgets/ui_components.dart';
import 'poll_card.dart';
import 'post_card.dart';

/// Screen for viewing a post with its full thread of comments
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.post,
    this.hubId,
  });

  final ChatMessage post;
  final String? hubId;

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

  Future<void> _postComment({String? parentCommentId}) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      await _feedService.replyToPost(
        parentMessageId: parentCommentId ?? widget.post.id,
        content: text,
        hubId: widget.hubId,
        threadId: widget.post.threadId ?? widget.post.id,
      );
      _commentController.clear();
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCommentCard(
    ChatMessage comment,
    List<ChatMessage> allComments,
    int depth,
  ) {
    final nestedReplies = allComments
        .where((c) => c.parentMessageId == comment.id)
        .toList();

    return Container(
      margin: EdgeInsets.only(
        left: depth * AppTheme.spacingMD,
        bottom: AppTheme.spacingSM,
      ),
      child: ModernCard(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: comment.senderPhotoUrl != null
                      ? NetworkImage(comment.senderPhotoUrl!)
                      : null,
                  child: comment.senderPhotoUrl == null
                      ? Text(comment.senderName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.senderName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        date_utils.AppDateUtils.getRelativeTime(comment.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              comment.content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _showReplyDialog(comment),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Reply'),
                ),
                if (nestedReplies.isNotEmpty)
                  Text(
                    '${nestedReplies.length} ${nestedReplies.length == 1 ? 'reply' : 'replies'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
              ],
            ),
            // Nested replies (support full depth up to maxDepth = 3)
            if (nestedReplies.isNotEmpty && depth < 3) ...[
              const SizedBox(height: AppTheme.spacingSM),
              ...nestedReplies.map((reply) => _buildCommentCard(reply, allComments, depth + 1)),
            ],
          ],
        ),
      ),
    );
  }

  void _showReplyDialog(ChatMessage parentComment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to ${parentComment.senderName}'),
        content: TextField(
          controller: _commentController,
          decoration: const InputDecoration(
            hintText: 'Write a reply...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _postComment(parentCommentId: parentComment.id);
            },
            child: const Text('Reply'),
          ),
        ],
      ),
    );
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
                          if (!mounted) return;
                          setState(() {});
                        } on Exception catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error voting: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
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
                        } on Exception {
                          // Error handling
                        }
                      },
                      onComment: () {},
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
                  // Comments stream
                  StreamBuilder<List<ChatMessage>>(
                    stream: _feedService.getPostComments(
                      postId: widget.post.id,
                      hubId: widget.hubId,
                      maxDepth: 3,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Text(
                          'Error loading comments: ${snapshot.error}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        );
                      }

                      final comments = snapshot.data ?? [];
                      
                      if (comments.isEmpty) {
                        return Text(
                          'No comments yet. Be the first to comment!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        );
                      }

                      return Column(
                        children: comments
                            .where((c) => c.parentMessageId == widget.post.id) // Top-level only
                            .map((comment) => _buildCommentCard(comment, comments, 0))
                            .toList(),
                      );
                    },
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
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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

