import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/shopping_service.dart';
import '../../services/auth_service.dart';
import '../../models/shopping_list.dart';
import '../../models/smart_recurring_list.dart';
import 'shopping_list_detail_screen.dart';
import 'create_list_dialog.dart';
import 'analytics_dashboard_screen.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final ShoppingService _shoppingService = ShoppingService();
  final AuthService _authService = AuthService();
  List<ShoppingList> _lists = [];
  List<SmartRecurringList> _smartLists = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0 = Lists, 1 = Analytics

  @override
  void initState() {
    super.initState();
    _loadLists();
    _loadSmartLists();
  }

  Future<void> _loadLists() async {
    setState(() => _isLoading = true);
    try {
      final lists = await _shoppingService.getShoppingLists();
      if (mounted) {
        setState(() {
          _lists = lists;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading lists: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSmartLists() async {
    try {
      final smartLists = await _shoppingService.getSmartRecurringLists();
      if (mounted) {
        setState(() {
          _smartLists = smartLists;
        });
      }
    } catch (e) {
      // Silently fail - smart lists are optional
    }
  }

  Future<void> _createNewList() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const CreateListDialog(),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _shoppingService.createShoppingList(result);
        _loadLists();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('List created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating list: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _createFromSmartList(String smartListId) async {
    try {
      await _shoppingService.createListFromSmartRecurring(smartListId);
      _loadLists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('List created from smart list'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteList(ShoppingList list) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Are you sure you want to delete "${list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _shoppingService.deleteShoppingList(list.id);
        _loadLists();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('List deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting list: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shopping Lists'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _createNewList,
              tooltip: 'Create New List',
            ),
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsDashboardScreen(),
                  ),
                );
              },
              tooltip: 'Analytics',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Lists', icon: Icon(Icons.list)),
              Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildListsTab(),
            const AnalyticsDashboardScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildListsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lists.isEmpty && _smartLists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No shopping lists yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _createNewList,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First List'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadLists();
        await _loadSmartLists();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_smartLists.isNotEmpty) ...[
            const Text(
              'Smart Recurring Lists',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._smartLists.map((smartList) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.orange),
                title: Text(smartList.name),
                subtitle: Text('${smartList.itemNames.length} items • Used ${smartList.usageCount} times'),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _createFromSmartList(smartList.id),
                  tooltip: 'Add Smart List',
                ),
              ),
            )),
            const SizedBox(height: 24),
          ],
          const Text(
            'Shopping Lists',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._lists.map((list) => _buildListCard(list)),
        ],
      ),
    );
  }

  Widget _buildListCard(ShoppingList list) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShoppingListDetailScreen(list: list),
            ),
          ).then((_) => _loadLists());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (list.isDefault)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.star, size: 20, color: Colors.amber),
                          ),
                        Expanded(
                          child: Text(
                            list.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.delete, size: 20),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                        onTap: () => Future.delayed(
                          const Duration(milliseconds: 100),
                          () => _deleteList(list),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${list.completedItemCount} / ${list.itemCount} items',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: list.completionPercentage,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            list.isCompleted ? Colors.green : theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (list.isCompleted)
                    Icon(Icons.check_circle, color: Colors.green, size: 32)
                  else
                    Icon(Icons.shopping_cart_outlined, color: theme.primaryColor, size: 32),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
