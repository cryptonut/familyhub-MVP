import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/chat_message.dart';
import '../../services/auth_service.dart';
import '../../services/feed_service.dart';
import '../../services/hub_service.dart';
import '../../utils/app_theme.dart';
import 'poll_card.dart';
import 'post_card.dart';
import 'post_detail_screen.dart';

/// Feed-style screen for displaying posts (X/Twitter-style)
class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    this.hubId,
    this.hubIds,
  });

  final String? hubId;
  final List<String>? hubIds; // For multi-hub feed

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FeedService _feedService = FeedService();
  final AuthService _authService = AuthService();
  final HubService _hubService = HubService();
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;
  List<Map<String, String>> _availableHubs = [];

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
      });
      // Load available hubs for cross-hub sharing
      await _loadAvailableHubs();
    }
  }

  Future<void> _loadAvailableHubs() async {
    try {
      final hubs = await _hubService.getUserHubs();
      if (mounted) {
        setState(() {
          _availableHubs = hubs.map((hub) => {
            'id': hub.id,
            'name': hub.name,
          },).toList();
        });
      }
    } on Exception {
      // Silently fail - cross-hub sharing is optional
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
              return const Center(child: CircularProgressIndicator());
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
          } on Exception catch (e) {
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
        } on Exception catch (e) {
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

  void _showPostComposer(BuildContext context) async {
    // Get available hub IDs for cross-hub sharing
    final availableHubIds = _availableHubs.map((hub) => hub['id']!).toList();
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PostComposerBottomSheet(
        hubId: widget.hubId,
        availableHubIds: availableHubIds.isNotEmpty ? availableHubIds : null,
        hubNames: _availableHubs,
        onPostCreated: () {
          setState(() {});
        },
      ),
    );
  }
}

/// Bottom sheet for composing new posts
class PostComposerBottomSheet extends StatefulWidget {
  const PostComposerBottomSheet({
    super.key,
    required this.onPostCreated,
    this.hubId,
    this.availableHubIds,
    this.hubNames = const [],
  });

  final String? hubId;
  final List<String>? availableHubIds; // For cross-hub polls
  final List<Map<String, String>> hubNames; // Hub names for display
  final VoidCallback onPostCreated;

  @override
  State<PostComposerBottomSheet> createState() => _PostComposerBottomSheetState();
}

class _PostComposerBottomSheetState extends State<PostComposerBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  final FeedService _feedService = FeedService();
  bool _isPosting = false;
  bool _isPoll = false;
  int _pollDurationHours = 24;
  List<String> _selectedHubIds = [];

  @override
  void initState() {
    super.initState();
    if (widget.hubId != null) {
      _selectedHubIds = [widget.hubId!];
    }
    if (widget.availableHubIds != null && widget.availableHubIds!.isNotEmpty) {
      _selectedHubIds = widget.availableHubIds!;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    for (final controller in _pollOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _postMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isPosting) return;

    if (_isPoll) {
      final options = _pollOptionControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll must have at least 2 options'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (options.length > 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll can have at most 4 options'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _isPosting = true;
      });

      try {
        await _feedService.createPollPost(
          content: text,
          options: options,
          duration: Duration(hours: _pollDurationHours),
          visibleHubIds: _selectedHubIds.length > 1 ? _selectedHubIds : null,
          hubId: widget.hubId,
        );
        widget.onPostCreated();
        if (mounted) {
          Navigator.pop(context);
        }
      } on Exception catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating poll: $e'),
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
    } else {
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
          hubId: widget.hubId,
          parentMessageId: null, // Explicitly set to null for top-level posts
          visibleHubIds: _selectedHubIds.length > 1 ? _selectedHubIds : const [],
        );

        await _feedService.sendMessage(message);
        widget.onPostCreated();
        if (mounted) {
          Navigator.pop(context);
        }
      } on Exception catch (e) {
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
  }

  void _addPollOption() {
    if (_pollOptionControllers.length < 4) {
      setState(() {
        _pollOptionControllers.add(TextEditingController());
      });
    }
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length > 2) {
      setState(() {
        _pollOptionControllers[index].dispose();
        _pollOptionControllers.removeAt(index);
      });
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: _isPoll ? 'Ask a question...' : "What's on your mind?",
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              // Post type toggle
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Post')),
                        ButtonSegment(value: true, label: Text('Poll')),
                      ],
                      selected: {_isPoll},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          _isPoll = newSelection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
              // Poll options
              if (_isPoll) ...[
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  'Poll Options',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                ...List.generate(
                  _pollOptionControllers.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pollOptionControllers[index],
                            decoration: InputDecoration(
                              hintText: 'Option ${index + 1}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        if (_pollOptionControllers.length > 2)
                          IconButton(
                            icon: const Icon(Icons.remove_circle),
                            onPressed: () => _removePollOption(index),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_pollOptionControllers.length < 4)
                  TextButton.icon(
                    onPressed: _addPollOption,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Option'),
                  ),
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  'Poll Duration',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                DropdownButton<int>(
                  value: _pollDurationHours,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 hour')),
                    DropdownMenuItem(value: 6, child: Text('6 hours')),
                    DropdownMenuItem(value: 24, child: Text('1 day')),
                    DropdownMenuItem(value: 72, child: Text('3 days')),
                    DropdownMenuItem(value: 168, child: Text('1 week')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _pollDurationHours = value;
                      });
                    }
                  },
                ),
              ],
              // Cross-hub selection (if multiple hubs available)
              if (widget.availableHubIds != null &&
                  widget.availableHubIds!.length > 1) ...[
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  'Share with Hubs',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Wrap(
                  spacing: AppTheme.spacingSM,
                  children: (widget.availableHubIds ?? []).map((hubId) {
                    final isSelected = _selectedHubIds.contains(hubId);
                    final hubName = widget.hubNames
                        .firstWhere(
                          (hub) => hub['id'] == hubId,
                          orElse: () => {'id': hubId, 'name': 'Hub'},
                        )['name']!;
                    return FilterChip(
                      label: Text(hubName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedHubIds.add(hubId);
                          } else {
                            _selectedHubIds.remove(hubId);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: AppTheme.spacingMD),
              ElevatedButton(
                onPressed: _isPosting ? null : _postMessage,
                child: _isPosting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isPoll ? 'Create Poll' : 'Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

