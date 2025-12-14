import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_message.dart';
import '../../services/feed_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/skeletons/skeleton_widgets.dart';
import '../../widgets/message_reaction_widget.dart';
import '../../widgets/message_reaction_button.dart';
import '../../services/message_reaction_service.dart';
import '../../utils/date_utils.dart' as date_utils;
import 'post_card.dart';
import 'poll_card.dart';
import 'post_detail_screen.dart';

/// Feed-style screen for displaying posts (X/Twitter-style)
class FeedScreen extends StatefulWidget {
  final String? hubId;
  final List<String>? hubIds; // For multi-hub feed

  const FeedScreen({
    super.key,
    this.hubId,
    this.hubIds,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();
  final AuthService _authService = AuthService();
  final MessageReactionService _reactionService = MessageReactionService();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final userModel = await _authService.getCurrentUserModel();
    if (mounted) {
      setState(() {
        _currentUserId = userModel?.uid;
        _currentUserName = userModel?.displayName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: StreamBuilder<List<ChatMessage>>(
          stream: _feedService.getFeedStream(
            hubId: widget.hubId,
            hubIds: widget.hubIds,
            limit: 20,
            includeReplies: false,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                itemCount: 5,
                itemBuilder: (context, index) => const SkeletonPostCard(),
              );
            }

            if (snapshot.hasError) {
              return Center(
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
                      'Error loading feed',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      snapshot.error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final posts = snapshot.data ?? [];

            if (posts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    Text(
                      'No posts yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'Be the first to post!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSM),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return _buildPostCard(post);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPostComposer(context),
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildPostCard(ChatMessage post) {
    // Use specialized cards based on post type
    if (post.postType == PostType.poll && post.pollOptions != null) {
      return PollCard(
        post: post,
        currentUserId: _currentUserId,
        onVote: (optionId) async {
          try {
            await _feedService.voteOnPoll(
              messageId: post.id,
              optionId: optionId,
              hubId: widget.hubId,
            );
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
        onTap: () => _openPostDetail(post),
      );
    }

    return PostCard(
      post: post,
      currentUserId: _currentUserId,
      onLike: () async {
        try {
          await _feedService.toggleLike(
            messageId: post.id,
            hubId: widget.hubId,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error liking post: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      onComment: () => _openPostDetail(post),
      onShare: () async {
        try {
          await _feedService.sharePost(
            originalMessageId: post.id,
            hubId: widget.hubId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post shared!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error sharing post: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      onTap: () => _openPostDetail(post),
    );
  }

  void _openPostDetail(ChatMessage post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          post: post,
          hubId: widget.hubId,
        ),
      ),
    );
  }

  void _showPostComposer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PostComposerBottomSheet(
        hubId: widget.hubId,
        onPostCreated: () {
          setState(() {});
        },
      ),
    );
  }
}

/// Bottom sheet for composing new posts
class PostComposerBottomSheet extends StatefulWidget {
  final String? hubId;
  final VoidCallback onPostCreated;

  const PostComposerBottomSheet({
    super.key,
    this.hubId,
    required this.onPostCreated,
  });

  @override
  State<PostComposerBottomSheet> createState() => _PostComposerBottomSheetState();
}

class _PostComposerBottomSheetState extends State<PostComposerBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final FeedService _feedService = FeedService();
  bool _isPosting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _postMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isPosting) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final message = ChatMessage(
        id: const Uuid().v4(),
        senderId: _feedService.currentUserId ?? '',
        senderName: _feedService.currentUserName ?? 'You',
        content: text,
        timestamp: DateTime.now(),
      );

      await _feedService.sendMessage(message);
      widget.onPostCreated();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'What\'s on your mind?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            ElevatedButton(
              onPressed: _isPosting ? null : _postMessage,
              child: _isPosting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}

