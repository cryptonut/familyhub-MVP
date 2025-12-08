import 'package:flutter/material.dart';
import '../../services/shopping_service.dart';
import '../../widgets/toast_notification.dart';
import '../../core/services/logger_service.dart';
import '../../utils/app_theme.dart';

class ShoppingAnalyticsScreen extends StatefulWidget {
  const ShoppingAnalyticsScreen({super.key});

  @override
  State<ShoppingAnalyticsScreen> createState() => _ShoppingAnalyticsScreenState();
}

class _ShoppingAnalyticsScreenState extends State<ShoppingAnalyticsScreen> {
  final ShoppingService _shoppingService = ShoppingService();
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() => _isLoading = true);
      final analytics = await _shoppingService.getSpendingAnalytics();
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      Logger.error('Error loading analytics', error: e, stackTrace: st, tag: 'ShoppingAnalyticsScreen');
      if (mounted) {
        setState(() => _isLoading = false);
        ToastNotification.error(context, 'Error loading analytics: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analytics.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No analytics data yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload receipts to see spending analytics',
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  child: ListView(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    children: [
                      // Total Spending Card
                      if (_analytics['totalSpending'] != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Spending',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '\$${(_analytics['totalSpending'] as num).toStringAsFixed(2)}',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                if (_analytics['receiptCount'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '${_analytics['receiptCount']} receipt${(_analytics['receiptCount'] as int) != 1 ? 's' : ''}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Top Items
                      if (_analytics['topItems'] != null && (_analytics['topItems'] as List).isNotEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Most Purchased Items',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 16),
                                ...((_analytics['topItems'] as List).map((item) {
                                  return ListTile(
                                    leading: const Icon(Icons.shopping_basket),
                                    title: Text(item['name'] as String? ?? 'Unknown'),
                                    trailing: Text(
                                      '${item['count']}x',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                })),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
