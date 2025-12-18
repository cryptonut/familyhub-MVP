import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/logger_service.dart';
import '../../services/shopping_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

class ShoppingAnalyticsScreen extends StatefulWidget {
  const ShoppingAnalyticsScreen({super.key});

  @override
  State<ShoppingAnalyticsScreen> createState() => _ShoppingAnalyticsScreenState();
}

class _ShoppingAnalyticsScreenState extends State<ShoppingAnalyticsScreen> {
  final ShoppingService _shoppingService = ShoppingService();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic> _analytics = {};
  int _selectedDays = 30;
  Map<String, String> _memberNames = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      // Load member names for display
      final members = await _authService.getFamilyMembers();
      _memberNames = {
        for (var member in members)
          member.uid: member.displayName ?? member.email ?? 'Unknown'
      };

      // Load analytics
      _analytics = await _shoppingService.getShoppingAnalytics(days: _selectedDays);
    } catch (e, st) {
      Logger.error('Error loading analytics', error: e, stackTrace: st, tag: 'ShoppingAnalyticsScreen');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analytics.isEmpty
              ? Center(
                  child: Text(
                    'No shopping data available',
                    style: theme.textTheme.bodyLarge,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20), // Increased padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary cards - expanded layout
                        _buildSummaryCards(),
                        const SizedBox(height: 32), // Increased spacing
                        // Category breakdown - expanded
                        _buildCategoryBreakdown(),
                        const SizedBox(height: 32),
                        // Member activity - expanded
                        _buildMemberActivity(),
                        const SizedBox(height: 32),
                        // Top items - expanded
                        _buildTopItems(),
                        const SizedBox(height: 32),
                        // Trends - expanded
                        _buildTrends(),
                        const SizedBox(height: 16), // Bottom padding
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryCards() {
    final totalItems = _analytics['totalItems'] as int? ?? 0;
    final purchasedItems = _analytics['purchasedItems'] as int? ?? 0;
    final pendingItems = _analytics['pendingItems'] as int? ?? 0;
    final completionRate = _analytics['completionRate'] as double? ?? 0.0;

    // Expanded grid layout - 2x2 for better visibility
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Items',
                totalItems.toString(),
                Icons.shopping_cart,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16), // Increased spacing
            Expanded(
              child: _buildStatCard(
                'Purchased',
                purchasedItems.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Pending',
                pendingItems.toString(),
                Icons.pending,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Completion',
                '${(completionRate * 100).toStringAsFixed(0)}%',
                Icons.trending_up,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2, // Subtle elevation
      child: Padding(
        padding: const EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28), // Larger icon
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32, // Larger value
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14, // Slightly larger label
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final itemsByCategory = _analytics['itemsByCategory'] as Map<String, dynamic>? ?? {};
    
    if (itemsByCategory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Items by Category',
                  style: TextStyle(
                    fontSize: 20, // Larger title
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20), // Increased spacing
            ...itemsByCategory.entries.map((entry) {
              final total = itemsByCategory.values.reduce((a, b) => (a as int) + (b as int)) as int;
              final percentage = total > 0 ? (entry.value as int) / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text('${entry.value} (${(percentage * 100).toStringAsFixed(0)}%)'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberActivity() {
    final itemsByMember = _analytics['itemsByMember'] as Map<String, dynamic>? ?? {};
    
    if (itemsByMember.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Activity by Member',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...itemsByMember.entries.map((entry) {
              final memberName = _memberNames[entry.key] ?? entry.key;
              return ListTile(
                leading: CircleAvatar(
                  child: Text(memberName[0].toUpperCase()),
                ),
                title: Text(memberName),
                trailing: Text(
                  '${entry.value} items',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopItems() {
    final topItems = _analytics['topItems'] as List<dynamic>? ?? [];
    
    if (topItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Most Purchased Items',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...topItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text('${index + 1}'),
                ),
                title: Text(
                  item['name'].toString().split(' ').map((word) => 
                    word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
                  ).join(' '),
                ),
                trailing: Text(
                  '${item['count']}x',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrends() {
    final itemsByDay = _analytics['itemsByDay'] as Map<String, dynamic>? ?? {};
    final recurringCount = _analytics['recurringItemsCount'] as int? ?? 0;
    
    if (itemsByDay.isEmpty && recurringCount == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Trends & Insights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (recurringCount > 0)
              ListTile(
                leading: const Icon(Icons.repeat, color: Colors.purple),
                title: const Text('Recurring Items'),
                trailing: Text(
                  '$recurringCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            if (itemsByDay.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Items Added Over Time',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...itemsByDay.entries.take(7).map((entry) {
                final date = DateTime.tryParse(entry.key) ?? DateTime.now();
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.calendar_today, size: 16),
                  title: Text(DateFormat('MMM d').format(date)),
                  trailing: Text('${entry.value} items'),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}

