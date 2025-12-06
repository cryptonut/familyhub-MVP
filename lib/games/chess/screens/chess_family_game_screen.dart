import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import '../../../widgets/ui_components.dart';
import '../../../utils/app_theme.dart';
import '../models/chess_game.dart';
import '../services/chess_service.dart';
import '../widgets/chess_game_card.dart';
import 'chess_game_screen.dart';

/// Screen for creating/joining family chess games
class ChessFamilyGameScreen extends StatefulWidget {
  const ChessFamilyGameScreen({super.key});

  @override
  State<ChessFamilyGameScreen> createState() => _ChessFamilyGameScreenState();
}

class _ChessFamilyGameScreenState extends State<ChessFamilyGameScreen> {
  final ChessService _chessService = ChessService();
  final AuthService _authService = AuthService();
  
  List<UserModel> _familyMembers = [];
  List<ChessGame> _waitingGames = [];
  bool _isLoading = true;
  StreamSubscription<List<ChessGame>>? _waitingGamesSubscription;
  String? _currentFamilyId;
  Set<String> _notifiedGameIds = {}; // Track which games we've already shown notifications for

  @override
  void initState() {
    super.initState();
    _loadData();
    // Listen for app lifecycle changes to refresh data when returning to screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't reload here - it causes multiple subscriptions
    // The stream will handle real-time updates
  }

  @override
  void dispose() {
    _waitingGamesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _authService.getFamilyMembers();
      final user = _authService.currentUser;
      
      // Filter out current user
      final otherMembers = members.where((m) => m.uid != user?.uid).toList();

      // Get family ID for streaming
      final userModel = await _authService.getCurrentUserModel();
      _currentFamilyId = userModel?.familyId;

      // Set up real-time stream for waiting games
      if (_currentFamilyId != null && user != null) {
        _waitingGamesSubscription?.cancel();
        _waitingGamesSubscription = _chessService
            .streamWaitingFamilyGames(_currentFamilyId!)
            .listen((games) {
          if (mounted) {
            setState(() {
              // Filter: games where current user is invited, OR games where they're the challenger (waiting or accepted)
              _waitingGames = games
                  .where((g) {
                    final isInvited = g.invitedPlayerId == user.uid;
                    // Challenger: waiting games OR active games where challenger hasn't joined yet
                    final isChallengerWaiting = g.whitePlayerId == user.uid && g.status == GameStatus.waiting;
                    // CRITICAL FIX: Don't require invitedPlayerId == null - if game is active with blackPlayerId, challenger needs to join
                    final isChallengerAccepted = g.whitePlayerId == user.uid && 
                                                 g.status == GameStatus.active && 
                                                 g.blackPlayerId != null; // Accepted - challenger needs to join
                    final isChallenger = isChallengerWaiting || isChallengerAccepted;
                    
                    // CRITICAL: If challenger has an accepted game, show notification ONLY
                    // NO auto-navigation - challenger must click "Join" button explicitly
                    // Only show once per game to avoid spam
                    if (isChallengerAccepted && mounted && !_notifiedGameIds.contains(g.id)) {
                      _notifiedGameIds.add(g.id);
                      Logger.info('Challenger detected accepted game ${g.id} - showing notification only (no auto-navigation)', tag: 'ChessFamilyGameScreen');
                      // Show snackbar notification to challenger - NO dialog, NO auto-navigation
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && context.mounted) {
                          final opponentName = g.blackPlayerName ?? 'Your opponent';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('$opponentName accepted your challenge! Click "Join" button to start playing.'),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 10),
                              // NO action button - user must click the "Join" button on the card
                            ),
                          );
                        }
                      });
                    }
                    
                    return isInvited || isChallenger;
                  })
                  .toList();
              
              Logger.info(
                'Loaded ${_waitingGames.length} waiting games for user ${user.uid} (total games in stream: ${games.length})',
                tag: 'ChessFamilyGameScreen'
              );
            });
          }
        });
      }

      setState(() {
        _familyMembers = otherMembers;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Error loading family data', error: e, tag: 'ChessFamilyGameScreen');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createGame(UserModel opponent) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final userModel = await _authService.getCurrentUserModel();
      if (userModel?.familyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be part of a family')),
        );
        return;
      }

      // Create game invite
      await _chessService.createFamilyGame(
        whitePlayerId: user.uid,
        whitePlayerName: userModel?.displayName ?? 'Player',
        familyId: userModel!.familyId!,
        invitedPlayerId: opponent.uid, // Invite Kate - she needs to join
        invitedPlayerName: opponent.displayName,
      );
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Challenge sent to ${opponent.displayName} successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Close any modal/dialog if present (member selection dialog)
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        
        // CRITICAL: DO NOT navigate away - challenger needs to stay on this screen
        // to see their waiting game and get notified when it's accepted
        // The stream listener will update the UI automatically
        
        // Refresh data to show the new challenge in the lobby
        _loadData();
        
        Logger.info('Challenge created - challenger staying on ChessFamilyGameScreen to see waiting game', tag: 'ChessFamilyGameScreen');
      }
    } catch (e) {
      Logger.error('Error creating family game', error: e, tag: 'ChessFamilyGameScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  /// SIMPLIFIED: Join game - one clear path
  Future<void> _joinGame(ChessGame game) async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in')),
        );
      }
      return;
    }

    try {
      // Verify game still exists before proceeding
      final gameDoc = await _chessService.getGame(game.id);
      if (gameDoc == null) {
        if (mounted) {
          setState(() {
            _waitingGames = _waitingGames.where((g) => g.id != game.id).toList();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game no longer exists'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      final isInvited = gameDoc.invitedPlayerId == user.uid && gameDoc.status == GameStatus.waiting;
      
      // CRITICAL: If invited and waiting, accept the invite but DO NOT auto-navigate
      // The user must click "Join" again to navigate to the game
      if (isInvited) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );
        }
        
        try {
          await _chessService.acceptInvite(game.id);
          // Wait for Firestore update
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Verify game is now active
          final updatedGame = await _chessService.getGame(game.id);
          if (updatedGame == null || updatedGame.status != GameStatus.active || updatedGame.blackPlayerId == null) {
            throw Exception('Game did not become active after accepting');
          }
          
          // SUCCESS: Invite accepted, game is now active
          // DO NOT navigate - user must click "Join" button explicitly
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Challenge accepted! Click "Join" to start playing.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          Logger.error('Error accepting invite', error: e, tag: 'ChessFamilyGameScreen');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error accepting challenge: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        } finally {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
        
        // CRITICAL: After accepting, STOP HERE - do not auto-navigate
        // The game card will update via stream, showing a "Join" button
        // User must click "Join" explicitly to navigate
        return;
      }
      
      // Only navigate if game is already active and user is clicking "Join" explicitly
      // Verify game exists and is ready before navigating
      final finalGame = await _chessService.getGame(game.id);
      if (finalGame == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // For active games, verify both players are set
      if (finalGame.status == GameStatus.active && finalGame.blackPlayerId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game is not ready - opponent has not joined'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Navigate to game - this only happens when user explicitly clicks "Join" on an active game
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChessGameScreen(gameId: game.id, mode: GameMode.family),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error joining game', error: e, tag: 'ChessFamilyGameScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllChessGamesFromDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 8),
            const Expanded(child: Text('Clear All Chess Data')),
          ],
        ),
        content: const Text(
          'This will permanently DELETE ALL chess games and invites from the database.\n\n'
          'This action cannot be undone.\n\n'
          'Are you absolutely sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE EVERYTHING'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Deleting all chess data...\nPlease wait.'),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await _chessService.deleteAllChessGames();
      
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
        
        setState(() {
          _waitingGames = [];
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Successfully deleted ${result['gamesDeleted']} games and ${result['invitesDeleted']} invites.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Refresh data
        _loadData();
      }
    } catch (e, stackTrace) {
      Logger.error('Error deleting all chess games from database', error: e, stackTrace: stackTrace, tag: 'ChessFamilyGameScreen');
      
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (errorContext) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade700, size: 28),
                const SizedBox(width: 8),
                const Expanded(child: Text('Deletion Failed')),
              ],
            ),
            content: Text(
              'An error occurred while deleting chess data:\n\n${e.toString()}\n\n'
              'Please check your connection and try again.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(errorContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _deleteAllWaitingGames() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Waiting Games'),
        content: Text('Are you sure you want to delete all ${_waitingGames.length} waiting games? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int successCount = 0;
    int failCount = 0;

    for (var game in _waitingGames) {
      try {
        await _chessService.deleteGame(game.id);
        successCount++;
      } catch (e) {
        Logger.error('Error deleting game ${game.id}', error: e, tag: 'ChessFamilyGameScreen');
        failCount++;
      }
    }

    if (mounted) {
      setState(() {
        _waitingGames = [];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failCount > 0
                ? 'Deleted $successCount games. $failCount failed.'
                : 'Successfully deleted all $successCount games.',
          ),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Delete a game - works for waiting or active games
  Future<void> _cancelChallenge(ChessGame game) async {
    final user = _authService.currentUser;
    if (user == null) return;
    
    final isChallenger = game.whitePlayerId == user.uid;
    final isInvited = game.invitedPlayerId == user.uid;
    final isActive = game.status == GameStatus.active;
    
    String message;
    if (isActive) {
      message = 'Are you sure you want to delete this active game? This will end the game for both players.';
    } else if (isChallenger) {
      message = 'Are you sure you want to cancel this challenge?';
    } else if (isInvited) {
      message = 'Are you sure you want to decline this challenge?';
    } else {
      message = 'Are you sure you want to delete this game?';
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // If invited player is declining a waiting game, use declineInvite first
      if (isInvited && game.status == GameStatus.waiting) {
        try {
          await _chessService.declineInvite(game.id);
        } catch (e) {
          Logger.warning('Error declining invite, will try direct delete: $e', tag: 'ChessFamilyGameScreen');
        }
      }
      
      // Delete the game and invite (works for any status)
      await _chessService.deleteGame(game.id);
      
              // Update UI - always remove from list even if delete failed (might be phantom game)
              if (mounted) {
                setState(() {
                  _waitingGames = _waitingGames.where((g) => g.id != game.id).toList();
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isActive ? 'Game deleted' : isChallenger ? 'Challenge cancelled' : isInvited ? 'Challenge declined' : 'Game deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
    } catch (e, stackTrace) {
      Logger.error('Error deleting game', error: e, stackTrace: stackTrace, tag: 'ChessFamilyGameScreen');
      
      // If permission denied, it's likely a phantom game - remove from UI anyway
      final isPermissionDenied = e.toString().contains('permission-denied');
      
      if (mounted) {
        // Remove from UI even if delete failed (phantom game)
        setState(() {
          _waitingGames = _waitingGames.where((g) => g.id != game.id).toList();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPermissionDenied 
                ? 'Removed invalid game from list (may not exist in database)'
                : 'Error deleting game: ${e.toString()}'),
            backgroundColor: isPermissionDenied ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Chess'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LOBBY - Open Challenges Section (always visible, even if empty)
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        color: _waitingGames.isNotEmpty 
                            ? Colors.orange.shade50 
                            : Colors.grey.shade100,
                        border: Border.all(
                          color: _waitingGames.isNotEmpty 
                              ? Colors.orange.shade300 
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _waitingGames.isNotEmpty 
                                    ? Icons.notifications_active 
                                    : Icons.casino,
                                color: _waitingGames.isNotEmpty 
                                    ? Colors.orange.shade700 
                                    : Colors.grey.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Lobby - Open Challenges',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _waitingGames.isNotEmpty 
                                      ? Colors.orange.shade900 
                                      : Colors.grey.shade700,
                                ),
                              ),
                              if (_waitingGames.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade700,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_waitingGames.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          if (_waitingGames.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingMD),
                              child: Text(
                                'No open challenges. Challenge a family member below!',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else ...[
                            // Delete all button for testing/cleanup
                            if (_waitingGames.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Delete all waiting games button
                                    ElevatedButton.icon(
                                      onPressed: () => _deleteAllWaitingGames(),
                                      icon: const Icon(Icons.delete_sweep, size: 20),
                                      label: Text('Delete All Waiting (${_waitingGames.length})'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Clear entire database button
                                    OutlinedButton.icon(
                                      onPressed: () => _deleteAllChessGamesFromDatabase(),
                                      icon: const Icon(Icons.delete_forever, size: 20),
                                      label: const Text('Clear All Chess Data'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red.shade900,
                                        side: BorderSide(color: Colors.red.shade900, width: 2),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ..._waitingGames.map((game) => _buildGameCard(game)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),

                    // Family members
                    const Text(
                      'Challenge Family Member',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    if (_familyMembers.isEmpty)
                      ModernCard(
                        padding: const EdgeInsets.all(AppTheme.spacingLG),
                        child: Center(
                          child: Text(
                            'No other family members available',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      ..._familyMembers.map((member) => _buildMemberCard(member)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGameCard(ChessGame game) {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();
    
    // CRITICAL: Challenger should NOT auto-navigate - they must click "Join" button explicitly
    final isChallenger = game.whitePlayerId == user.uid;
    final isActive = game.status == GameStatus.active;
    
    return ChessGameCard(
      game: game,
      currentUserId: user.uid,
      onAccept: () => _joinGame(game),
      onJoin: () => _joinGame(game),
      onDelete: () => _cancelChallenge(game),
      // Only allow tap-to-join for invited players, NOT for challengers
      // Challengers must use the explicit "Join" button
      onTap: (isChallenger && isActive) ? null : () => _joinGame(game),
    );
  }

  Widget _buildMemberCard(UserModel member) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      onTap: () => _createGame(member),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(member.displayName[0].toUpperCase()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              member.displayName,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

