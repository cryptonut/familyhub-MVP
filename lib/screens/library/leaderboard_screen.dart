import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/leaderboard_entry.dart';
import '../../services/auth_service.dart';
import '../../services/leaderboard_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

class LeaderboardScreen extends StatefulWidget {
  final String hubId;
  final String? familyId;

  const LeaderboardScreen({
    super.key,
    required this.hubId,
    this.familyId,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardService _leaderboardService = LeaderboardService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  LeaderboardScope _selectedScope = LeaderboardScope.hub;
  List<LeaderboardEntry> _entries = [];
  int? _userRank;
  bool _isLoading = true;
  String? _familyId;

  @override
  void initState() {
    super.initState();
    _loadFamilyId();
    _loadLeaderboard();
  }

  Future<void> _loadFamilyId() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      _familyId = userModel?.familyId;
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      List<LeaderboardEntry> entries;
      switch (_selectedScope) {
        case LeaderboardScope.family:
          final familyId = widget.familyId ?? _familyId;
          if (familyId == null) {
            setState(() {
              _isLoading = false;
              _entries = [];
            });
            return;
          }
          entries = await _leaderboardService.getFamilyLeaderboard(familyId);
          break;
        case LeaderboardScope.hub:
          entries = await _leaderboardService.getHubLeaderboard(widget.hubId);
          break;
        case LeaderboardScope.global:
          entries = await _leaderboardService.getGlobalLeaderboard();
          break;
      }

      final userId = _auth.currentUser?.uid;
      int? userRank;
      if (userId != null) {
        userRank = await _leaderboardService.getUserRank(
          userId: userId,
          scope: _selectedScope,
          familyId: widget.familyId ?? _familyId,
          hubId: widget.hubId,
        );
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _userRank = userRank;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leaderboard: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: Column(
        children: [
          // Scope selector
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: SegmentedButton<LeaderboardScope>(
              segments: [
                if ((widget.familyId ?? _familyId) != null)
                  const ButtonSegment(
                    value: LeaderboardScope.family,
                    label: Text('Family'),
                  ),
                const ButtonSegment(
                  value: LeaderboardScope.hub,
                  label: Text('Hub'),
                ),
                const ButtonSegment(
                  value: LeaderboardScope.global,
                  label: Text('Global'),
                ),
              ],
              selected: {_selectedScope},
              onSelectionChanged: (Set<LeaderboardScope> newSelection) {
                setState(() {
                  _selectedScope = newSelection.first;
                });
                _loadLeaderboard();
              },
            ),
          ),

          // Leaderboard content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const EmptyState(
                        icon: Icons.leaderboard_outlined,
                        title: 'No entries yet',
                        message: 'Complete challenges to appear on the leaderboard',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          final isCurrentUser =
                              entry.userId == _auth.currentUser?.uid;
                          final isTopThree = entry.rank <= 3;

                          return ModernCard(
                            margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                            color: isCurrentUser
                                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                : null,
                            child: ListTile(
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: isTopThree ? 24 : 20,
                                    backgroundColor: isTopThree
                                        ? _getRankColor(entry.rank)
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    child: entry.userPhotoUrl != null
                                        ? ClipOval(
                                            child: CachedNetworkImage(
                                              imageUrl: entry.userPhotoUrl!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Text(
                                            entry.userName.isNotEmpty
                                                ? entry.userName[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              color: isTopThree
                                                  ? Theme.of(context).colorScheme.onPrimary
                                                  : Theme.of(context).colorScheme.onSurface,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                  if (isTopThree)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surface,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.emoji_events,
                                          size: 16,
                                          color: _getRankColor(entry.rank),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '#${entry.rank}',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isTopThree
                                            ? _getRankColor(entry.rank)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.userName,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: isCurrentUser
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Score: ${entry.totalScore}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${entry.booksCompleted} books • Avg: ${entry.averageScore.toStringAsFixed(1)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: isCurrentUser
                                  ? Chip(
                                      label: const Text('You'),
                                      backgroundColor: theme.colorScheme.primary,
                                      labelStyle: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
      case 3:
        return Colors.brown[300]!;
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }
}

