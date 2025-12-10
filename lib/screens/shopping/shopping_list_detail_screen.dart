import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt; // Temporarily disabled due to Kotlin compilation errors
import '../../core/services/logger_service.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_item.dart';
import '../../models/shopping_category.dart';
import '../../models/user_model.dart';
import '../../services/shopping_service.dart';
import '../../services/auth_service.dart';
import '../../providers/user_data_provider.dart';
import '../../widgets/toast_notification.dart';
import '../../utils/app_theme.dart';
import 'add_shopping_item_dialog.dart';
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
  final TextEditingController _quickAddController = TextEditingController();
  final FocusNode _quickAddFocusNode = FocusNode();
  
  StreamSubscription<List<ShoppingItem>>? _itemsSubscription;
  List<ShoppingItem> _items = [];
  List<ShoppingCategory> _categories = [];
  Map<String, String> _userNames = {};
  Map<String, List<ShoppingItem>> _groupedItems = {};
  bool _isLoading = true;
  bool _isShopper = false;
  bool _showCompleted = false;
  String? _currentUserId;
  
  // Speech to text - TEMPORARILY DISABLED
  // final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _currentUserId = _authService.currentUser?.uid;
    _isShopper = await _shoppingService.isCurrentUserShopper();
    await _loadCategories();
    _subscribeToItems();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _shoppingService.getCategories();
      if (mounted) {
        setState(() => _categories = categories);
      }
    } catch (e, st) {
      Logger.error('_loadCategories error', error: e, stackTrace: st, tag: 'ShoppingListDetailScreen');
    }
  }

  void _subscribeToItems() {
    _itemsSubscription = _shoppingService.streamShoppingItems(widget.list.id).listen(
      (items) async {
        // Load user names
        final userIds = items.map((i) => i.addedBy).toSet();
        await _loadUserNames(userIds);
        
        if (mounted) {
          setState(() {
            _items = items;
            _groupItems();
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        Logger.error('Items stream error', error: error, tag: 'ShoppingListDetailScreen');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _loadUserNames(Set<String> userIds) async {
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    final familyMembers = userProvider.familyMembers;
    
    for (var userId in userIds) {
      if (!_userNames.containsKey(userId)) {
        final member = familyMembers.firstWhere(
          (m) => m.uid == userId,
          orElse: () => UserModel(
            uid: '',
            email: '',
            displayName: '',
            createdAt: DateTime.now(),
            familyId: '',
          ),
        );
        
        if (member.uid.isNotEmpty) {
          _userNames[userId] = member.displayName.isNotEmpty
              ? member.displayName
              : member.email.split('@').first;
        } else {
          _userNames[userId] = 'Unknown';
        }
      }
    }
  }

  void _groupItems() {
    _groupedItems = {};
    for (var item in _items) {
      // Skip completed items if not showing them
      if (!_showCompleted && item.status != ShoppingItemStatus.pending) {
        continue;
      }
      
      final category = item.categoryName.isNotEmpty ? item.categoryName : 'Other';
      _groupedItems.putIfAbsent(category, () => []);
      _groupedItems[category]!.add(item);
    }
    
    // Sort each category's items
    for (var items in _groupedItems.values) {
      items.sort((a, b) {
        // Pending items first
        if (a.status == ShoppingItemStatus.pending && b.status != ShoppingItemStatus.pending) {
          return -1;
        }
        if (a.status != ShoppingItemStatus.pending && b.status == ShoppingItemStatus.pending) {
          return 1;
        }
        return a.name.compareTo(b.name);
      });
    }
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    _quickAddController.dispose();
    _quickAddFocusNode.dispose();
    super.dispose();
  }

  Future<void> _quickAddItem() async {
    final name = _quickAddController.text.trim();
    if (name.isEmpty) return;

    ShoppingItem? tempItem;
    try {
      final suggestedCategory = _shoppingService.suggestCategory(name);
      final category = _categories.firstWhere(
        (c) => c.id == suggestedCategory,
        orElse: () => _categories.firstWhere(
          (c) => c.id == 'other',
          orElse: () => ShoppingCategory.defaultCategories.last,
        ),
      );

      // Create item optimistically
      tempItem = ShoppingItem(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        listId: widget.list.id,
        name: name,
        categoryId: category.id,
        categoryName: category.name,
        addedBy: _currentUserId ?? '',
        createdAt: DateTime.now(),
      );

      // Optimistically add to UI immediately
      if (mounted) {
        setState(() {
          _items = [tempItem!, ..._items];
          _groupItems();
        });
        _quickAddController.clear();
        _quickAddFocusNode.requestFocus();
      }

      // Actually add to Firestore
      await _shoppingService.addShoppingItem(
        listId: widget.list.id,
        name: name,
        categoryId: category.id,
        categoryName: category.name,
      );

      // Stream will update with the real item - UI already updated optimistically
    } catch (e) {
      // If add failed, remove the optimistic item
      if (mounted && tempItem != null) {
        setState(() {
          _items = _items.where((i) => i.id != tempItem!.id).toList();
          _groupItems();
        });
        ToastNotification.error(context, 'Error adding item: $e');
      }
    }
  }

  Future<void> _addItemWithDialog() async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => AddShoppingItemDialog(
        listId: widget.list.id,
        categories: _categories,
      ),
    );

    if (result != null && mounted) {
      if (result is ShoppingItem) {
        // Optimistically add the new item to the UI immediately
        setState(() {
          _items = [result, ..._items];
          _groupItems();
        });
        ToastNotification.success(context, 'Item added');
      } else if (result == true) {
        // Item was updated (not added)
        ToastNotification.success(context, 'Item updated');
      }
    }
  }

  Future<void> _markItemStatus(ShoppingItem item, ShoppingItemStatus status) async {
    try {
      switch (status) {
        case ShoppingItemStatus.gotIt:
          await _shoppingService.markItemGotIt(widget.list.id, item.id);
          break;
        case ShoppingItemStatus.unavailable:
          await _shoppingService.markItemUnavailable(widget.list.id, item.id);
          break;
        case ShoppingItemStatus.cancelled:
          await _shoppingService.markItemCancelled(widget.list.id, item.id);
          break;
        case ShoppingItemStatus.pending:
          await _shoppingService.resetItemToPending(widget.list.id, item.id);
          break;
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.error(context, 'Error updating item: $e');
      }
    }
  }

  Future<void> _updateQuantity(ShoppingItem item, int delta) async {
    final newQuantity = item.quantity + delta;
    if (newQuantity < 1) {
      // Ask to delete
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Item?'),
          content: Text('Remove "${item.name}" from the list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _shoppingService.deleteShoppingItem(widget.list.id, item.id);
      }
      return;
    }

    try {
      await _shoppingService.updateItemQuantity(widget.list.id, item.id, newQuantity);
    } catch (e) {
      if (mounted) {
        ToastNotification.error(context, 'Error updating quantity: $e');
      }
    }
  }

  Future<void> _createSmartList() async {
    try {
      final smartList = await _shoppingService.createOrUpdateSmartList(
        listId: widget.list.id,
        name: widget.list.name,
        frequency: 'weekly',
      );
      
      if (mounted) {
        ToastNotification.success(
          context,
          'Smart list "${smartList.name}" created! Use it to quickly create future lists.',
        );
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.error(context, 'Error creating smart list: $e');
      }
    }
  }

  Future<void> _clearCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Completed Items?'),
        content: const Text('This will remove all completed items from the list. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final completedItems = _items.where((i) => i.status != ShoppingItemStatus.pending).toList();
        for (var item in completedItems) {
          await _shoppingService.deleteShoppingItem(widget.list.id, item.id);
        }
        if (mounted) {
          ToastNotification.success(context, 'Completed items cleared');
        }
      } catch (e) {
        if (mounted) {
          ToastNotification.error(context, 'Error clearing items: $e');
        }
      }
    }
  }

  Future<void> _editItem(ShoppingItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddShoppingItemDialog(
        listId: widget.list.id,
        categories: _categories,
        item: item, // Pass item for editing
      ),
    );

    if (result == true && mounted) {
      ToastNotification.success(context, 'Item updated');
    }
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _shoppingService.deleteShoppingItem(widget.list.id, item.id);
        if (mounted) {
          ToastNotification.success(context, 'Item deleted');
        }
      } catch (e) {
        if (mounted) {
          ToastNotification.error(context, 'Error deleting item: $e');
        }
      }
    }
  }

  Future<void> _startListening() async {
    // TEMPORARILY DISABLED - speech_to_text Kotlin errors
    ToastNotification.warning(context, 'Speech recognition temporarily disabled');
    return;
    /* DISABLED
    bool available = await _speech.initialize(
      onStatus: (status) {
        Logger.debug('Speech status: $status', tag: 'ShoppingListDetailScreen');
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (error) {
        Logger.error('Speech error: $error', tag: 'ShoppingListDetailScreen');
        if (mounted) {
          setState(() => _isListening = false);
          ToastNotification.error(context, 'Speech recognition error');
        }
      },
    );

    if (available) {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _quickAddController.text = result.recognizedWords;
            setState(() => _isListening = false);
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: true,
      );
    } else {
      if (mounted) {
        ToastNotification.warning(context, 'Speech recognition not available');
      }
    }
    */ // END DISABLED
  }

  void _stopListening() {
    // _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingCount = _items.where((i) => i.status == ShoppingItemStatus.pending).length;
    final completedCount = _items.where((i) => i.status != ShoppingItemStatus.pending).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.list.name),
            Text(
              '$pendingCount pending, $completedCount completed',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showCompleted ? Icons.visibility : Icons.visibility_off),
            tooltip: _showCompleted ? 'Hide Completed' : 'Show Completed',
            onPressed: () {
              setState(() {
                _showCompleted = !_showCompleted;
                _groupItems();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Upload Receipt',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptUploadScreen(listId: widget.list.id),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'create_smart_list':
                  await _createSmartList();
                  break;
                case 'clear_completed':
                  await _clearCompleted();
                  break;
              }
            },
            itemBuilder: (context) {
              final isCompleted = pendingCount == 0 && completedCount > 0;
              return [
                if (isCompleted)
                  const PopupMenuItem(
                    value: 'create_smart_list',
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 20),
                        SizedBox(width: 8),
                        Text('Create Smart List'),
                      ],
                    ),
                  ),
                if (isCompleted)
                  const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'clear_completed',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, size: 20),
                      SizedBox(width: 8),
                      Text('Clear Completed'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick add bar
          _buildQuickAddBar(),
          // Items list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? _buildEmptyState()
                    : _buildGroupedList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'shopping-detail-fab',
        onPressed: _addItemWithDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuickAddBar() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _quickAddController,
              focusNode: _quickAddFocusNode,
              decoration: InputDecoration(
                hintText: 'Add item...',
                prefixIcon: const Icon(Icons.add_shopping_cart),
                suffixIcon: _quickAddController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _quickAddController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _quickAddItem(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // Microphone button
          IconButton.filled(
            onPressed: _isListening ? _stopListening : _startListening,
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            style: IconButton.styleFrom(
              backgroundColor: _isListening ? Colors.red : theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          // Add button
          IconButton.filled(
            onPressed: _quickAddController.text.isNotEmpty ? _quickAddItem : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No items yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items using the field above or tap +',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    final sortedCategories = _groupedItems.keys.toList()
      ..sort((a, b) {
        final catA = _categories.firstWhere(
          (c) => c.name == a,
          orElse: () => ShoppingCategory(
            id: 'other',
            name: a,
            order: 99,
            createdAt: DateTime.now(),
          ),
        );
        final catB = _categories.firstWhere(
          (c) => c.name == b,
          orElse: () => ShoppingCategory(
            id: 'other',
            name: b,
            order: 99,
            createdAt: DateTime.now(),
          ),
        );
        return catA.order.compareTo(catB.order);
      });

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final categoryName = sortedCategories[index];
        final items = _groupedItems[categoryName]!;
        final category = _categories.firstWhere(
          (c) => c.name == categoryName,
          orElse: () => ShoppingCategory(
            id: 'other',
            name: categoryName,
            icon: '📦',
            createdAt: DateTime.now(),
          ),
        );

        return _buildCategorySection(category, items);
      },
    );
  }

  Widget _buildCategorySection(ShoppingCategory category, List<ShoppingItem> items) {
    final theme = Theme.of(context);
    
    return ExpansionTile(
      initiallyExpanded: true,
      leading: Text(
        category.icon ?? '📦',
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(
        category.name,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${items.length}',
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      children: items.map((item) => _buildItemTile(item)).toList(),
    );
  }

  Widget _buildItemTile(ShoppingItem item) {
    final theme = Theme.of(context);
    final addedByName = _userNames[item.addedBy] ?? 'Unknown';
    final isCompleted = item.status != ShoppingItemStatus.pending;
    
    return Dismissible(
      key: Key(item.id),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Got it
          if (_isShopper) {
            await _markItemStatus(item, ShoppingItemStatus.gotIt);
          }
          return false;
        } else {
          // Delete
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Item?'),
              content: Text('Remove "${item.name}" from the list?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ) ?? false;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _shoppingService.deleteShoppingItem(widget.list.id, item.id);
        }
      },
      child: ListTile(
        leading: _buildItemLeading(item),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Quantity controls
                _buildQuantityControls(item),
                const SizedBox(width: 8),
                // Added by
                CircleAvatar(
                  radius: 10,
                  child: Text(
                    addedByName.isNotEmpty ? addedByName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    addedByName,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (item.notes != null && item.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.notes,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: _buildItemActions(item),
        onTap: () {
          _editItem(item);
        },
        onLongPress: () {
          _deleteItem(item);
        },
      ),
    );
  }

  Widget _buildItemLeading(ShoppingItem item) {
    if (item.status == ShoppingItemStatus.pending) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            item.quantityDisplay,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    IconData icon;
    Color color;
    switch (item.status) {
      case ShoppingItemStatus.gotIt:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case ShoppingItemStatus.unavailable:
        icon = Icons.cancel;
        color = Colors.orange;
        break;
      case ShoppingItemStatus.cancelled:
        icon = Icons.remove_circle;
        color = Colors.grey;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Icon(icon, color: color, size: 40);
  }

  Widget _buildQuantityControls(ShoppingItem item) {
    if (item.status != ShoppingItemStatus.pending) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _updateQuantity(item, -1),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.remove, size: 16),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${item.quantity}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        InkWell(
          onTap: () => _updateQuantity(item, 1),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: const Icon(Icons.add, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildItemActions(ShoppingItem item) {
    if (!_isShopper) return const SizedBox.shrink();

    if (item.status != ShoppingItemStatus.pending) {
      // Already actioned - show reset button
      return IconButton(
        icon: const Icon(Icons.undo),
        tooltip: 'Reset to Pending',
        onPressed: () => _markItemStatus(item, ShoppingItemStatus.pending),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Got it button
        IconButton(
          icon: const Icon(Icons.check_circle_outline),
          color: Colors.green,
          tooltip: 'Got It!',
          onPressed: () => _markItemStatus(item, ShoppingItemStatus.gotIt),
        ),
        // Unavailable button
        IconButton(
          icon: const Icon(Icons.cancel_outlined),
          color: Colors.orange,
          tooltip: 'Unavailable',
          onPressed: () => _markItemStatus(item, ShoppingItemStatus.unavailable),
        ),
        // Cancel button
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: Colors.grey,
          tooltip: 'Cancel',
          onPressed: () => _markItemStatus(item, ShoppingItemStatus.cancelled),
        ),
      ],
    );
  }
}
