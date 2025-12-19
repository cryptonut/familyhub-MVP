import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/navigation_order_service.dart';
import '../../core/services/logger_service.dart';

class ReorderNavigationScreen extends StatefulWidget {
  const ReorderNavigationScreen({super.key});

  @override
  State<ReorderNavigationScreen> createState() => _ReorderNavigationScreenState();
}

class _ReorderNavigationScreenState extends State<ReorderNavigationScreen> {
  final _navigationOrderService = NavigationOrderService();
  List<int> _order = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  // Navigation item definitions
  final List<NavigationItem> _items = [
    NavigationItem(index: 0, label: 'Home', icon: Icons.home, isLocked: true),
    NavigationItem(index: 1, label: 'Calendar', icon: Icons.calendar_today),
    NavigationItem(index: 2, label: 'Jobs', icon: Icons.task),
    NavigationItem(index: 3, label: 'Games', icon: Icons.sports_esports),
    NavigationItem(index: 4, label: 'Photos', icon: Icons.photo_library),
    NavigationItem(index: 5, label: 'Shopping', icon: Icons.shopping_bag),
    NavigationItem(index: 6, label: 'Location', icon: Icons.location_on),
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final order = await _navigationOrderService.getNavigationOrder();
      setState(() {
        _order = order;
        _isLoading = false;
        _hasChanges = false;
      });
    } catch (e) {
      Logger.error('Error loading navigation order', error: e, tag: 'ReorderNavigationScreen');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading navigation order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveOrder() async {
    try {
      await _navigationOrderService.saveNavigationOrder(_order);
      if (mounted) {
        setState(() {
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigation order saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Show message that app restart may be needed
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please restart the app for changes to take effect'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        });
      }
    } catch (e) {
      Logger.error('Error saving navigation order', error: e, tag: 'ReorderNavigationScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Default'),
        content: const Text('Are you sure you want to reset the navigation order to default?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _navigationOrderService.resetToDefault();
        await _loadOrder();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Navigation order reset to default'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        Logger.error('Error resetting navigation order', error: e, tag: 'ReorderNavigationScreen');
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    // Home is always at position 0, so we skip it in the reorderable list
    // oldIndex and newIndex are 0-based in the displayed list (Home is shown but not reorderable)
    // We need to map these to positions 1-6 in the _order array
    
    // Skip Home (index 0) - adjust indices
    final oldOrderIndex = oldIndex; // Already accounts for Home being first
    final newOrderIndex = newIndex; // Already accounts for Home being first
    
    // Validate indices (should be 1-6, not 0)
    if (oldOrderIndex < 1 || oldOrderIndex > 6 || newOrderIndex < 1 || newOrderIndex > 6) {
      return; // Invalid reorder
    }
    
    setState(() {
      // Reorder the items (excluding Home which is at index 0)
      final item = _order.removeAt(oldOrderIndex);
      _order.insert(newOrderIndex, item);
      _hasChanges = true;
    });
  }

  List<NavigationItem> get _orderedItems {
    // Return items in the current order (Home is always first)
    final ordered = <NavigationItem>[];
    for (int i = 0; i < _order.length; i++) {
      final screenIndex = _order[i];
      ordered.add(_items[screenIndex]);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Navigation'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveOrder,
              child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToDefault,
            tooltip: 'Reset to default',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Text(
                    'Long press and drag to reorder. Home is locked to the first position.',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ReorderableListView(
                    padding: const EdgeInsets.all(16),
                    onReorder: _onReorder,
                    children: _orderedItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      
                      return _buildReorderableItem(item, index);
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildReorderableItem(NavigationItem item, int displayIndex) {
    return Card(
      key: ValueKey(item.index),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: item.isLocked
            ? Icon(Icons.lock, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))
            : Icon(Icons.drag_handle, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        title: Text(item.label),
        trailing: item.isLocked
            ? const Chip(
                label: Text('Locked'),
                labelStyle: TextStyle(fontSize: 10),
              )
            : Icon(Icons.reorder, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        enabled: !item.isLocked,
      ),
    );
  }
}

class NavigationItem {
  final int index;
  final String label;
  final IconData icon;
  final bool isLocked;

  NavigationItem({
    required this.index,
    required this.label,
    required this.icon,
    this.isLocked = false,
  });
}

