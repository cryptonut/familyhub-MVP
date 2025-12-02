import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class QuickActionsFAB extends StatefulWidget {
  final List<QuickAction> actions;
  final IconData mainIcon;

  const QuickActionsFAB({
    super.key,
    required this.actions,
    this.mainIcon = Icons.add,
  });

  @override
  State<QuickActionsFAB> createState() => _QuickActionsFABState();
}

class _QuickActionsFABState extends State<QuickActionsFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isExpanded)
          ...widget.actions.reversed.map((action) {
            final index = widget.actions.indexOf(action);
            return ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: FloatingActionButton.small(
                    heroTag: 'fab_${action.label}',
                    onPressed: () {
                      _toggleExpanded();
                      action.onTap();
                    },
                    backgroundColor: action.color ?? Theme.of(context).colorScheme.primary,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(action.icon, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          action.label,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: _toggleExpanded,
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_isExpanded ? Icons.close : widget.mainIcon),
          ),
        ),
      ],
    );
  }
}

class QuickAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
}

