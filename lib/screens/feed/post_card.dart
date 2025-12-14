import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../utils/app_theme.dart';
import '../../utils/date_utils.dart' as date_utils;
import '../../widgets/message_reaction_widget.dart';
import '../../widgets/message_reaction_button.dart';

/// Card widget for displaying a feed post (X/Twitter-style)
class PostCard extends StatelessWidget {
  final ChatMessage post;
  final String? currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.post,
    this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLiked = post.reactions.any((r) => r.userId == currentUserId && r.emoji == '❤️');

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author info
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: post.senderPhotoUrl != null
                        ? NetworkImage(post.senderPhotoUrl!)
                        : null,
                    child: post.senderPhotoUrl == null
                        ? Text(post.senderName[0].toUpperCase())
                        : null,
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.senderName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          date_utils.formatRelativeTime(post.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              // Content
              Text(
                post.content,
                style: theme.textTheme.bodyLarge,
              ),
              // URL Preview
              if (post.urlPreview != null) ...[
                const SizedBox(height: AppTheme.spacingMD),
                _buildUrlPreview(post.urlPreview!, theme),
              ],
              // Reactions
              if (post.reactions.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingSM),
                MessageReactionWidget(
                  messageId: post.id,
                  reactions: post.reactions,
                  currentUserId: currentUserId,
                ),
              ],
              const SizedBox(height: AppTheme.spacingMD),
              // Engagement metrics and actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: post.likeCount > 0 ? post.likeCount.toString() : null,
                    color: isLiked ? Colors.red : null,
                    onTap: onLike,
                  ),
                  _buildActionButton(
                    icon: Icons.comment_outlined,
                    label: post.commentCount > 0 ? post.commentCount.toString() : null,
                    onTap: onComment,
                  ),
                  _buildActionButton(
                    icon: Icons.share_outlined,
                    label: post.shareCount > 0 ? post.shareCount.toString() : null,
                    onTap: onShare,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    String? label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSM,
          vertical: AppTheme.spacingXS,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUrlPreview(UrlPreview preview, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Image.network(
                preview.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview.siteName != null)
                  Text(
                    preview.siteName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                if (preview.title != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview.title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (preview.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    preview.description!,
                    style: theme.textTheme.bodySmall,
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

