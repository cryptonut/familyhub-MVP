import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class SwipeableListItem extends StatelessWidget {
  final Widget child;
  final List<SwipeAction> leftActions;
  final List<SwipeAction> rightActions;
  final VoidCallback? onTap;

  const SwipeableListItem({
    super.key,
    required this.child,
    this.leftActions = const [],
    this.rightActions = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (leftActions.isEmpty && rightActions.isEmpty) {
      return InkWell(
        onTap: onTap,
        child: child,
      );
    }

    return Dismissible(
      key: Key(DateTime.now().millisecondsSinceEpoch.toString()),
      direction: _getDismissDirection(),
      background: _buildSwipeBackground(context, leftActions, Alignment.centerLeft),
      secondaryBackground: _buildSwipeBackground(context, rightActions, Alignment.centerRight),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd && leftActions.isNotEmpty) {
          leftActions.first.onTap();
        } else if (direction == DismissDirection.endToStart && rightActions.isNotEmpty) {
          rightActions.first.onTap();
        }
      },
      child: InkWell(
        onTap: onTap,
        child: child,
      ),
    );
  }

  DismissDirection _getDismissDirection() {
    if (leftActions.isNotEmpty && rightActions.isNotEmpty) {
      return DismissDirection.horizontal;
    } else if (leftActions.isNotEmpty) {
      return DismissDirection.startToEnd;
    } else if (rightActions.isNotEmpty) {
      return DismissDirection.endToStart;
    }
    return DismissDirection.none;
  }

  Widget _buildSwipeBackground(
    BuildContext context,
    List<SwipeAction> actions,
    Alignment alignment,
  ) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final action = actions.first;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: action.color ?? Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          Icon(
            action.icon,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: AppTheme.spacingSM),
          Text(
            action.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class SwipeAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  SwipeAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
}

