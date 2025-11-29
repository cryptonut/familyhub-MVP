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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _authService.getFamilyMembers();
      final user = _authService.currentUser;
      
      // Filter out current user
      final otherMembers = members.where((m) => m.uid != user?.uid).toList();

      // Load waiting games
      List<ChessGame> waitingGames = [];
      if (user != null) {
        final activeGames = await _chessService.getActiveGames(user.uid);
        waitingGames = activeGames
            .where((g) => g.mode == GameMode.family && g.status == GameStatus.waiting)
            .toList();
      }

      setState(() {
        _familyMembers = otherMembers;
        _waitingGames = waitingGames;
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

      final game = await _chessService.createFamilyGame(
        whitePlayerId: user.uid,
        whitePlayerName: userModel?.displayName ?? 'Player',
        familyId: userModel!.familyId!,
        blackPlayerId: opponent.uid,
        blackPlayerName: opponent.displayName,
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
                    // Waiting games
                    if (_waitingGames.isNotEmpty) ...[
                      const Text(
                        'Waiting for You',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      ..._waitingGames.map((game) => _buildWaitingGameCard(game)),
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
    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      onTap: () => _joinGame(game),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: Colors.orange),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${game.whitePlayerName} challenged you!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Tap to join',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
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

