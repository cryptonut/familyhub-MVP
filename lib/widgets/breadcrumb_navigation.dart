import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class BreadcrumbNavigation extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const BreadcrumbNavigation({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.length <= 1) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      child: Row(
        children: [
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;

            return Row(
              children: [
                if (index > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                GestureDetector(
                  onTap: isLast ? null : item.onTap,
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isLast
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;

  BreadcrumbItem({
    required this.label,
    this.onTap,
  });
}

