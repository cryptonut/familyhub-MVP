import 'package:flutter/material.dart';
import 'chess_game.dart';

/// Centralized logic for determining user role and UI state for a chess game
/// This eliminates duplicate logic across multiple screens
class ChessGameRole {
  final bool isChallenger;
  final bool isInvited;
  final bool isBlackPlayer;
  final bool isWhitePlayer;
  final bool canAccept;
  final bool canJoin;
  final bool canDelete;
  final String displayText;
  final String subtitleText;
  final String buttonText;
  final Color buttonColor;
  final IconData buttonIcon;

  ChessGameRole._({
    required this.isChallenger,
    required this.isInvited,
    required this.isBlackPlayer,
    required this.isWhitePlayer,
    required this.canAccept,
    required this.canJoin,
    required this.canDelete,
    required this.displayText,
    required this.subtitleText,
    required this.buttonText,
    required this.buttonColor,
    required this.buttonIcon,
  });

  /// Determine user's role and UI state for a game
  static ChessGameRole determine(ChessGame game, String userId) {
    // Determine user's relationship to the game
    final isWhitePlayer = game.whitePlayerId == userId;
    final isBlackPlayer = game.blackPlayerId == userId;
    final isInvited = game.invitedPlayerId == userId;
    final isChallenger = isWhitePlayer && !isBlackPlayer; // Challenger is white player who hasn't been joined yet

    // Determine game state
    final isWaiting = game.status == GameStatus.waiting;
    final isActive = game.status == GameStatus.active;
    final hasBlackPlayer = game.blackPlayerId != null;

    // Determine capabilities
    bool canAccept = false;
    bool canJoin = false;
    bool canDelete = true; // Always can delete
    String displayText = '';
    String subtitleText = '';
    String buttonText = '';
    Color buttonColor = Colors.blue;
    IconData buttonIcon = Icons.play_arrow;

    if (isInvited && isWaiting) {
      // User is invited and game is waiting - can accept
      canAccept = true;
      canJoin = false;
      final challengerName = game.whitePlayerName ?? 'Someone';
      displayText = '$challengerName challenged you!';
      subtitleText = 'Tap to accept challenge';
      buttonText = 'Accept Challenge';
      buttonColor = Colors.green.shade700;
      buttonIcon = Icons.check_circle;
    } else if (isChallenger && isWaiting) {
      // Challenger waiting for opponent to accept
      canAccept = false;
      canJoin = false;
      final opponentName = game.invitedPlayerId != null 
          ? (game.blackPlayerName ?? 'Opponent')
          : 'Opponent';
      displayText = 'Waiting for $opponentName to accept...';
      subtitleText = 'Challenge sent - waiting for response';
      buttonText = ''; // No button, only delete
      buttonColor = Colors.grey;
      buttonIcon = Icons.hourglass_empty;
    } else if (isChallenger && isActive && hasBlackPlayer) {
      // Challenger's game was accepted - can join
      canAccept = false;
      canJoin = true;
      final opponentName = game.blackPlayerName ?? 'Opponent';
      displayText = '$opponentName accepted! Join game';
      subtitleText = 'Your challenge was accepted - tap to join!';
      buttonText = 'Join Game';
      buttonColor = Colors.blue.shade700;
      buttonIcon = Icons.play_arrow;
    } else if (isActive && (isWhitePlayer || isBlackPlayer)) {
      // User is already in an active game - can join to continue
      canAccept = false;
      canJoin = true;
      final opponentName = isWhitePlayer 
          ? (game.blackPlayerName ?? 'Opponent')
          : (game.whitePlayerName ?? 'Opponent');
      displayText = 'Game vs $opponentName';
      subtitleText = isActive ? 'Tap to continue game' : 'Game finished';
      buttonText = 'Join Game';
      buttonColor = Colors.blue.shade700;
      buttonIcon = Icons.play_arrow;
    } else {
      // Fallback - shouldn't happen but handle gracefully
      canAccept = false;
      canJoin = false;
      displayText = 'Chess Game';
      subtitleText = 'Unknown state';
      buttonText = '';
      buttonColor = Colors.grey;
      buttonIcon = Icons.help_outline;
    }

    return ChessGameRole._(
      isChallenger: isChallenger,
      isInvited: isInvited,
      isBlackPlayer: isBlackPlayer,
      isWhitePlayer: isWhitePlayer,
      canAccept: canAccept,
      canJoin: canJoin,
      canDelete: canDelete,
      displayText: displayText,
      subtitleText: subtitleText,
      buttonText: buttonText,
      buttonColor: buttonColor,
      buttonIcon: buttonIcon,
    );
  }
}

