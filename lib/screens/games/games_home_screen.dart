import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/logger_service.dart';
import '../../services/games_service.dart';
import '../../services/auth_service.dart';
import '../../models/game_stats.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'word_scramble_screen.dart';
import 'leaderboard_screen.dart';
import 'my_stats_screen.dart';
import '../../games/chess/screens/chess_lobby_screen.dart';
import '../../games/tetris/screens/tetris_screen.dart';
import '../../games/puzzle2048/screens/puzzle2048_screen.dart';
import '../../games/slide_puzzle/screens/slide_puzzle_screen.dart';

class GamesHomeScreen extends StatefulWidget {
  const GamesHomeScreen({super.key});

  @override
  State<GamesHomeScreen> createState() => _GamesHomeScreenState();
}

class _GamesHomeScreenState extends State<GamesHomeScreen> {
  final GamesService _gamesService = GamesService();
  final AuthService _authService = AuthService();

  List<GameStats> _leaderboard = [];
  GameStats? _myStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        _myStats = await _gamesService.getUserStats(user.uid);
      }
      _leaderboard = await _gamesService.getLeaderboard();
    } catch (e) {
      Logger.error('Error loading games data', error: e, tag: 'GamesHomeScreen');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Games'),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeaderboardScreen(),
                ),
              );
            },
            tooltip: 'View Leaderboard',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // My Stats Card
                    if (_myStats != null) _buildMyStatsCard(_myStats!),

                    // Game Cards
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Choose a Game',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    _buildGameCard(
                      title: 'Chess',
                      description: 'Play chess vs AI, family, or online',
                      icon: Icons.sports_esports,
                      color: Colors.brown,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChessLobbyScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    _buildGameCard(
                      title: 'Word Scramble',
                      description: 'Daily and random word challenges',
                      icon: Icons.text_fields,
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WordScrambleScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    _buildGameCard(
                      title: 'Tetris',
                      description: 'Classic falling blocks puzzle',
                      icon: Icons.gamepad,
                      color: Colors.red,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TetrisScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    _buildGameCard(
                      title: '2048',
                      description: 'Combine tiles to reach 2048',
                      icon: Icons.apps,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Puzzle2048Screen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    _buildGameCard(
                      title: 'Slide Puzzle',
                      description: 'Classic 15-tile sliding puzzle',
                      icon: Icons.view_module,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SlidePuzzleScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),

                    // Leaderboard Preview
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Leaderboard',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LeaderboardScreen(),
                                    ),
                                  );
                                },
                                child: const Text('View All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_leaderboard.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'No scores yet. Be the first to play!',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._leaderboard.take(5).map((stats) => _buildLeaderboardItem(stats)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMyStatsCard(GameStats stats) {
    return ModernCard(
      margin: const EdgeInsets.all(AppTheme.spacingMD),
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MyStatsScreen(),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Stats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Wins', stats.totalWins.toString(), Icons.emoji_events),
              _buildStatItem('Chess', stats.winsChess.toString(), Icons.sports_esports),
              _buildStatItem('Scramble', stats.winsScramble.toString(), Icons.text_fields),
              _buildStatItem('Bingo', stats.winsBingo.toString(), Icons.grid_view),
            ],
          ),
          if (stats.streakDays > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '${stats.streakDays} day streak!',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildGameCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ModernCard(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: AppTheme.spacingSM),
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.spacingLG),
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(GameStats stats) {
    return FutureBuilder<UserModel?>(
      future: _authService.getUserModel(stats.userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isMe = stats.userId == _authService.currentUser?.uid;

        return ModernCard(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
          color: isMe ? Colors.blue.shade50 : null,
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isMe ? Colors.blue : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                user?.displayName[0].toUpperCase() ?? '?',
                style: TextStyle(
                  color: isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              user?.displayName ?? 'Unknown',
              style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text('${stats.totalWins} wins'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stats.streakDays > 0) ...[
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                  const SizedBox(width: 4),
                  Text('${stats.streakDays}'),
                  const SizedBox(width: 8),
                ],
                Text(
                  '#${_leaderboard.indexOf(stats) + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

