import 'package:flutter/material.dart';
import '../models/chess_game.dart';
import '../models/chess_game_role.dart';
import '../../../utils/app_theme.dart';

/// Reusable card widget for displaying chess games
/// Uses ChessGameRole for consistent logic across all screens
class ChessGameCard extends StatelessWidget {
  final ChessGame game;
  final String currentUserId;
  final VoidCallback? onAccept;
  final VoidCallback? onJoin;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const ChessGameCard({
    super.key,
    required this.game,
    required this.currentUserId,
    this.onAccept,
    this.onJoin,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final role = ChessGameRole.determine(game, currentUserId);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: role.isInvited
            ? Colors.orange.shade100
            : role.isChallenger && game.status == GameStatus.waiting
                ? Colors.green.shade50
                : role.isChallenger && game.status == GameStatus.active
                    ? Colors.blue.shade50
                    : Colors.blue.shade50,
        border: Border.all(
          color: role.isInvited
              ? Colors.orange.shade400
              : role.isChallenger && game.status == GameStatus.waiting
                  ? Colors.green.shade400
                  : role.isChallenger && game.status == GameStatus.active
                      ? Colors.blue.shade400
                      : Colors.blue.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: (role.isChallenger) 
            ? null // Challenger can't tap - must use explicit button
            : onTap, // Invited players can tap to accept
        child: ListTile(
          enabled: !role.isChallenger, // Disable ListTile for challengers to prevent any tap handling
          leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: role.isInvited
                ? Colors.orange.shade200
                : role.isChallenger && game.status == GameStatus.waiting
                    ? Colors.green.shade200
                    : role.isChallenger && game.status == GameStatus.active
                        ? Colors.blue.shade200
                        : Colors.blue.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            role.isInvited
                ? Icons.notifications_active
                : role.isChallenger && game.status == GameStatus.waiting
                    ? Icons.hourglass_empty
                    : role.isChallenger && game.status == GameStatus.active
                        ? Icons.check_circle
                        : Icons.person_add,
            color: role.isInvited
                ? Colors.orange.shade900
                : role.isChallenger && game.status == GameStatus.waiting
                    ? Colors.green.shade900
                    : role.isChallenger && game.status == GameStatus.active
                        ? Colors.blue.shade900
                        : Colors.blue.shade900,
            size: 24,
          ),
        ),
        title: Text(
          role.displayText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: role.isInvited
                ? Colors.orange.shade900
                : role.isChallenger && game.status == GameStatus.waiting
                    ? Colors.green.shade900
                    : role.isChallenger && game.status == GameStatus.active
                        ? Colors.blue.shade900
                        : Colors.blue.shade900,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          role.subtitleText,
          style: TextStyle(
            color: role.isInvited
                ? Colors.orange.shade700
                : role.isChallenger && game.status == GameStatus.waiting
                    ? Colors.green.shade700
                    : role.isChallenger && game.status == GameStatus.active
                        ? Colors.blue.shade700
                        : Colors.blue.shade700,
            fontSize: 12,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // DELETE button - always visible
            if (role.canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete game',
                onPressed: onDelete,
                color: Colors.red.shade700,
                iconSize: 22,
              ),
            const SizedBox(width: 8),
            // Action button (Accept or Join)
            if (role.canAccept && onAccept != null)
              ElevatedButton.icon(
                onPressed: onAccept,
                icon: Icon(role.buttonIcon, size: 18),
                label: Text(role.buttonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: role.buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              )
            else if (role.canJoin && onJoin != null)
              ElevatedButton.icon(
                onPressed: onJoin,
                icon: Icon(role.buttonIcon, size: 18),
                label: Text(role.buttonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: role.buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}

