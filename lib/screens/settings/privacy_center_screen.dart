import 'package:flutter/material.dart';
import '../../services/privacy_service.dart';
import '../../services/auth_service.dart';
import '../../models/privacy_activity.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'package:intl/intl.dart';

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  final PrivacyService _privacyService = PrivacyService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _activeShares = [];
  List<PrivacyActivity> _recentActivity = [];
  bool _isLoading = true;
  bool _isMasterToggleOn = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final shares = await _privacyService.getActiveShares();
      final activity = await _privacyService.getRecentActivity();
      
      setState(() {
        _activeShares = shares;
        _recentActivity = activity;
        _isMasterToggleOn = shares.isNotEmpty;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading privacy data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleMasterSwitch(bool value) async {
    if (!value) {
      // Turn off all sharing
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turn Off All Sharing'),
          content: const Text(
            'This will disable all active sharing: location, calendar sync, birthday visibility, and geofence alerts. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Turn Off All'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          await _privacyService.stopAllSharing();
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All sharing has been turned off'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } else {
      // Can't turn on via master switch - user must enable individual features
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable individual sharing features to activate'),
          ),
        );
      }
    }
  }

  Future<void> _pauseShare(String shareType) async {
    try {
      await _privacyService.pauseShare(shareType);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$shareType sharing paused'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Center'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Master Toggle Card
                    ModernCard(
                      margin: const EdgeInsets.all(AppTheme.spacingMD),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              _isMasterToggleOn ? Icons.share : Icons.block,
                              color: _isMasterToggleOn ? Colors.green : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Active Sharing',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _isMasterToggleOn
                                        ? '${_activeShares.length} active shares'
                                        : 'No active sharing',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isMasterToggleOn,
                              onChanged: _toggleMasterSwitch,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Active Shares Section
                    if (_activeShares.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Active Shares',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._activeShares.map((share) => _buildShareCard(share)),
                    ],

                    // Turn Off All Button
                    if (_activeShares.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _toggleMasterSwitch(false),
                            icon: const Icon(Icons.stop_circle),
                            label: const Text('Turn Off All Sharing'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Recent Activity Section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Activity',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_recentActivity.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'No recent activity',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._recentActivity.map((activity) => _buildActivityCard(activity)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildShareCard(Map<String, dynamic> share) {
    return ModernCard(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: AppTheme.spacingXS),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(
            share['icon'] as IconData,
            color: Colors.blue.shade700,
          ),
        ),
        title: Text(share['name'] as String),
        subtitle: Text(share['description'] as String),
        trailing: TextButton(
          onPressed: () => _pauseShare(share['type'] as String),
          child: const Text('Pause'),
        ),
      ),
    );
  }

  Widget _buildActivityCard(PrivacyActivity activity) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    IconData icon;
    Color color;

    switch (activity.action) {
      case 'enabled':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'disabled':
      case 'stopped':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'paused':
        icon = Icons.pause_circle;
        color = Colors.orange;
        break;
      default:
        icon = Icons.info;
        color = Colors.blue;
    }

    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          '${activity.action.toUpperCase()} ${activity.shareType}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(dateFormat.format(activity.timestamp)),
        trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
      ),
    );
  }
}

