import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/games_service.dart';
import '../../services/auth_service.dart';
import '../../models/game_stats.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'chess_puzzle_screen.dart';
import 'word_scramble_screen.dart';
import 'family_bingo_screen.dart';
import 'leaderboard_screen.dart';

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
      debugPrint('Error loading games data: $e');
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
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    _buildGameCard(
                      title: 'Chess Puzzles',
                      description: 'Solve chess puzzles solo',
                      icon: Icons.sports_esports,
                      color: Colors.brown,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChessPuzzleScreen(),
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
                      title: 'Family Bingo',
                      description: '5×5 auto-generated bingo cards',
                      icon: Icons.grid_view,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FamilyBingoScreen(),
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
                                  color: Colors.grey[800],
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
                                    style: TextStyle(color: Colors.grey[600]),
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
            color: Colors.grey[600],
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
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
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
              backgroundColor: isMe ? Colors.blue : Colors.grey[300],
              child: Text(
                user?.displayName[0].toUpperCase() ?? '?',
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.grey[800],
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
                    color: Colors.grey[700],
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

