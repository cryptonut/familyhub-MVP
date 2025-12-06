import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../core/services/logger_service.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/ui_components.dart';
import '../../../utils/app_theme.dart';
import '../models/chess_game.dart';
import '../models/chess_game_role.dart';
import '../services/chess_service.dart';
import '../screens/chess_game_screen.dart';
import '../screens/chess_solo_game_screen.dart';
import '../screens/chess_family_game_screen.dart';

/// Lobby screen for selecting chess game mode
class ChessLobbyScreen extends StatefulWidget {
  const ChessLobbyScreen({super.key});

  @override
  State<ChessLobbyScreen> createState() => _ChessLobbyScreenState();
}

class _ChessLobbyScreenState extends State<ChessLobbyScreen> {
  final AuthService _authService = AuthService();
  final ChessService _chessService = ChessService();
  bool _openModeEnabled = false;
  bool _isLoading = true;
  List<ChessGame> _waitingGames = [];
  List<ChessGame> _activeGames = [];
  StreamSubscription<List<ChessGame>>? _waitingGamesSubscription;
  StreamSubscription<List<ChessGame>>? _activeGamesSubscription;
  String? _currentFamilyId;
  String? _currentUserId;
  final Set<String> _notifiedGameIds = {};

  @override
  void initState() {
    super.initState();
    _checkOpenModeEnabled();
    _loadWaitingGames();
  }

  @override
  void dispose() {
    _waitingGamesSubscription?.cancel();
    _activeGamesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadWaitingGames() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      final user = _authService.currentUser;
      _currentFamilyId = userModel?.familyId;
      _currentUserId = user?.uid;

      if (_currentFamilyId != null && _currentUserId != null) {
        // Stream waiting games
        _waitingGamesSubscription?.cancel();
        _waitingGamesSubscription = _chessService
            .streamWaitingFamilyGames(_currentFamilyId!)
            .listen((games) {
          if (mounted) {
            setState(() {
              // Use ChessGameRole to determine which games to show
              _waitingGames = games
                  .where((g) {
                    final role = ChessGameRole.determine(g, _currentUserId!);
                    // Show if user is involved in any way
                    final shouldShow = role.isChallenger || role.isInvited || role.isBlackPlayer || role.isWhitePlayer;
                    
                    // Show notification for challenger when game is accepted
                    if (role.isChallenger && g.status == GameStatus.active && g.blackPlayerId != null && !_notifiedGameIds.contains(g.id)) {
                      _notifiedGameIds.add(g.id);
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
                                    child: Text('$opponentName accepted! Tap to join'),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 15),
                              action: SnackBarAction(
                                label: 'Join Now',
                                textColor: Colors.white,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChessGameScreen(gameId: g.id, mode: GameMode.family),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }
                      });
                    }
                    
                    return shouldShow;
                  })
                  .toList();
            });
          }
        });

        // Load active games
        _loadActiveGames();
      }
    } catch (e) {
      Logger.error('Error loading waiting games', error: e, tag: 'ChessLobbyScreen');
    }
  }

  Future<void> _loadActiveGames() async {
    if (_currentUserId == null) return;
    
    try {
      final games = await _chessService.getActiveGames(_currentUserId!);
      if (mounted) {
        setState(() {
          _activeGames = games;
        });
      }
    } catch (e) {
      Logger.error('Error loading active games', error: e, tag: 'ChessLobbyScreen');
    }
  }

  Future<void> _checkOpenModeEnabled() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel?.familyId != null) {
        // Check family settings - this would be in a family settings collection
        // For now, default to false
        setState(() {
          _openModeEnabled = false; // TODO: Load from family settings
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Error checking open mode', error: e, tag: 'ChessLobbyScreen');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Waiting Games Alert - Show prominently at top
                  if (_waitingGames.isNotEmpty) ...[
                    _buildWaitingGamesAlert(),
                    const SizedBox(height: AppTheme.spacingMD),
                  ],
                  
                  const Text(
                    'Choose Game Mode',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  
                  // Solo Mode
                  _buildModeCard(
                    title: 'Solo vs AI',
                    description: 'Play against an AI opponent',
                    icon: Icons.smart_toy,
                    color: Colors.blue,
                    onTap: () => _startSoloGame(context),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingMD),
                  
                  // Family Mode
                  _buildModeCard(
                    title: 'Family Game',
                    description: 'Challenge a family member',
                    icon: Icons.family_restroom,
                    color: Colors.green,
                    onTap: () => _startFamilyGame(context),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingMD),
                  
                  // Open Mode
                  _buildModeCard(
                    title: 'Open Matchmaking',
                    description: 'Play against random players',
                    icon: Icons.people,
                    color: Colors.orange,
                    enabled: _openModeEnabled,
                    onTap: _openModeEnabled ? () => _startOpenGame(context) : null,
                    disabledMessage: 'Open mode is disabled for your family',
                  ),
                  
                  const SizedBox(height: AppTheme.spacingLG),
                  
                  // Active Games
                  _buildActiveGamesSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool enabled = true,
    String? disabledMessage,
  }) {
    return ModernCard(
      onTap: enabled ? onTap : null,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      color: enabled ? null : Colors.grey.shade200,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: enabled ? null : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enabled ? description : (disabledMessage ?? 'Not available'),
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled ? Colors.grey[600] : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (enabled)
            Icon(Icons.chevron_right, color: Colors.grey[400])
          else
            Icon(Icons.lock, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildWaitingGamesAlert() {
    final user = _authService.currentUser;
    if (user == null || _waitingGames.isEmpty) return const SizedBox.shrink();
    
    final totalGames = _waitingGames.length;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
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
              Icon(Icons.notifications_active, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$totalGames Game${totalGames > 1 ? 's' : ''} Waiting',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Show all waiting games using ChessGameRole for consistent logic
          ..._waitingGames.take(2).map((game) {
            final role = ChessGameRole.determine(game, user.uid);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.displayText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: role.isInvited 
                                ? Colors.orange.shade800 
                                : role.isChallenger && game.status == GameStatus.active
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                          ),
                        ),
                        if (role.subtitleText.isNotEmpty)
                          Text(
                            role.subtitleText,
                            style: TextStyle(
                              fontSize: 12,
                              color: role.isInvited 
                                  ? Colors.orange.shade600 
                                  : Colors.green.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red.shade700,
                    onPressed: () => _deleteGame(game),
                    tooltip: 'Delete',
                  ),
                  const SizedBox(width: 4),
                  if (role.canAccept || role.canJoin)
                    ElevatedButton.icon(
                      onPressed: () {
                        if (role.canAccept || role.canJoin) {
                          if (game.status == GameStatus.active && game.blackPlayerId != null) {
                            // Navigate directly to active game
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChessGameScreen(gameId: game.id, mode: GameMode.family),
                              ),
                            );
                          } else {
                            // Navigate to family game screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ChessFamilyGameScreen(),
                              ),
                            );
                          }
                        }
                      },
                      icon: Icon(role.buttonIcon, size: 18),
                      label: Text(role.buttonText.isNotEmpty ? role.buttonText : 'View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: role.buttonColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChessFamilyGameScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
            );
          }),
          if (totalGames > 2)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChessFamilyGameScreen(),
                  ),
                );
              },
              child: Text(
                'View all $totalGames games',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveGamesSection() {
    if (_activeGames.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Games',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        ..._activeGames.take(3).map((game) => ModernCard(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChessGameScreen(gameId: game.id, mode: GameMode.family),
              ),
            );
          },
          child: Row(
            children: [
              const Icon(Icons.sports_esports, color: Colors.brown),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs ${game.isPlayer(_currentUserId!) ? (game.whitePlayerId == _currentUserId ? game.blackPlayerName ?? 'Opponent' : game.whitePlayerName ?? 'Opponent') : 'Unknown'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Your turn' + (game.isMyTurn(_currentUserId!) ? '' : ' - Waiting'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        )),
        if (_activeGames.length > 3)
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChessFamilyGameScreen(),
                ),
              );
            },
            child: const Text('View all active games'),
          ),
      ],
    );
  }

  void _startSoloGame(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChessSoloGameScreen(),
      ),
    );
  }

  void _startFamilyGame(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChessFamilyGameScreen(),
      ),
    );
  }

  void _startOpenGame(BuildContext context) {
    // Navigate to matchmaking screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChessGameScreen(gameId: null, mode: GameMode.open),
      ),
    );
  }

  Future<void> _deleteGame(ChessGame game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: const Text('Are you sure you want to delete this game?'),
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

    if (confirmed == true) {
      try {
        await _chessService.deleteGame(game.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting game: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

