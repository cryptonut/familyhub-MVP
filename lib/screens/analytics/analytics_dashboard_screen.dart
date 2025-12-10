import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/skeletons/skeleton_widgets.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final AuthService _authService = AuthService();
  FamilyAnalytics? _analytics;
  bool _isLoading = true;
  String? _error;
  int _selectedDays = 30;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel?.familyId == null) {
        setState(() {
          _error = 'You must be part of a family to view analytics';
          _isLoading = false;
        });
        return;
      }

      final analytics = await _analyticsService.getFamilyAnalytics(
        familyId: userModel!.familyId!,
        days: _selectedDays,
      );

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      Logger.error('Error loading analytics', error: e, stackTrace: st, tag: 'AnalyticsDashboardScreen');
      if (mounted) {
        setState(() {
          _error = 'Error loading analytics: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Analytics'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list),
            onSelected: (days) {
              setState(() => _selectedDays = days);
              _loadAnalytics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('Last 7 days')),
              const PopupMenuItem(value: 30, child: Text('Last 30 days')),
              const PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAnalytics,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _analytics == null
                  ? const Center(child: Text('No analytics data available'))
                  : RefreshIndicator(
                      onRefresh: _loadAnalytics,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPeriodHeader(),
                            const SizedBox(height: 24),
                            _buildTaskAnalytics(),
                            const SizedBox(height: 24),
                            _buildMessageAnalytics(),
                            const SizedBox(height: 24),
                            _buildCalendarAnalytics(),
                            const SizedBox(height: 24),
                            _buildPhotoAnalytics(),
                            const SizedBox(height: 24),
                            _buildWalletAnalytics(),
                            const SizedBox(height: 24),
                            _buildActivityTrends(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildPeriodHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.insights, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analytics Period',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${_selectedDays} days',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskAnalytics() {
    if (_analytics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Task Analytics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            _buildStatRow('Total Tasks', '${_analytics!.totalTasks}'),
            _buildStatRow('Completed', '${_analytics!.completedTasks}'),
            _buildStatRow('Active', '${_analytics!.activeTasks}'),
            _buildStatRow(
              'Completion Rate',
              '${(_analytics!.taskCompletionRate * 100).toStringAsFixed(1)}%',
            ),
            if (_analytics!.tasksByMember.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Tasks by Member',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._analytics!.tasksByMember.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text('${entry.value} tasks', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageAnalytics() {
    if (_analytics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.message, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Message Analytics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            _buildStatRow('Total Messages', '${_analytics!.totalMessages}'),
            if (_analytics!.messagesByMember.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Messages by Member',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._analytics!.messagesByMember.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text('${entry.value} messages', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarAnalytics() {
    if (_analytics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Calendar Analytics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            _buildStatRow('Total Events', '${_analytics!.totalEvents}'),
            _buildStatRow('Upcoming Events', '${_analytics!.upcomingEvents}'),
            if (_analytics!.eventsByType.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Events by Type',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._analytics!.eventsByType.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text('${entry.value} events', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoAnalytics() {
    if (_analytics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Photo Analytics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            _buildStatRow('Total Photos', '${_analytics!.totalPhotos}'),
            if (_analytics!.photosByMember.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Photos by Member',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._analytics!.photosByMember.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text('${entry.value} photos', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWalletAnalytics() {
    if (_analytics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Wallet Analytics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            _buildStatRow('Total Earned', '\$${_analytics!.totalEarned.toStringAsFixed(2)}'),
            _buildStatRow('Total Spent', '\$${_analytics!.totalSpent.toStringAsFixed(2)}'),
            if (_analytics!.earningsByMember.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Earnings by Member',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._analytics!.earningsByMember.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(
                          '\$${entry.value.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTrends() {
    if (_analytics == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Activity Trends',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            if (_analytics!.dailyActivity.isEmpty && _analytics!.weeklyActivity.isEmpty)
              const Text('No activity trends available yet')
            else ...[
              if (_analytics!.dailyActivity.isNotEmpty) ...[
                Text(
                  'Daily Activity',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ..._analytics!.dailyActivity.entries.take(7).map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key),
                          Text('${entry.value} activities', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
