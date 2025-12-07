import 'package:flutter/material.dart';
import '../../services/games_service.dart';
import '../../services/auth_service.dart';
import '../../models/game_stats.dart';
import '../../models/user_model.dart';
import '../../core/services/logger_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'dart:math' as math;

class PersonalStatsScreen extends StatefulWidget {
  final String userId;
  final String? userName;
  
  const PersonalStatsScreen({
    super.key,
    required this.userId,
    this.userName,
  });

  @override
  State<PersonalStatsScreen> createState() => _PersonalStatsScreenState();
}

class _PersonalStatsScreenState extends State<PersonalStatsScreen> {
  final GamesService _gamesService = GamesService();
  final AuthService _authService = AuthService();
  
  GameStats? _stats;
  UserModel? _user;
  bool _isLoading = true;
  
  // Game data structure
  final List<Map<String, dynamic>> _games = [
    {
      'name': 'Chess',
      'winsField': 'winsChess',
      'icon': Icons.sports_esports,
      'color': Colors.brown,
    },
    {
      'name': 'Word Scramble',
      'winsField': 'winsScramble',
      'icon': Icons.text_fields,
      'color': Colors.purple,
    },
    {
      'name': 'Tetris',
      'winsField': 'tetrisHighScore',
      'icon': Icons.gamepad,
      'color': Colors.red,
      'isScore': true,
    },
    {
      'name': '2048',
      'winsField': 'puzzle2048HighScore',
      'icon': Icons.apps,
      'color': Colors.blue,
      'isScore': true,
    },
    {
      'name': 'Slide Puzzle',
      'winsField': 'slidePuzzleBestTime',
      'icon': Icons.view_module,
      'color': Colors.teal,
      'isTime': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _stats = await _gamesService.getUserStats(widget.userId);
      _user = await _authService.getUserModel(widget.userId);
    } catch (e) {
      Logger.error('Error loading personal stats', error: e, tag: 'PersonalStatsScreen');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _getWins(String field, GameStats stats) {
    switch (field) {
      case 'winsChess':
        return stats.winsChess;
      case 'winsScramble':
        return stats.winsScramble;
      case 'winsBingo':
        return stats.winsBingo;
      case 'tetrisHighScore':
        return stats.tetrisHighScore;
      case 'puzzle2048HighScore':
        return stats.puzzle2048HighScore;
      case 'slidePuzzleBestTime':
        return stats.slidePuzzleBestTime;
      default:
        return 0;
    }
  }

  String _formatTime(int milliseconds) {
    if (milliseconds == 0) return 'N/A';
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    }
    return '${remainingSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName ?? _user?.displayName ?? 'Stats'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? EmptyState(
                  icon: Icons.bar_chart,
                  title: 'No stats available',
                  message: 'This user has not played any games yet.',
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header stats
                      ModernCard(
                        margin: const EdgeInsets.all(AppTheme.spacingMD),
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        child: Column(
                          children: [
                            if (_user != null)
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: Text(
                                  _user!.displayName.isNotEmpty
                                      ? _user!.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            if (_user != null) const SizedBox(height: 16),
                            Text(
                              _user?.displayName ?? 'Player',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '${_stats!.totalWins}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Total Wins',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_stats!.streakDays > 0) ...[
                                  const SizedBox(width: 32),
                                  Column(
                                    children: [
                                      const Icon(Icons.local_fire_department, color: Colors.orange),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_stats!.streakDays}',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Day Streak',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Game-by-game stats table
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
                        child: Text(
                          'Game Statistics',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ModernCard(
                        margin: const EdgeInsets.all(AppTheme.spacingMD),
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            // Header row
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingMD),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Game',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Score/Time',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Data rows
                            ..._games.map((game) {
                              final value = _getWins(game['winsField'] as String, _stats!);
                              final isScore = game['isScore'] == true;
                              final isTime = game['isTime'] == true;
                              
                              return Container(
                                padding: const EdgeInsets.all(AppTheme.spacingMD),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      game['icon'] as IconData,
                                      color: game['color'] as Color,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        game['name'] as String,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        isTime
                                            ? _formatTime(value)
                                            : value.toString(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: value > 0
                                              ? Theme.of(context).colorScheme.primary
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

