import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/logger_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_model.dart';
import '../../../widgets/ui_components.dart';
import '../../../utils/app_theme.dart';
import '../models/chess_game.dart';
import '../services/chess_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
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
              // Filter: games where current user is invited, OR games where they're the challenger waiting, OR open invitations
              _waitingGames = games
                  .where((g) => 
                      (g.invitedPlayerId == user.uid) || // User was invited
                      (g.whitePlayerId == user.uid && g.status == GameStatus.waiting) || // User is challenger waiting for acceptance
                      (g.whitePlayerId != user.uid && g.invitedPlayerId == null) // Open invitation
                  )
                  .toList();
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
      
      // Immediately exit modal/dialog and navigate back to home
      if (mounted) {
        Navigator.pop(context); // Exit any modal/dialog
        Navigator.pop(context); // Navigate back to home_screen
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

  Future<void> _joinGame(ChessGame game) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final userModel = await _authService.getCurrentUserModel();
      await _chessService.joinFamilyGame(
        gameId: game.id,
        blackPlayerId: user.uid,
        blackPlayerName: userModel?.displayName ?? 'Player',
      );

      // Navigate to game screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChessGameScreen(gameId: game.id, mode: GameMode.family),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error joining family game', error: e, tag: 'ChessFamilyGameScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _cancelChallenge(ChessGame game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Challenge'),
        content: const Text('Are you sure you want to cancel this challenge?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete the game and invite
      await _chessService.deleteGame(game.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge cancelled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error cancelling challenge', error: e, tag: 'ChessFamilyGameScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
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
                    // Waiting games - Make more prominent
                    if (_waitingGames.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade300, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.notifications_active, color: Colors.orange.shade700, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'Challenges Waiting (${_waitingGames.length})',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            ..._waitingGames.map((game) => _buildWaitingGameCard(game)),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLG),
                    ],

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

  Widget _buildWaitingGameCard(ChessGame game) {
    final user = _authService.currentUser;
    final isInvited = game.invitedPlayerId == user?.uid;
    final isChallenger = game.whitePlayerId == user?.uid;
    final challengerName = game.whitePlayerName ?? 'Unknown';
    final invitedName = game.blackPlayerName ?? 'Someone';
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: isInvited 
            ? Colors.orange.shade100 
            : isChallenger 
                ? Colors.green.shade50 
                : Colors.blue.shade50,
        border: Border.all(
          color: isInvited 
              ? Colors.orange.shade400 
              : isChallenger 
                  ? Colors.green.shade400 
                  : Colors.blue.shade300,
          width: (isInvited || isChallenger) ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isInvited 
                ? Colors.orange.shade200 
                : isChallenger 
                    ? Colors.green.shade200 
                    : Colors.blue.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isInvited 
                ? Icons.notifications_active 
                : isChallenger 
                    ? Icons.hourglass_empty 
                    : Icons.person_add,
            color: isInvited 
                ? Colors.orange.shade900 
                : isChallenger 
                    ? Colors.green.shade900 
                    : Colors.blue.shade900,
            size: 24,
          ),
        ),
        title: Text(
          isInvited 
              ? '$challengerName challenged you!'
              : isChallenger
                  ? 'Waiting for $invitedName to accept...'
                  : 'Game by $challengerName',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isInvited 
                ? Colors.orange.shade900 
                : isChallenger 
                    ? Colors.green.shade900 
                    : Colors.blue.shade900,
          ),
        ),
        subtitle: Text(
          isInvited 
              ? 'Tap to accept challenge' 
              : isChallenger
                  ? 'Challenge sent - waiting for response'
                  : 'Tap to join as opponent',
          style: TextStyle(
            color: isInvited 
                ? Colors.orange.shade700 
                : isChallenger 
                    ? Colors.green.shade700 
                    : Colors.blue.shade700,
            fontSize: 12,
          ),
        ),
        trailing: isChallenger
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel challenge',
                onPressed: () => _cancelChallenge(game),
                color: Colors.grey.shade700,
              )
            : ElevatedButton.icon(
                onPressed: () => _joinGame(game),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(isInvited ? 'Accept' : 'Join'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isInvited ? Colors.orange.shade700 : Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
        onTap: isChallenger ? null : () => _joinGame(game),
      ),
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

