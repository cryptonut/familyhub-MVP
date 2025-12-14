import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Bottom sheet for selecting emoji reactions
class EmojiPickerBottomSheet extends StatelessWidget {
  final Function(String) onEmojiSelected;

  const EmojiPickerBottomSheet({
    super.key,
    required this.onEmojiSelected,
  });

  // Common emoji reactions
  static const List<String> _commonEmojis = [
    '👍', '👎', '❤️', '😂', '😮', '😢', '🙏', '👏',
    '🔥', '⭐', '💯', '🎉', '✅', '❌', '💪', '🎯',
    '😊', '😍', '🤔', '😴', '🤯', '🥳', '😎', '🤝',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
        top: AppTheme.spacingMD,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
            child: Row(
              children: [
                Text(
                  'Add Reaction',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          // Emoji grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: AppTheme.spacingSM,
                crossAxisSpacing: AppTheme.spacingSM,
              ),
              itemCount: _commonEmojis.length,
              itemBuilder: (context, index) {
                final emoji = _commonEmojis[index];
                return GestureDetector(
                  onTap: () => onEmojiSelected(emoji),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
        ],
      ),
    );
  }
}

