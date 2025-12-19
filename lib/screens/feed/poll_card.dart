import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../utils/app_theme.dart';
import '../../utils/date_utils.dart' as date_utils;
import '../chat/private_chat_screen.dart';

/// Card widget for displaying a poll post
class PollCard extends StatelessWidget {
  const PollCard({
    super.key,
    required this.post,
    required this.onVote,
    this.currentUserId,
    this.onTap,
  });

  final ChatMessage post;
  final String? currentUserId;
  final Function(String optionId) onVote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pollOptions = post.pollOptions ?? [];
    final totalVotes = pollOptions.fold<int>(0, (sum, option) => sum + option.voteCount);
    final hasVoted = post.votedPollOptionId != null;
    final isExpired = post.pollExpiresAt != null && post.pollExpiresAt!.isBefore(DateTime.now());

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
                  // Avatar (clickable to open private chat)
                  GestureDetector(
                    onTap: () {
                      // Navigate to private chat with sender
                      if (post.senderId != currentUserId) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PrivateChatScreen(
                              recipientId: post.senderId,
                              recipientName: post.senderName,
                            ),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: post.senderPhotoUrl != null
                          ? NetworkImage(post.senderPhotoUrl!)
                          : null,
                      child: post.senderPhotoUrl == null
                          ? Text(post.senderName[0].toUpperCase())
                          : null,
                    ),
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
                          date_utils.AppDateUtils.getRelativeTime(post.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              // Poll question
              Text(
                post.content,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              // Poll options
              ...pollOptions.map((option) => _buildPollOption(
                    option: option,
                    totalVotes: totalVotes,
                    hasVoted: hasVoted,
                    isExpired: isExpired,
                    isSelected: option.id == post.votedPollOptionId,
                    theme: theme,
                    onTap: () {
                      if (!hasVoted && !isExpired) {
                        onVote(option.id);
                      }
                    },
                  ),),
              const SizedBox(height: AppTheme.spacingSM),
              // Poll metadata
              Row(
                children: [
                  Text(
                    '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (post.pollExpiresAt != null) ...[
                    const SizedBox(width: AppTheme.spacingSM),
                    Text(
                      isExpired
                          ? 'Poll ended'
                          : 'Ends ${date_utils.AppDateUtils.getRelativeTime(post.pollExpiresAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPollOption({
    required PollOption option,
    required int totalVotes,
    required bool hasVoted,
    required bool isExpired,
    required bool isSelected,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    final percentage = totalVotes > 0 ? (option.voteCount / totalVotes) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: InkWell(
        onTap: hasVoted || isExpired ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingSM),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      option.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (hasVoted || isExpired)
                    Text(
                      '${(percentage * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              if (hasVoted || isExpired) ...[
                const SizedBox(height: AppTheme.spacingXS),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSelected ? theme.colorScheme.primary : theme.colorScheme.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

