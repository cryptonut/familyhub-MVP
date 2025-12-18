import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_reaction.dart';
import '../services/message_reaction_service.dart';
import '../utils/app_theme.dart';
import 'emoji_picker_bottom_sheet.dart';

/// Widget to display and manage message reactions
class MessageReactionWidget extends StatefulWidget {
  final String messageId;
  final String familyId;
  final String? chatId; // For private messages
  final bool isCurrentUser;

  const MessageReactionWidget({
    super.key,
    required this.messageId,
    required this.familyId,
    this.chatId,
    this.isCurrentUser = false,
  });

  @override
  State<MessageReactionWidget> createState() => _MessageReactionWidgetState();
}

class _MessageReactionWidgetState extends State<MessageReactionWidget> {
  final MessageReactionService _reactionService = MessageReactionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MessageReaction>>(
      stream: _reactionService.watchReactions(
        widget.messageId,
        widget.familyId,
        chatId: widget.chatId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Show add reaction button when no reactions
          return _buildAddReactionButton();
        }

        final reactions = snapshot.data!;
        final userId = _auth.currentUser?.uid;

        // Group reactions by emoji
        final reactionGroups = <String, List<MessageReaction>>{};
        for (var reaction in reactions) {
          reactionGroups.putIfAbsent(reaction.emoji, () => []).add(reaction);
        }

        return Wrap(
          spacing: AppTheme.spacingXS,
          runSpacing: AppTheme.spacingXS,
          children: [
            // Display reaction groups
            ...reactionGroups.entries.map((entry) {
              final emoji = entry.key;
              final groupReactions = entry.value;
              final count = groupReactions.length;
              final hasUserReaction = userId != null &&
                  groupReactions.any((r) => r.userId == userId);

              return GestureDetector(
                onTap: () => _toggleReaction(emoji),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSM,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: hasUserReaction
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    border: Border.all(
                      color: hasUserReaction
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        emoji,
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (count > 1) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hasUserReaction
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            // Add reaction button
            _buildAddReactionButton(),
          ],
        );
      },
    );
  }

  Widget _buildAddReactionButton() {
    return InkWell(
      onTap: _showEmojiPicker,
      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      child: Container(
        padding: const EdgeInsets.all(8), // Increased from spacingXS (4px) to 8px
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        child: Icon(
          Icons.add_reaction_outlined,
          size: 24, // Increased from 16 to 24 for better touch target
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => EmojiPickerBottomSheet(
        onEmojiSelected: (emoji) {
          _toggleReaction(emoji);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _toggleReaction(String emoji) async {
    try {
      await _reactionService.addReaction(
        widget.messageId,
        emoji,
        widget.familyId,
        chatId: widget.chatId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reacting: $e')),
        );
      }
    }
  }
}
