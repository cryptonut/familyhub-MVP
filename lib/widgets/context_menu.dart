import 'package:flutter/material.dart';

class ContextMenu extends StatelessWidget {
  final Widget child;
  final List<ContextMenuAction> actions;

  const ContextMenu({
    super.key,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: child,
    );
  }

  void _showContextMenu(BuildContext context) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset position = renderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: actions.map((action) {
        return PopupMenuItem(
          value: action,
          child: Row(
            children: [
              Icon(action.icon, size: 20),
              const SizedBox(width: 12),
              Text(action.label),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        value.onTap();
      }
    });
  }
}

class ContextMenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  ContextMenuAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
}

