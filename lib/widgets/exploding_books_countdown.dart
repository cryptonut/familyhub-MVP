import 'package:flutter/material.dart';
import '../models/exploding_book_challenge.dart';

/// Countdown timer widget for Exploding Books challenges
class ExplodingBooksCountdown extends StatelessWidget {
  final ExplodingBookChallenge challenge;
  final double? height;

  const ExplodingBooksCountdown({
    super.key,
    required this.challenge,
    this.height = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!challenge.isActive || challenge.timeRemaining == null) {
      return const SizedBox.shrink();
    }

    final timeRemaining = challenge.timeRemaining!;
    final totalTime = challenge.targetCompletionDate.difference(challenge.startedAt!);
    final progress = 1.0 - (timeRemaining.inSeconds / totalTime.inSeconds.clamp(1, double.infinity));

    // Color coding: green → yellow → red
    Color progressColor;
    if (progress < 0.5) {
      progressColor = Colors.green;
    } else if (progress < 0.8) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          // Progress bar
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: progressColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Time remaining text overlay
          Positioned.fill(
            child: Center(
              child: Text(
                _formatTimeRemaining(timeRemaining),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: progress > 0.5 ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.isNegative) {
      return 'Time expired';
    }

    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h remaining';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m remaining';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m remaining';
    } else {
      return '${duration.inSeconds}s remaining';
    }
  }
}

/// Expanded countdown widget with more details
class ExplodingBooksCountdownExpanded extends StatelessWidget {
  final ExplodingBookChallenge challenge;

  const ExplodingBooksCountdownExpanded({
    super.key,
    required this.challenge,
  });

  @override
  Widget build(BuildContext context) {
    if (!challenge.isActive || challenge.timeRemaining == null) {
      return const SizedBox.shrink();
    }

    final timeRemaining = challenge.timeRemaining!;
    final totalTime = challenge.targetCompletionDate.difference(challenge.startedAt!);
    final progress = 1.0 - (timeRemaining.inSeconds / totalTime.inSeconds.clamp(1, double.infinity));

    Color progressColor;
    String statusText;
    if (progress < 0.5) {
      progressColor = Colors.green;
      statusText = 'On Track';
    } else if (progress < 0.8) {
      progressColor = Colors.orange;
      statusText = 'Running Low';
    } else {
      progressColor = Colors.red;
      statusText = 'Urgent';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: progressColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: progressColor.withValues(alpha: 0.3), width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timer, color: progressColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                _formatTimeRemaining(timeRemaining),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.isNegative) {
      return 'Time expired';
    }

    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h remaining';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m remaining';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m remaining';
    } else {
      return '${duration.inSeconds}s remaining';
    }
  }
}

