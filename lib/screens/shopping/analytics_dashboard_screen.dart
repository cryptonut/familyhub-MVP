import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../services/shopping_service.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final ShoppingService _shoppingService = ShoppingService();
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final analytics = await _shoppingService.getAnalytics(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAnalytics();
    }
  }

  Future<void> _exportToCSV() async {
    try {
      final csv = _generateCSV();
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics data copied to clipboard'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Shopping Analytics');
    buffer.writeln('Date Range: ${_startDate?.toString().split(' ')[0] ?? 'All'} - ${_endDate?.toString().split(' ')[0] ?? 'All'}');
    buffer.writeln('');
    buffer.writeln('Total Spending,\$${(_analytics['totalSpending'] as num?)?.toStringAsFixed(2) ?? '0.00'}');
    buffer.writeln('Receipt Count,${_analytics['receiptCount'] ?? 0}');
    buffer.writeln('');
    buffer.writeln('Category Breakdown');
    final categoryBreakdown = _analytics['categoryBreakdown'] as Map<String, dynamic>? ?? {};
    for (final entry in categoryBreakdown.entries) {
      buffer.writeln('${entry.key},\$${(entry.value as num).toStringAsFixed(2)}');
    }
    buffer.writeln('');
    buffer.writeln('Top Items');
    final topItems = _analytics['topItems'] as List<dynamic>? ?? [];
    for (final item in topItems) {
      buffer.writeln('${item['name']},${item['count']}');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCSV,
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    _buildCategoryBreakdown(),
                    const SizedBox(height: 24),
                    _buildTopItems(),
                    const SizedBox(height: 24),
                    _buildMonthlyAverages(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    final totalSpending = (_analytics['totalSpending'] as num?)?.toDouble() ?? 0.0;
    final receiptCount = _analytics['receiptCount'] as int? ?? 0;
    final avgPerReceipt = receiptCount > 0 ? totalSpending / receiptCount : 0.0;

    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Spending',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${totalSpending.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Receipts',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$receiptCount',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Avg/Receipt',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${avgPerReceipt.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown() {
    final categoryBreakdown = _analytics['categoryBreakdown'] as Map<String, dynamic>? ?? {};
    if (categoryBreakdown.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No category data available')),
        ),
      );
    }

    final sorted = categoryBreakdown.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final total = categoryBreakdown.values.fold<double>(
      0.0,
      (sum, value) => sum + (value as num).toDouble(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...sorted.map((entry) {
              final percentage = total > 0
                  ? ((entry.value as num).toDouble() / total * 100)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(
                          '\$${(entry.value as num).toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
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

  Widget _buildTopItems() {
    final topItems = _analytics['topItems'] as List<dynamic>? ?? [];
    if (topItems.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No item data available')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 10 Most Bought Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...topItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text(item['name'] as String? ?? 'Unknown'),
                trailing: Text(
                  '${item['count']} times',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyAverages() {
    final monthlyAverages = _analytics['monthlyAverages'] as List<dynamic>? ?? [];
    if (monthlyAverages.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No monthly data available')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Averages',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...monthlyAverages.map((data) {
              final month = data['month'] as String? ?? '';
              final average = (data['average'] as num?)?.toDouble() ?? 0.0;
              final count = data['count'] as int? ?? 0;
              return ListTile(
                title: Text(month),
                subtitle: Text('$count receipts'),
                trailing: Text(
                  '\$${average.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
