import 'package:flutter/material.dart';
import '../models/message_reaction.dart';
import '../services/message_reaction_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessageReactionWidget extends StatelessWidget {
  final String messageId;
  final String familyId;
  final List<MessageReaction> reactions;
  final String? chatId;

  const MessageReactionWidget({
    super.key,
    required this.messageId,
    required this.familyId,
    required this.reactions,
    this.chatId,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group reactions by emoji
    final reactionGroups = <String, List<MessageReaction>>{};
    for (var reaction in reactions) {
      reactionGroups.putIfAbsent(reaction.emoji, () => []).add(reaction);
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: reactionGroups.entries.map((entry) {
        final emoji = entry.key;
        final count = entry.value.length;
        final userId = FirebaseAuth.instance.currentUser?.uid;
        final hasUserReaction = entry.value.any((r) => r.userId == userId);

        return GestureDetector(
          onTap: () => _toggleReaction(context, emoji, hasUserReaction),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasUserReaction
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: hasUserReaction
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  count > 1 ? '$count' : '',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: hasUserReaction
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _toggleReaction(BuildContext context, String emoji, bool hasReaction) {
    final service = MessageReactionService();
    if (hasReaction) {
      service.removeReaction(messageId, emoji, familyId, chatId: chatId);
    } else {
      service.addReaction(messageId, emoji, familyId, chatId: chatId);
    }
  }
}

class MessageReactionButton extends StatelessWidget {
  final String messageId;
  final String familyId;
  final String? chatId;

  const MessageReactionButton({
    super.key,
    required this.messageId,
    required this.familyId,
    this.chatId,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add_reaction, size: 20),
      onPressed: () => _showEmojiPicker(context),
      tooltip: 'Add reaction',
    );
  }

  void _showEmojiPicker(BuildContext context) {
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '✅', '❌'];
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: emojis.length,
          itemBuilder: (context, index) {
            final emoji = emojis[index];
            return InkWell(
              onTap: () {
                MessageReactionService().addReaction(
                  messageId,
                  emoji,
                  familyId,
                  chatId: chatId,
                );
                Navigator.pop(context);
              },
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


