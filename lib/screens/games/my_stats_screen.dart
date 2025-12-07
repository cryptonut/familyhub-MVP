import 'package:flutter/material.dart';
import '../../models/game_stats.dart';
import '../../models/user_model.dart';
import '../../services/games_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/skeletons/skeleton_widgets.dart';

class MyStatsScreen extends StatefulWidget {
  final String? userId; // If null, shows current user's stats

  const MyStatsScreen({super.key, this.userId});

  @override
  State<MyStatsScreen> createState() => _MyStatsScreenState();
}

class _MyStatsScreenState extends State<MyStatsScreen> {
  final GamesService _gamesService = GamesService();
  final AuthService _authService = AuthService();
  
  GameStats? _stats;
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final targetUserId = widget.userId ?? _authService.currentUser?.uid;
      if (targetUserId == null) return;

      final user = await _authService.getUserModel(targetUserId);
      final stats = await _gamesService.getUserStats(targetUserId);

      if (mounted) {
        setState(() {
          _user = user;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle error
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _user != null 
        ? '${_user!.displayName}\'s Stats' 
        : 'My Stats';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? const Center(child: Text('No stats available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildStreakCard(),
                      const SizedBox(height: 16),
                      _buildOverviewCard(),
                      const SizedBox(height: 16),
                      _buildDetailedStats(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    if (_user == null) return const SizedBox.shrink();
    
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.blue.shade100,
          child: Text(
            _user!.displayName[0].toUpperCase(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _user!.displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Joined ${_user!.createdAt.year}',
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard() {
    if (_stats == null || _stats!.streakDays == 0) return const SizedBox.shrink();

    return ModernCard(
      color: Colors.orange.shade50,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_stats!.streakDays} Day Streak!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
              const Text(
                'Keep playing to maintain your streak',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    if (_stats == null) return const SizedBox.shrink();

    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: _buildStatItem('Total Wins', _stats!.totalWins.toString(), Icons.emoji_events, Colors.amber),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
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

  Widget _buildDetailedStats() {
    if (_stats == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Game Performance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildGameRow('Chess', _stats!.winsChess, Icons.sports_esports, Colors.brown),
        _buildGameRow('Word Scramble', _stats!.winsScramble, Icons.text_fields, Colors.purple),
        _buildGameRow('Bingo', _stats!.winsBingo, Icons.grid_view, Colors.orange),
        _buildGameRow('Tetris', 0, Icons.gamepad, Colors.red, highScore: _stats!.tetrisHighScore),
        _buildGameRow('2048', 0, Icons.apps, Colors.blue, highScore: _stats!.puzzle2048HighScore),
      ],
    );
  }

  Widget _buildGameRow(String name, int wins, IconData icon, Color color, {int? highScore}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (highScore != null && highScore > 0)
                    Text(
                      'High Score: $highScore',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    )
                  else
                    Text(
                      '$wins Wins',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (highScore == null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$wins',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
