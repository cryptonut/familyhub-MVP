import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../utils/app_theme.dart';

/// Base skeleton widget with shimmer effect
class SkeletonWidget extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surfaceContainerHigh;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusSM),
        ),
      ),
    );
  }
}

/// Skeleton for event card
class SkeletonEventCard extends StatelessWidget {
  const SkeletonEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonWidget(width: 40, height: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonWidget(width: double.infinity, height: 16),
                      const SizedBox(height: AppTheme.spacingXS),
                      const SkeletonWidget(width: 150, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            const SkeletonWidget(width: double.infinity, height: 12),
            const SizedBox(height: AppTheme.spacingXS),
            const SkeletonWidget(width: 200, height: 12),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for task card
class SkeletonTaskCard extends StatelessWidget {
  const SkeletonTaskCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Row(
          children: [
            const SkeletonWidget(width: 24, height: 24),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonWidget(width: double.infinity, height: 16),
                  const SizedBox(height: AppTheme.spacingXS),
                  const SkeletonWidget(width: 120, height: 12),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            const SkeletonWidget(width: 60, height: 24),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for message bubble
class SkeletonMessageBubble extends StatelessWidget {
  final bool isMe;

  const SkeletonMessageBubble({
    super.key,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMD,
          vertical: AppTheme.spacingXS,
        ),
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonWidget(width: 200, height: 14),
            const SizedBox(height: AppTheme.spacingXS),
            const SkeletonWidget(width: 150, height: 14),
            const SizedBox(height: AppTheme.spacingXS),
            const SkeletonWidget(width: 80, height: 10),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for photo grid item
class SkeletonPhotoGridItem extends StatelessWidget {
  const SkeletonPhotoGridItem({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: SkeletonWidget(
        width: double.infinity,
        height: double.infinity,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
    );
  }
}

/// Skeleton for list item
class SkeletonListItem extends StatelessWidget {
  const SkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      child: Row(
        children: [
          const SkeletonWidget(width: 48, height: 48, borderRadius: BorderRadius.all(Radius.circular(24))),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonWidget(width: double.infinity, height: 16),
                const SizedBox(height: AppTheme.spacingXS),
                const SkeletonWidget(width: 120, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for dashboard stats
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonWidget(width: 40, height: 40),
            const SizedBox(height: AppTheme.spacingMD),
            const SkeletonWidget(width: 80, height: 24),
            const SizedBox(height: AppTheme.spacingXS),
            const SkeletonWidget(width: 100, height: 14),
          ],
        ),
      ),
    );
  }
}

