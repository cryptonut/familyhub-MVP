import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../utils/app_theme.dart';
import '../../utils/date_utils.dart' as date_utils;

/// Card widget for displaying a feed post (X/Twitter-style)
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    this.currentUserId,
    this.onTap,
  });

  final ChatMessage post;
  final String? currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLiked = post.reactions.any((r) => r.userId == currentUserId && r.emoji == '❤️');
    final likeCount = post.likeCount > 0 ? post.likeCount : (isLiked ? 1 : 0);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 23,
              backgroundImage: post.senderPhotoUrl != null
                  ? NetworkImage(post.senderPhotoUrl!)
                  : null,
              backgroundColor: theme.colorScheme.primary,
              child: post.senderPhotoUrl == null
                  ? Text(
                      post.senderName.isNotEmpty
                          ? post.senderName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author info row
                  Row(
                    children: [
                      Text(
                        post.senderName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date_utils.AppDateUtils.getRelativeTime(post.timestamp),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Post content
                  Text(
                    post.content,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  // URL Preview
                  if (post.urlPreview != null) ...[
                    const SizedBox(height: 12),
                    _buildUrlPreview(post.urlPreview!, theme),
                  ],
                  const SizedBox(height: 12),
                  // Engagement row (X-style)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Comment
                      _buildEngagementButton(
                        icon: Icons.chat_bubble_outline,
                        count: post.commentCount,
                        onTap: onComment,
                        theme: theme,
                      ),
                      // Like
                      _buildEngagementButton(
                        icon: isLiked ? Icons.favorite : Icons.favorite_border,
                        count: likeCount,
                        onTap: onLike,
                        theme: theme,
                        color: isLiked ? Colors.red : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementButton({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
    required ThemeData theme,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18.75,
              color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                _formatCount(count),
                style: TextStyle(
                  fontSize: 13,
                  color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
  }

  Widget _buildUrlPreview(UrlPreview preview, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.imageUrl != null)
            Image.network(
              preview.imageUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview.siteName != null)
                  Text(
                    preview.siteName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                if (preview.title != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview.title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (preview.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
