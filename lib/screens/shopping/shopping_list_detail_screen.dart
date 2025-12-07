import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/shopping_service.dart';
import '../../services/auth_service.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../models/user_model.dart';
import 'add_item_dialog.dart';
import 'item_notes_dialog.dart';
import 'receipt_upload_screen.dart';

class ShoppingListDetailScreen extends StatefulWidget {
  final ShoppingList list;

  const ShoppingListDetailScreen({super.key, required this.list});

  @override
  State<ShoppingListDetailScreen> createState() => _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends State<ShoppingListDetailScreen> {
  final ShoppingService _shoppingService = ShoppingService();
  final AuthService _authService = AuthService();
  List<ShoppingListItem> _items = [];
  Map<String, UserModel> _userCache = {};
  bool _isLoading = true;
  bool _isShopper = false;
  String? _currentUserId;
  Map<String, bool> _expandedCategories = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _checkShopperRole();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkShopperRole() async {
    final userModel = await _authService.getCurrentUserModel();
    setState(() {
      _isShopper = userModel?.isShopper() ?? false;
      _currentUserId = userModel?.uid;
    });
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _shoppingService.getShoppingListItems(widget.list.id);
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
        _loadUserNames();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUserNames() async {
    final userIds = _items.map((item) => item.addedBy).toSet();
    for (final userId in userIds) {
      if (!_userCache.containsKey(userId)) {
        try {
          final userModel = await _authService.getUserModel(userId);
          if (userModel != null && mounted) {
            setState(() {
              _userCache[userId] = userModel;
            });
          }
        } catch (e) {
          // Silently fail
        }
      }
    }
  }

  Future<void> _addItem() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddItemDialog(
        shoppingService: _shoppingService,
        listId: widget.list.id,
      ),
    );

    if (result != null) {
      _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _updateItemStatus(String itemId, ItemStatus status) async {
    try {
      await _shoppingService.updateItemStatus(widget.list.id, itemId, status);
      _loadItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateQuantity(String itemId, int quantity) async {
    if (quantity < 1) {
      _deleteItem(itemId);
      return;
    }
    try {
      await _shoppingService.updateItemQuantity(widget.list.id, itemId, quantity);
      _loadItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating quantity: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await _shoppingService.deleteItem(widget.list.id, itemId);
      _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editItem(ShoppingListItem item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddItemDialog(
        shoppingService: _shoppingService,
        listId: widget.list.id,
        existingItem: item,
      ),
    );

    if (result != null) {
      _loadItems();
    }
  }

  Future<void> _showItemNotes(ShoppingListItem item) async {
    await showDialog(
      context: context,
      builder: (context) => ItemNotesDialog(
        item: item,
        shoppingService: _shoppingService,
      ),
    );
    _loadItems();
  }

  Map<String, List<ShoppingListItem>> _groupByCategory() {
    final filtered = _items.where((item) {
      if (_searchQuery.isEmpty) return true;
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final grouped = <String, List<ShoppingListItem>>{};
    for (final item in filtered) {
      final category = item.category ?? 'Uncategorized';
      grouped.putIfAbsent(category, () => []).add(item);
    }
    return grouped;
  }

  Widget _buildItemRow(ShoppingListItem item) {
    final theme = Theme.of(context);
    final addedByUser = _userCache[item.addedBy];
    final isCompleted = item.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isCompleted ? Colors.grey[100] : null,
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: theme.primaryColor.withOpacity(0.2),
          child: Text(
            addedByUser?.displayName[0].toUpperCase() ?? '?',
            style: TextStyle(
              fontSize: 12,
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted ? Colors.grey[600] : null,
                ),
              ),
            ),
            if (item.notes != null || item.attachmentUrls.isNotEmpty)
              IconButton(
                icon: Icon(
                  item.attachmentUrls.isNotEmpty ? Icons.attachment : Icons.note,
                  size: 20,
                  color: Colors.grey[600],
                ),
                onPressed: () => _showItemNotes(item),
                tooltip: 'Notes/Attachments',
              ),
          ],
        ),
        subtitle: Row(
          children: [
            // Quantity controls
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: () => _updateQuantity(item.id, item.quantity - 1),
              tooltip: 'Decrease quantity',
            ),
            Text(
              '${item.quantity}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => _updateQuantity(item.id, item.quantity + 1),
              tooltip: 'Increase quantity',
            ),
            if (item.category != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.category!,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: _isShopper && !widget.list.isCompleted
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.check_circle,
                      color: item.status == ItemStatus.gotIt ? Colors.green : Colors.grey,
                    ),
                    onPressed: () => _updateItemStatus(item.id, ItemStatus.gotIt),
                    tooltip: 'Got It',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.cancel,
                      color: item.status == ItemStatus.unavailable ? Colors.orange : Colors.grey,
                    ),
                    onPressed: () => _updateItemStatus(item.id, ItemStatus.unavailable),
                    tooltip: 'Unavailable',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: item.status == ItemStatus.cancelled ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => _updateItemStatus(item.id, ItemStatus.cancelled),
                    tooltip: 'Cancelled',
                  ),
                ],
              )
            : null,
        onTap: () => _editItem(item),
        onLongPress: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(item.name),
              content: const Text('Delete this item?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteItem(item.id);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCategory();
    final categories = grouped.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.list.name),
        actions: [
          if (widget.list.isCompleted)
            IconButton(
              icon: const Icon(Icons.receipt),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceiptUploadScreen(list: widget.list),
                  ),
                );
              },
              tooltip: 'Upload Receipt',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Progress indicator
          if (!widget.list.isCompleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: widget.list.completionPercentage,
                      backgroundColor: Colors.grey[200],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.list.completedItemCount}/${widget.list.itemCount}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          // Items list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : grouped.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'No items yet' : 'No items found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            if (_searchQuery.isEmpty)
                              ElevatedButton.icon(
                                onPressed: _addItem,
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Item'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final items = grouped[category]!;
                          final isExpanded = _expandedCategories[category] ?? true;

                          return ExpansionTile(
                            initiallyExpanded: isExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _expandedCategories[category] = expanded;
                              });
                            },
                            title: Row(
                              children: [
                                Text(
                                  category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${items.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            children: items.map((item) => _buildItemRow(item)).toList(),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.list.isCompleted
          ? null
          : FloatingActionButton.extended(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
    );
  }
}
