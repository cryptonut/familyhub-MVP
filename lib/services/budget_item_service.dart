import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/budget_item.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'budget_service.dart';

/// Service for managing budget items
class BudgetItemService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  String? _cachedFamilyId;

  Future<String?> get _familyId async {
    final userModel = await _authService.getCurrentUserModel();
    final freshFamilyId = userModel?.familyId;
    if (_cachedFamilyId != freshFamilyId) {
      Logger.debug('_familyId: FamilyId changed from $_cachedFamilyId to $freshFamilyId', tag: 'BudgetItemService');
      _cachedFamilyId = freshFamilyId;
    }
    return _cachedFamilyId;
  }

  void clearFamilyIdCache() {
    Logger.debug('clearFamilyIdCache: Clearing cached familyId', tag: 'BudgetItemService');
    _cachedFamilyId = null;
  }

  /// Get all items for a budget
  Future<List<BudgetItem>> getItems(String budgetId, {String? parentItemId}) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getItems: User not part of a family', tag: 'BudgetItemService');
      return [];
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/items');
      Query query = _firestore.collection(collectionPath);

      if (parentItemId != null) {
        query = query.where('parentItemId', isEqualTo: parentItemId);
      } else {
        // For top-level items, we need to handle both null and missing parentItemId
        // Firestore treats missing fields differently than null, so we query for null explicitly
        // and also check if the field doesn't exist
        query = query.where('parentItemId', isNull: true);
      }

      query = query.orderBy('order', descending: false);

      final snapshot = await query.get();
      Logger.debug('getItems: Query returned ${snapshot.docs.length} documents', tag: 'BudgetItemService');
      
      final items = snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          Logger.debug('getItems: Parsing item ${doc.id}, parentItemId: ${data['parentItemId']}', tag: 'BudgetItemService');
          return BudgetItem.fromJson({
            'id': doc.id,
            ...data,
          });
        } catch (e) {
          Logger.warning('Error parsing budget item ${doc.id}', error: e, tag: 'BudgetItemService');
          return null;
        }
      }).whereType<BudgetItem>().toList();

      Logger.debug('getItems: Loaded ${items.length} items for budget $budgetId', tag: 'BudgetItemService');
      return items;
    } catch (e, stackTrace) {
      // If the query fails (e.g., index not ready), fallback to loading all and filtering
      if (e.toString().contains('index') || e.toString().contains('failed-precondition')) {
        Logger.warning('getItems: Index may not be ready, falling back to in-memory filter', tag: 'BudgetItemService');
        try {
          final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/items');
          final snapshot = await _firestore.collection(collectionPath).get();
          List<BudgetItem> allItems = snapshot.docs.map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return BudgetItem.fromJson({
                'id': doc.id,
                ...data,
              });
            } catch (e) {
              Logger.warning('Error parsing budget item ${doc.id} during fallback', error: e, tag: 'BudgetItemService');
              return null;
            }
          }).whereType<BudgetItem>().toList();

          // Filter in memory
          if (parentItemId != null) {
            allItems = allItems.where((i) => i.parentItemId == parentItemId).toList();
          } else {
            // Top-level items: parentItemId is null or missing
            allItems = allItems.where((i) => i.parentItemId == null).toList();
          }

          // Sort by order
          allItems.sort((a, b) => a.order.compareTo(b.order));

          Logger.debug('getItems: Loaded ${allItems.length} items via fallback', tag: 'BudgetItemService');
          return allItems;
        } catch (fallbackError) {
          Logger.error('getItems fallback error', error: fallbackError, tag: 'BudgetItemService');
          return [];
        }
      }
      Logger.error('getItems error', error: e, stackTrace: stackTrace, tag: 'BudgetItemService');
      return [];
    }
  }

  /// Get a single item by ID
  Future<BudgetItem?> getItem(String budgetId, String itemId) async {
    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/items');
      final doc = await _firestore.collection(collectionPath).doc(itemId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      return BudgetItem.fromJson({
        'id': doc.id,
        ...data,
      });
    } catch (e, stackTrace) {
      Logger.error('getItem error', error: e, stackTrace: stackTrace, tag: 'BudgetItemService');
      rethrow;
    }
  }

  /// Create a new budget item
  Future<BudgetItem> createItem({
    required String budgetId,
    required String name,
    String description = '',
    required double estimatedAmount,
    String? parentItemId,
    int? order,
    double? adherenceThreshold,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final itemId = _uuid.v4();
      final now = DateTime.now();

      // Get next order if not provided
      int itemOrder = order ?? 0;
      if (order == null) {
        final existingItems = await getItems(budgetId, parentItemId: parentItemId);
        itemOrder = existingItems.isEmpty ? 0 : existingItems.map((i) => i.order).reduce((a, b) => a > b ? a : b) + 1;
      }

      // Get budget to inherit adherence threshold if not provided
      final budgetService = BudgetService();
      final budget = await budgetService.getBudget(budgetId);
      if (budget == null) {
        throw NotFoundException('Budget not found', code: 'budget-not-found');
      }

      final item = BudgetItem(
        id: itemId,
        budgetId: budgetId,
        name: name,
        description: description,
        estimatedAmount: estimatedAmount,
        parentItemId: parentItemId, // null for top-level items, which is what we want
        order: itemOrder,
        adherenceThreshold: adherenceThreshold ?? budget.adherenceThreshold,
        createdBy: currentUserId,
        createdAt: now,
      );

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/items');
      await _firestore.collection(collectionPath).doc(itemId).set(item.toJson());

      // Update parent item's subItemIds if this is a sub-item
      if (parentItemId != null) {
        final parentItem = await getItem(budgetId, parentItemId);
        if (parentItem != null) {
          final updatedSubItemIds = [...parentItem.subItemIds, itemId];
          await updateItem(budgetId, parentItem.copyWith(
            subItemIds: updatedSubItemIds,
            updatedAt: now,
          ));
        }
      }

      // Update budget item count
      await _updateBudgetItemCount(budgetId);

      Logger.debug('createItem: Created item $itemId', tag: 'BudgetItemService');
      return item;
    } catch (e, stackTrace) {
      Logger.error('createItem error', error: e, stackTrace: stackTrace, tag: 'BudgetItemService');
      rethrow;
    }
  }

  /// Update an existing item
  Future<BudgetItem> updateItem(String budgetId, BudgetItem item) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final updatedItem = item.copyWith(updatedAt: DateTime.now());
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/items');
      await _firestore.collection(collectionPath).doc(item.id).set(updatedItem.toJson(), SetOptions(merge: true));

      // If status changed to complete, check if parent should be updated
      if (updatedItem.status == BudgetItemStatus.complete && item.status != BudgetItemStatus.complete) {
        await _checkAndUpdateParentItem(budgetId, item);
        await _updateBudgetItemCount(budgetId);
      }

      Logger.debug('updateItem: Updated item ${item.id}', tag: 'BudgetItemService');
      return updatedItem;
    } catch (e, stackTrace) {
      Logger.error('updateItem error', error: e, stackTrace: stackTrace, tag: 'BudgetItemService');
      rethrow;
    }
  }

  /// Complete an item (user-attested actual cost)
  Future<BudgetItem> completeItem({
    required String budgetId,
    required String itemId,
    required double actualAmount,
    String? receiptUrl,
    String? receiptId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final item = await getItem(budgetId, itemId);
    if (item == null) {
      throw NotFoundException('Item not found', code: 'item-not-found');
    }

    // Check if all sub-items are complete
    if (item.hasSubItems) {
      final subItems = await getItems(budgetId, parentItemId: itemId);
      final incompleteSubItems = subItems.where((si) => si.status != BudgetItemStatus.complete).toList();
      if (incompleteSubItems.isNotEmpty) {
        throw ValidationException(
          'Cannot complete item: ${incompleteSubItems.length} sub-item(s) not yet complete',
          code: 'sub-items-incomplete',
        );
      }
    }

    final completedItem = item.copyWith(
      actualAmount: actualAmount,
      status: BudgetItemStatus.complete,
      receiptUrl: receiptUrl,
      receiptId: receiptId,
      completedAt: DateTime.now(),
      completedBy: currentUserId,
      updatedAt: DateTime.now(),
    );

    await updateItem(budgetId, completedItem);
    await _checkAndUpdateParentItem(budgetId, item);
    await _updateBudgetItemCount(budgetId);

    return completedItem;
  }

  /// Reopen a completed item
  Future<BudgetItem> reopenItem(String budgetId, String itemId) async {
    final item = await getItem(budgetId, itemId);
    if (item == null) {
      throw NotFoundException('Item not found', code: 'item-not-found');
    }

    if (item.status != BudgetItemStatus.complete) {
      throw ValidationException('Item is not complete', code: 'item-not-complete');
    }

    // Check if parent item is complete (can't reopen if parent is complete)
    if (item.parentItemId != null) {
      final parentItem = await getItem(budgetId, item.parentItemId!);
      if (parentItem?.status == BudgetItemStatus.complete) {
        throw ValidationException('Cannot reopen: parent item is complete', code: 'parent-complete');
      }
    }

    final reopenedItem = item.copyWith(
      status: BudgetItemStatus.pending,
      completedAt: null,
      completedBy: null,
      updatedAt: DateTime.now(),
    );

    await updateItem(budgetId, reopenedItem);
    await _checkAndUpdateParentItem(budgetId, item);
    await _updateBudgetItemCount(budgetId);

    return reopenedItem;
  }

  /// Delete an item
  Future<void> deleteItem(String budgetId, String itemId) async {
    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final item = await getItem(budgetId, itemId);
      if (item == null) {
        throw NotFoundException('Item not found', code: 'item-not-found');
      }

      // Check if item has sub-items
      if (item.hasSubItems) {
        throw ValidationException('Cannot delete item: has sub-items. Delete sub-items first.', code: 'has-sub-items');
      }

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/items');
      await _firestore.collection(collectionPath).doc(itemId).delete();

      // Remove from parent's subItemIds if it was a sub-item
      if (item.parentItemId != null) {
        final parentItem = await getItem(budgetId, item.parentItemId!);
        if (parentItem != null) {
          final updatedSubItemIds = parentItem.subItemIds.where((id) => id != itemId).toList();
          await updateItem(budgetId, parentItem.copyWith(
            subItemIds: updatedSubItemIds,
            updatedAt: DateTime.now(),
          ));
        }
      }

      // Update budget item count
      await _updateBudgetItemCount(budgetId);

      Logger.debug('deleteItem: Deleted item $itemId', tag: 'BudgetItemService');
    } catch (e, stackTrace) {
      Logger.error('deleteItem error', error: e, stackTrace: stackTrace, tag: 'BudgetItemService');
      rethrow;
    }
  }

  /// Reorder items
  Future<void> reorderItems(String budgetId, List<String> itemIds) async {
    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/items');
      final batch = _firestore.batch();

      for (int i = 0; i < itemIds.length; i++) {
        final itemRef = _firestore.collection(collectionPath).doc(itemIds[i]);
        batch.update(itemRef, {'order': i, 'updatedAt': Timestamp.now()});
      }

      await batch.commit();
      Logger.debug('reorderItems: Reordered ${itemIds.length} items', tag: 'BudgetItemService');
    } catch (e, stackTrace) {
      Logger.error('reorderItems error', error: e, stackTrace: stackTrace, tag: 'BudgetItemService');
      rethrow;
    }
  }

  /// Check and update parent item status based on sub-items
  Future<void> _checkAndUpdateParentItem(String budgetId, BudgetItem item) async {
    if (item.parentItemId == null) return;

    final parentItem = await getItem(budgetId, item.parentItemId!);
    if (parentItem == null) return;

    final subItems = await getItems(budgetId, parentItemId: item.parentItemId);
    final allComplete = subItems.every((si) => si.status == BudgetItemStatus.complete);
    final anyComplete = subItems.any((si) => si.status == BudgetItemStatus.complete);

    BudgetItemStatus newStatus;
    if (allComplete) {
      newStatus = BudgetItemStatus.complete;
    } else if (anyComplete) {
      newStatus = BudgetItemStatus.inProgress;
    } else {
      newStatus = BudgetItemStatus.pending;
    }

    if (parentItem.status != newStatus) {
      await updateItem(budgetId, parentItem.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      ));
    }
  }

  /// Update budget item count (denormalized)
  Future<void> _updateBudgetItemCount(String budgetId) async {
    final familyId = await _familyId;
    if (familyId == null) return;

    try {
      final allItems = await getItems(budgetId);
      final completedItems = allItems.where((i) => i.status == BudgetItemStatus.complete).toList();

      final budgetPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets');
      await _firestore.collection(budgetPath).doc(budgetId).update({
        'itemCount': allItems.length,
        'completedItemCount': completedItems.length,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      Logger.warning('_updateBudgetItemCount error', error: e, tag: 'BudgetItemService');
    }
  }
}

