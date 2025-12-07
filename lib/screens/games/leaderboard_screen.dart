import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import '../../services/games_service.dart';
import '../../services/auth_service.dart';
import '../../models/game_stats.dart';
import '../../models/user_model.dart';
import 'my_stats_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final GamesService _gamesService = GamesService();
  final AuthService _authService = AuthService();

  List<GameStats> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    _subscribeToUpdates();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final leaderboard = await _gamesService.getLeaderboard();
      setState(() {
        _leaderboard = leaderboard;
      });
    } catch (e) {
      Logger.error('Error loading leaderboard', error: e, tag: 'LeaderboardScreen');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToUpdates() {
    _gamesService.getLeaderboardStream().listen((leaderboard) {
      if (mounted) {
        setState(() {
          _leaderboard = leaderboard;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              child: _leaderboard.isEmpty
                  ? Center(
                      child: Text(
                        'No scores yet. Be the first to play!',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _leaderboard.length,
                      itemBuilder: (context, index) {
                        final stats = _leaderboard[index];
                        return _buildLeaderboardItem(stats, index);
                      },
                    ),
            ),
    );
  }

  Widget _buildLeaderboardItem(GameStats stats, int index) {
    final isMe = stats.userId == _authService.currentUser?.uid;
    final rank = index + 1;

    return FutureBuilder<UserModel?>(
      future: _authService.getUserModel(stats.userId),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: isMe ? Colors.blue.shade50 : null,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyStatsScreen(userId: stats.userId),
                ),
              );
            },
            child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: isMe ? Colors.blue : Colors.grey[300],
                  child: Text(
                    user?.displayName[0].toUpperCase() ?? '?',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.grey[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (rank <= 3)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.emoji_events,
                        size: 16,
                        color: rank == 1
                            ? Colors.amber
                            : rank == 2
                                ? Colors.grey[400]!
                                : Colors.brown[300]!,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              user?.displayName ?? 'Unknown',
              style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${stats.totalWins} total wins'),
                if (stats.tetrisHighScore > 0)
                  Row(
                    children: [
                      const Icon(Icons.gamepad, color: Colors.red, size: 16),
                      const SizedBox(width: 4),
                      Text('Tetris: ${stats.tetrisHighScore}'),
                    ],
                  ),
                if (stats.streakDays > 0)
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text('${stats.streakDays} day streak'),
                    ],
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: rank == 1
                        ? Colors.amber
                        : rank == 2
                            ? Colors.grey[600]
                            : rank == 3
                                ? Colors.brown[400]
                                : Colors.grey[700],
                  ),
                ),
                Text(
                  '${stats.winsChess}C ${stats.winsScramble}S',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}

