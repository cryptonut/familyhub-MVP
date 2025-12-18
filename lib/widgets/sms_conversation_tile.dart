import 'package:flutter/material.dart';
import '../models/sms_conversation.dart';
import '../utils/date_utils.dart' as app_date_utils;
import '../utils/app_theme.dart';

/// Widget for displaying a single SMS conversation in a list
class SmsConversationTile extends StatelessWidget {
  final SmsConversation conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SmsConversationTile({
    super.key,
    required this.conversation,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contactName = conversation.contactName ?? conversation.phoneNumber;
    final lastMessage = conversation.lastMessage ?? '';
    final lastMessageTime = conversation.lastMessageTime;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMD,
          vertical: AppTheme.spacingSM,
        ),
        child: Row(
          children: [
            // Contact avatar
            _buildAvatar(theme),
            const SizedBox(width: AppTheme.spacingMD),
            // Contact info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contactName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastMessageTime != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(lastMessageTime),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
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

  Widget _buildAvatar(ThemeData theme) {
    if (conversation.contactPhotoUrl != null && conversation.contactPhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(conversation.contactPhotoUrl!),
      );
    }

    final initials = _getInitials(conversation.contactName ?? conversation.phoneNumber);
    return CircleAvatar(
      radius: 24,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      // Today - show time
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day name
      return app_date_utils.AppDateUtils.getDayName(time.weekday);
    } else {
      // Older - show date
      return '${time.month}/${time.day}';
    }
  }
}

