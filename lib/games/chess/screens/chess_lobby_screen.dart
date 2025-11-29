import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/logger_service.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/ui_components.dart';
import '../../../utils/app_theme.dart';
import '../models/chess_game.dart';
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
  bool _openModeEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkOpenModeEnabled();
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

  Widget _buildActiveGamesSection() {
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
        // TODO: Load and display active games
        Text(
          'No active games',
          style: TextStyle(color: Colors.grey[600]),
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
}

