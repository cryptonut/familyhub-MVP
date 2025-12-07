import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/logger_service.dart';
import '../../models/shopping_list.dart';
import '../../models/user_model.dart';
import '../../services/shopping_service.dart';
import '../../services/auth_service.dart';
import '../../providers/user_data_provider.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/toast_notification.dart';
import '../../utils/app_theme.dart';
import 'shopping_list_detail_screen.dart';
import 'shopping_analytics_screen.dart';
import 'add_edit_shopping_list_dialog.dart';

class ShoppingHomeScreen extends StatefulWidget {
  const ShoppingHomeScreen({super.key});

  @override
  State<ShoppingHomeScreen> createState() => _ShoppingHomeScreenState();
}

class _ShoppingHomeScreenState extends State<ShoppingHomeScreen> {
  final ShoppingService _shoppingService = ShoppingService();
  List<ShoppingList> _lists = [];
  bool _isLoading = true;
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists({bool forceRefresh = false}) async {
    try {
      setState(() => _isLoading = true);
      final lists = await _shoppingService.getShoppingLists(forceRefresh: forceRefresh);
      
      // Load user names for creators
      final userIds = lists.map((l) => l.creatorId).toSet();
      await _loadUserNames(userIds);
      
      if (mounted) {
        setState(() {
          _lists = lists;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      Logger.error('_loadLists error', error: e, stackTrace: st, tag: 'ShoppingHomeScreen');
      if (mounted) {
        setState(() => _isLoading = false);
        ToastNotification.error(context, 'Error loading shopping lists');
      }
    }
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

  Future<void> _createNewList() async {
    final result = await showDialog<ShoppingList>(
      context: context,
      builder: (context) => const AddEditShoppingListDialog(),
    );

    if (result != null) {
      await _loadLists(forceRefresh: true);
      if (mounted) {
        ToastNotification.success(context, 'List "${result.name}" created');
        // Navigate to the new list
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShoppingListDetailScreen(list: result),
          ),
        );
      }
    }
  }

  Future<void> _editList(ShoppingList list) async {
    final result = await showDialog<ShoppingList>(
      context: context,
      builder: (context) => AddEditShoppingListDialog(list: list),
    );

    if (result != null) {
      await _loadLists(forceRefresh: true);
      if (mounted) {
        ToastNotification.success(context, 'List updated');
      }
    }
  }

  Future<void> _deleteList(ShoppingList list) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List?'),
        content: Text('Are you sure you want to delete "${list.name}"? This action cannot be undone.'),
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
        await _shoppingService.deleteShoppingList(list.id);
        await _loadLists(forceRefresh: true);
        if (mounted) {
          ToastNotification.success(context, 'List deleted');
        }
      } catch (e) {
        if (mounted) {
          ToastNotification.error(context, 'Error deleting list: $e');
        }
      }
    }
  }

  Future<void> _setAsDefault(ShoppingList list) async {
    try {
      await _shoppingService.updateShoppingList(list.copyWith(isDefault: true));
      await _loadLists(forceRefresh: true);
      if (mounted) {
        ToastNotification.success(context, '"${list.name}" set as default');
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.error(context, 'Error setting default: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Analytics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ShoppingAnalyticsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _loadLists(forceRefresh: true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
              ? _buildEmptyState()
              : _buildListView(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'shopping-fab',
        onPressed: _createNewList,
        icon: const Icon(Icons.add),
        label: const Text('New List'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.shopping_bag_outlined,
      title: 'No shopping lists yet',
      subtitle: 'Create your first list to start shopping together',
      action: ElevatedButton.icon(
        onPressed: _createNewList,
        icon: const Icon(Icons.add),
        label: const Text('Create List'),
      ),
    );
  }

  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: () => _loadLists(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: _lists.length,
        itemBuilder: (context, index) {
          final list = _lists[index];
          return _buildListCard(list);
        },
      ),
    );
  }

  Widget _buildListCard(ShoppingList list) {
    final theme = Theme.of(context);
    final creatorName = _userNames[list.creatorId] ?? 'Unknown';
    final progress = list.progress;
    
    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShoppingListDetailScreen(list: list),
          ),
        );
        _loadLists(forceRefresh: true);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shopping_cart,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              // Title and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            list.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (list.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Default',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created by $creatorName',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _editList(list);
                      break;
                    case 'default':
                      _setAsDefault(list);
                      break;
                    case 'delete':
                      _deleteList(list);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  if (!list.isDefault)
                    const PopupMenuItem(
                      value: 'default',
                      child: Row(
                        children: [
                          Icon(Icons.star, size: 20),
                          SizedBox(width: 8),
                          Text('Set as Default'),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Progress bar
          if (list.itemCount > 0) ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        list.isCompleted
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Text(
                  '${list.completedItemCount}/${list.itemCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: list.isCompleted
                        ? Colors.green
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'No items yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          // Description if present
          if (list.description != null && list.description!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingS),
            Text(
              list.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Shared with indicator
          if (list.sharedWith.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingS),
            Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Shared with ${list.sharedWith.length} member${list.sharedWith.length > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
