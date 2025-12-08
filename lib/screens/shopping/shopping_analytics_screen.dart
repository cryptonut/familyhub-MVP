import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/logger_service.dart';
import '../../services/shopping_service.dart';
import '../../widgets/toast_notification.dart';
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
  String _selectedPeriod = '30'; // days

  final List<Map<String, dynamic>> _periods = [
    {'label': 'Last 7 Days', 'days': '7'},
    {'label': 'Last 30 Days', 'days': '30'},
    {'label': 'Last 90 Days', 'days': '90'},
    {'label': 'Last Year', 'days': '365'},
    {'label': 'All Time', 'days': 'all'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      DateTime? startDate;
      if (_selectedPeriod != 'all') {
        final days = int.parse(_selectedPeriod);
        startDate = DateTime.now().subtract(Duration(days: days));
      }

      final analytics = await _shoppingService.getSpendingAnalytics(
        startDate: startDate,
        endDate: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      Logger.error('_loadAnalytics error', error: e, stackTrace: st, tag: 'ShoppingAnalyticsScreen');
      if (mounted) {
        setState(() => _isLoading = false);
        ToastNotification.error(context, 'Error loading analytics');
      }
    }
  }

  Future<void> _exportData(String format) async {
    try {
      String content;
      String filename;
      
      if (format == 'csv') {
        content = _generateCsv();
        filename = 'shopping_analytics_${DateTime.now().millisecondsSinceEpoch}.csv';
      } else {
        // Simple text format for now
        content = _generateTextReport();
        filename = 'shopping_analytics_${DateTime.now().millisecondsSinceEpoch}.txt';
      }

      // Write to temporary file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(content);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Shopping Analytics Export',
      );
    } catch (e) {
      Logger.error('Error exporting data', error: e, tag: 'ShoppingAnalyticsScreen');
      if (mounted) {
        ToastNotification.error(context, 'Error exporting data');
      }
    }
  }

  String _generateCsv() {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Shopping Analytics Report');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Period: ${_periods.firstWhere((p) => p['days'] == _selectedPeriod)['label']}');
    buffer.writeln();
    
    // Summary
    buffer.writeln('Summary');
    buffer.writeln('Total Spending,\$${(_analytics['totalSpending'] ?? 0).toStringAsFixed(2)}');
    buffer.writeln('Number of Receipts,${_analytics['receiptCount'] ?? 0}');
    buffer.writeln();
    
    // Top items
    buffer.writeln('Top Items');
    buffer.writeln('Item Name,Purchase Count');
    final topItems = _analytics['topItems'] as List<dynamic>? ?? [];
    for (var item in topItems) {
      buffer.writeln('${item['name']},${item['count']}');
    }
    buffer.writeln();
    
    // Store spending
    buffer.writeln('Spending by Store');
    buffer.writeln('Store,Amount');
    final storeSpending = _analytics['storeSpending'] as Map<String, dynamic>? ?? {};
    for (var entry in storeSpending.entries) {
      buffer.writeln('${entry.key},\$${(entry.value as num).toStringAsFixed(2)}');
    }
    
    return buffer.toString();
  }

  String _generateTextReport() {
    final buffer = StringBuffer();
    
    buffer.writeln('Shopping Analytics Report');
    buffer.writeln('=' * 40);
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Period: ${_periods.firstWhere((p) => p['days'] == _selectedPeriod)['label']}');
    buffer.writeln();
    
    buffer.writeln('Summary');
    buffer.writeln('-' * 20);
    buffer.writeln('Total Spending: \$${(_analytics['totalSpending'] ?? 0).toStringAsFixed(2)}');
    buffer.writeln('Number of Receipts: ${_analytics['receiptCount'] ?? 0}');
    buffer.writeln();
    
    buffer.writeln('Top 10 Most Purchased Items');
    buffer.writeln('-' * 20);
    final topItems = _analytics['topItems'] as List<dynamic>? ?? [];
    for (var i = 0; i < topItems.length; i++) {
      final item = topItems[i];
      buffer.writeln('${i + 1}. ${item['name']} (${item['count']} times)');
    }
    buffer.writeln();
    
    buffer.writeln('Spending by Store');
    buffer.writeln('-' * 20);
    final storeSpending = _analytics['storeSpending'] as Map<String, dynamic>? ?? {};
    for (var entry in storeSpending.entries) {
      buffer.writeln('${entry.key}: \$${(entry.value as num).toStringAsFixed(2)}');
    }
    
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Analytics'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            tooltip: 'Export',
            onSelected: _exportData,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, size: 20),
                    SizedBox(width: 8),
                    Text('Export as CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'txt',
                child: Row(
                  children: [
                    Icon(Icons.description, size: 20),
                    SizedBox(width: 8),
                    Text('Export as Text'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Period selector
          _buildPeriodSelector(),
          // Analytics content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAnalytics,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryCards(),
                          const SizedBox(height: AppTheme.spacingL),
                          _buildSpendingChart(),
                          const SizedBox(height: AppTheme.spacingL),
                          _buildTopItemsCard(),
                          const SizedBox(height: AppTheme.spacingL),
                          _buildStoreBreakdown(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _periods.map((period) {
            final isSelected = period['days'] == _selectedPeriod;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(period['label'] as String),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedPeriod = period['days'] as String);
                    _loadAnalytics();
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalSpending = (_analytics['totalSpending'] as num?)?.toDouble() ?? 0;
    final receiptCount = _analytics['receiptCount'] as int? ?? 0;
    final avgPerReceipt = receiptCount > 0 ? totalSpending / receiptCount : 0.0;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Total Spent',
            value: '\$${totalSpending.toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: _SummaryCard(
            title: 'Receipts',
            value: '$receiptCount',
            icon: Icons.receipt_long,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: _SummaryCard(
            title: 'Avg/Trip',
            value: '\$${avgPerReceipt.toStringAsFixed(2)}',
            icon: Icons.shopping_cart,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingChart() {
    final theme = Theme.of(context);
    
    // Simple spending visualization
    final storeSpending = _analytics['storeSpending'] as Map<String, dynamic>? ?? {};
    if (storeSpending.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              const Text('No spending data available'),
              Text(
                'Upload verified receipts to see analytics',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalSpending = (_analytics['totalSpending'] as num?)?.toDouble() ?? 1;
    final sortedStores = storeSpending.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending by Store',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...sortedStores.take(5).map((entry) {
              final percentage = ((entry.value as num) / totalSpending * 100);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '\$${(entry.value as num).toStringAsFixed(2)} (${percentage.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopItemsCard() {
    final theme = Theme.of(context);
    final topItems = _analytics['topItems'] as List<dynamic>? ?? [];

    if (topItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, size: 20),
                SizedBox(width: 8),
                Text(
                  'Top 10 Most Purchased',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = topItems[index];
                final count = item['count'] as int;
                
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(item['name'] as String),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count×',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreBreakdown() {
    final storeSpending = _analytics['storeSpending'] as Map<String, dynamic>? ?? {};
    
    if (storeSpending.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedStores = storeSpending.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.store, size: 20),
                SizedBox(width: 8),
                Text(
                  'Store Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            DataTable(
              columns: const [
                DataColumn(label: Text('Store')),
                DataColumn(label: Text('Spent'), numeric: true),
              ],
              rows: sortedStores.map((entry) {
                return DataRow(cells: [
                  DataCell(Text(entry.key)),
                  DataCell(Text('\$${(entry.value as num).toStringAsFixed(2)}')),
                ]);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
