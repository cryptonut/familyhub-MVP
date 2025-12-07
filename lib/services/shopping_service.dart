import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_item.dart';
import '../models/receipt.dart';
import '../models/smart_recurring_list.dart';
import 'auth_service.dart';

class ShoppingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService = AuthService();

  String? _cachedFamilyId;

  Future<String?> get _familyId async {
    final userModel = await _authService.getCurrentUserModel();
    final freshFamilyId = userModel?.familyId;
    if (_cachedFamilyId != freshFamilyId) {
      Logger.debug('_familyId: FamilyId changed from $_cachedFamilyId to $freshFamilyId', tag: 'ShoppingService');
      _cachedFamilyId = freshFamilyId;
    }
    return _cachedFamilyId;
  }

  void clearFamilyIdCache() {
    _cachedFamilyId = null;
  }

  // ========== Shopping Lists ==========

  Future<List<ShoppingList>> getShoppingLists() async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getShoppingLists: User not part of a family', tag: 'ShoppingService');
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('families/$familyId/shoppingLists')
          .orderBy('isDefault', descending: true)
          .orderBy('createdAt', descending: true)
          .get();

      final lists = snapshot.docs
          .map((doc) => ShoppingList.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      Logger.debug('getShoppingLists: Loaded ${lists.length} lists', tag: 'ShoppingService');
      return lists;
    } catch (e, st) {
      Logger.error('getShoppingLists error', error: e, stackTrace: st, tag: 'ShoppingService');
      return [];
    }
  }

  Stream<List<ShoppingList>> getShoppingListsStream() {
    return Stream.fromFuture(_familyId).asyncExpand((familyId) {
      if (familyId == null) {
        return Stream.value(<ShoppingList>[]);
      }

      return _firestore
          .collection('families/$familyId/shoppingLists')
          .orderBy('isDefault', descending: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ShoppingList.fromJson({'id': doc.id, ...doc.data()}))
              .toList());
    });
  }

  Future<ShoppingList> createShoppingList(String name, {bool isDefault = false}) async {
    final familyId = await _familyId;
    final userId = _auth.currentUser?.uid;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    if (userId == null) throw AuthException('User not authenticated', code: 'not-authenticated');

    try {
      // If this is set as default, unset other defaults
      if (isDefault) {
        await _unsetOtherDefaults(familyId);
      }

      final list = ShoppingList(
        id: _firestore.collection('families/$familyId/shoppingLists').doc().id,
        name: name,
        familyId: familyId,
        createdBy: userId,
        createdAt: DateTime.now(),
        isDefault: isDefault,
        sharedWith: {userId: true}, // Creator is automatically shared
      );

      final data = list.toJson();
      data.remove('id');

      await _firestore
          .collection('families/$familyId/shoppingLists')
          .doc(list.id)
          .set(data);

      Logger.info('createShoppingList: Created list ${list.id}', tag: 'ShoppingService');
      return list;
    } catch (e, st) {
      Logger.error('createShoppingList error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<void> _unsetOtherDefaults(String familyId) async {
    final snapshot = await _firestore
        .collection('families/$familyId/shoppingLists')
        .where('isDefault', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isDefault': false});
    }
    await batch.commit();
  }

  Future<void> updateShoppingList(ShoppingList list) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    try {
      // If setting as default, unset others
      if (list.isDefault) {
        await _unsetOtherDefaults(familyId);
      }

      final data = list.toJson();
      data.remove('id');

      await _firestore
          .collection('families/$familyId/shoppingLists')
          .doc(list.id)
          .update(data);

      Logger.info('updateShoppingList: Updated list ${list.id}', tag: 'ShoppingService');
    } catch (e, st) {
      Logger.error('updateShoppingList error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<void> deleteShoppingList(String listId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    try {
      // Delete all items first
      final itemsSnapshot = await _firestore
          .collection('families/$familyId/shoppingLists/$listId/items')
          .get();

      final batch = _firestore.batch();
      for (var doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete the list
      await _firestore
          .collection('families/$familyId/shoppingLists')
          .doc(listId)
          .delete();

      Logger.info('deleteShoppingList: Deleted list $listId', tag: 'ShoppingService');
    } catch (e, st) {
      Logger.error('deleteShoppingList error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<void> shareListWithUser(String listId, String userId, bool share) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    try {
      final listRef = _firestore
          .collection('families/$familyId/shoppingLists')
          .doc(listId);

      if (share) {
        await listRef.set({
          'sharedWith.$userId': true,
        }, SetOptions(merge: true));
      } else {
        await listRef.set({
          'sharedWith.$userId': FieldValue.delete(),
        }, SetOptions(merge: true));
      }

      Logger.info('shareListWithUser: ${share ? "Shared" : "Unshared"} list $listId with $userId', tag: 'ShoppingService');
    } catch (e, st) {
      Logger.error('shareListWithUser error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  // ========== Shopping List Items ==========

  Future<List<ShoppingListItem>> getShoppingListItems(String listId) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getShoppingListItems: User not part of a family', tag: 'ShoppingService');
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('families/$familyId/shoppingLists/$listId/items')
          .orderBy('orderIndex')
          .orderBy('createdAt')
          .get();

      final items = snapshot.docs
          .map((doc) => ShoppingListItem.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      Logger.debug('getShoppingListItems: Loaded ${items.length} items', tag: 'ShoppingService');
      return items;
    } catch (e, st) {
      Logger.warning('getShoppingListItems: orderBy failed, trying without', error: e, stackTrace: st, tag: 'ShoppingService');
      // Fallback without orderBy
      try {
        final snapshot = await _firestore
            .collection('families/$familyId/shoppingLists/$listId/items')
            .get();

        final items = snapshot.docs
            .map((doc) => ShoppingListItem.fromJson({'id': doc.id, ...doc.data()}))
            .toList();

        items.sort((a, b) {
          if (a.orderIndex != null && b.orderIndex != null) {
            return a.orderIndex!.compareTo(b.orderIndex!);
          }
          return a.createdAt.compareTo(b.createdAt);
        });

        return items;
      } catch (e2, st2) {
        Logger.error('getShoppingListItems error', error: e2, stackTrace: st2, tag: 'ShoppingService');
        return [];
      }
    }
  }

  Stream<List<ShoppingListItem>> getShoppingListItemsStream(String listId) {
    return Stream.fromFuture(_familyId).asyncExpand((familyId) {
      if (familyId == null) {
        return Stream.value(<ShoppingListItem>[]);
      }

      return _firestore
          .collection('families/$familyId/shoppingLists/$listId/items')
          .orderBy('orderIndex')
          .orderBy('createdAt')
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ShoppingListItem.fromJson({'id': doc.id, ...doc.data()}))
              .toList())
          .handleError((error) {
            Logger.warning('getShoppingListItemsStream error', error: error, tag: 'ShoppingService');
            return <ShoppingListItem>[];
          });
    });
  }

  Future<ShoppingListItem> addItem(
    String listId,
    String name, {
    int quantity = 1,
    String? category,
    String? notes,
  }) async {
    final familyId = await _familyId;
    final userId = _auth.currentUser?.uid;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    if (userId == null) throw AuthException('User not authenticated', code: 'not-authenticated');

    try {
      // Get current max orderIndex
      final items = await getShoppingListItems(listId);
      final maxOrderIndex = items.isEmpty
          ? 0
          : items.map((i) => i.orderIndex ?? 0).reduce((a, b) => a > b ? a : b);

      final item = ShoppingListItem(
        id: _firestore.collection('families/$familyId/shoppingLists/$listId/items').doc().id,
        listId: listId,
        name: name,
        quantity: quantity,
        category: category,
        notes: notes,
        addedBy: userId,
        createdAt: DateTime.now(),
        orderIndex: maxOrderIndex + 1,
      );

      final data = item.toJson();
      data.remove('id');

      await _firestore
          .collection('families/$familyId/shoppingLists/$listId/items')
          .doc(item.id)
          .set(data);

      // Update list item count
      await _updateListCounts(listId);

      Logger.info('addItem: Added item ${item.id} to list $listId', tag: 'ShoppingService');
      return item;
    } catch (e, st) {
      Logger.error('addItem error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<void> updateItem(ShoppingListItem item) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    try {
      final data = item.copyWith(updatedAt: DateTime.now()).toJson();
      data.remove('id');

      await _firestore
          .collection('families/$familyId/shoppingLists/${item.listId}/items')
          .doc(item.id)
          .update(data);

      // Update list counts
      await _updateListCounts(item.listId);

      Logger.info('updateItem: Updated item ${item.id}', tag: 'ShoppingService');
    } catch (e, st) {
      Logger.error('updateItem error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<void> deleteItem(String listId, String itemId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    try {
      await _firestore
          .collection('families/$familyId/shoppingLists/$listId/items')
          .doc(itemId)
          .delete();

      // Update list counts
      await _updateListCounts(listId);

      Logger.info('deleteItem: Deleted item $itemId', tag: 'ShoppingService');
    } catch (e, st) {
      Logger.error('deleteItem error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<void> updateItemStatus(String listId, String itemId, ItemStatus status) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    try {
      await _firestore
          .collection('families/$familyId/shoppingLists/$listId/items')
          .doc(itemId)
          .update({
        'status': status.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Update list counts
      await _updateListCounts(listId);

      Logger.info('updateItemStatus: Updated item $itemId status to ${status.name}', tag: 'ShoppingService');
    } catch (e, st) {
      Logger.error('updateItemStatus error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<void> updateItemQuantity(String listId, String itemId, int quantity) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    try {
      await _firestore
          .collection('families/$familyId/shoppingLists/$listId/items')
          .doc(itemId)
          .update({
        'quantity': quantity,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      Logger.info('updateItemQuantity: Updated item $itemId quantity to $quantity', tag: 'ShoppingService');
    } catch (e, st) {
      Logger.error('updateItemQuantity error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<void> reorderItems(String listId, List<String> itemIds) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    try {
      final batch = _firestore.batch();
      for (int i = 0; i < itemIds.length; i++) {
        final itemRef = _firestore
            .collection('families/$familyId/shoppingLists/$listId/items')
            .doc(itemIds[i]);
        batch.update(itemRef, {'orderIndex': i});
      }
      await batch.commit();

      Logger.info('reorderItems: Reordered ${itemIds.length} items', tag: 'ShoppingService');
    } catch (e, st) {
      Logger.error('reorderItems error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<void> _updateListCounts(String listId) async {
    final familyId = await _familyId;
    if (familyId == null) return;

    try {
      final items = await getShoppingListItems(listId);
      final itemCount = items.length;
      final completedItemCount = items.where((item) => item.isCompleted).length;

      await _firestore
          .collection('families/$familyId/shoppingLists')
          .doc(listId)
          .update({
        'itemCount': itemCount,
        'completedItemCount': completedItemCount,
      });
    } catch (e, st) {
      Logger.warning('_updateListCounts error', error: e, stackTrace: st, tag: 'ShoppingService');
    }
  }

  // ========== Receipts ==========

  Future<String> uploadReceiptImage(File imageFile, String listId) async {
    final familyId = await _familyId;
    final userId = _auth.currentUser?.uid;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    if (userId == null) throw AuthException('User not authenticated', code: 'not-authenticated');

    try {
      final fileName = 'receipts/$familyId/$listId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);

      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      Logger.info('uploadReceiptImage: Uploaded receipt image to $url', tag: 'ShoppingService');
      return url;
    } catch (e, st) {
      Logger.error('uploadReceiptImage error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<Receipt> saveReceipt(Receipt receipt) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    try {
      final data = receipt.toJson();
      data.remove('id');

      await _firestore
          .collection('families/$familyId/receipts')
          .doc(receipt.id)
          .set(data);

      Logger.info('saveReceipt: Saved receipt ${receipt.id}', tag: 'ShoppingService');
      return receipt;
    } catch (e, st) {
      Logger.error('saveReceipt error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<List<Receipt>> getReceipts({String? listId}) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getReceipts: User not part of a family', tag: 'ShoppingService');
      return [];
    }

    try {
      Query query = _firestore.collection('families/$familyId/receipts');
      if (listId != null) {
        query = query.where('listId', isEqualTo: listId);
      }
      query = query.orderBy('date', descending: true);

      final snapshot = await query.get();
      final receipts = snapshot.docs
          .map((doc) => Receipt.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      Logger.debug('getReceipts: Loaded ${receipts.length} receipts', tag: 'ShoppingService');
      return receipts;
    } catch (e, st) {
      Logger.error('getReceipts error', error: e, stackTrace: st, tag: 'ShoppingService');
      return [];
    }
  }

  // ========== Smart Recurring Lists ==========

  Future<List<SmartRecurringList>> getSmartRecurringLists() async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getSmartRecurringLists: User not part of a family', tag: 'ShoppingService');
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('families/$familyId/smartRecurringLists')
          .orderBy('usageCount', descending: true)
          .get();

      final lists = snapshot.docs
          .map((doc) => SmartRecurringList.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      Logger.debug('getSmartRecurringLists: Loaded ${lists.length} smart lists', tag: 'ShoppingService');
      return lists;
    } catch (e, st) {
      Logger.error('getSmartRecurringLists error', error: e, stackTrace: st, tag: 'ShoppingService');
      return [];
    }
  }

  Future<SmartRecurringList> createSmartRecurringList(
    String name,
    List<String> itemNames, {
    String frequency = 'weekly',
  }) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    try {
      final list = SmartRecurringList(
        id: _firestore.collection('families/$familyId/smartRecurringLists').doc().id,
        familyId: familyId,
        name: name,
        itemNames: itemNames,
        frequency: frequency,
        createdAt: DateTime.now(),
      );

      final data = list.toJson();
      data.remove('id');

      await _firestore
          .collection('families/$familyId/smartRecurringLists')
          .doc(list.id)
          .set(data);

      Logger.info('createSmartRecurringList: Created smart list ${list.id}', tag: 'ShoppingService');
      return list;
    } catch (e, st) {
      Logger.error('createSmartRecurringList error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  Future<ShoppingList> createListFromSmartRecurring(String smartListId) async {
    final familyId = await _familyId;
    final userId = _auth.currentUser?.uid;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    if (userId == null) throw AuthException('User not authenticated', code: 'not-authenticated');

    try {
      final smartListDoc = await _firestore
          .collection('families/$familyId/smartRecurringLists')
          .doc(smartListId)
          .get();

      if (!smartListDoc.exists) {
        throw FirestoreException('Smart recurring list not found', code: 'not-found');
      }

      final smartList = SmartRecurringList.fromJson({
        'id': smartListDoc.id,
        ...smartListDoc.data()!,
      });

      // Create new shopping list
      final shoppingList = await createShoppingList(smartList.name);

      // Add items from smart list
      for (final itemName in smartList.itemNames) {
        await addItem(shoppingList.id, itemName);
      }

      // Update smart list usage
      await _firestore
          .collection('families/$familyId/smartRecurringLists')
          .doc(smartListId)
          .update({
        'lastUsedAt': DateTime.now().toIso8601String(),
        'usageCount': FieldValue.increment(1),
      });

      Logger.info('createListFromSmartRecurring: Created list from smart list $smartListId', tag: 'ShoppingService');
      return shoppingList;
    } catch (e, st) {
      Logger.error('createListFromSmartRecurring error', error: e, stackTrace: st, tag: 'ShoppingService');
      rethrow;
    }
  }

  // ========== Analytics ==========

  Future<Map<String, dynamic>> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final familyId = await _familyId;
    if (familyId == null) {
      return {
        'totalSpending': 0.0,
        'receiptCount': 0,
        'categoryBreakdown': <String, double>{},
        'topItems': <Map<String, dynamic>>[],
        'monthlyAverages': <Map<String, dynamic>>[],
      };
    }

    try {
      Query query = _firestore.collection('families/$familyId/receipts');
      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: endDate);
      }

      final receiptsSnapshot = await query.get();
      final receipts = receiptsSnapshot.docs
          .map((doc) => Receipt.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      double totalSpending = 0.0;
      final Map<String, double> categoryBreakdown = {};
      final Map<String, int> itemCounts = {};

      for (final receipt in receipts) {
        totalSpending += receipt.total;
        for (final item in receipt.items) {
          final category = item.category ?? 'Uncategorized';
          categoryBreakdown[category] = (categoryBreakdown[category] ?? 0.0) + item.total;
          itemCounts[item.name] = (itemCounts[item.name] ?? 0) + item.quantity;
        }
      }

      // Get top 10 items
      final topItems = itemCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top10Items = topItems.take(10).map((entry) => {
        'name': entry.key,
        'count': entry.value,
      }).toList();

      // Calculate monthly averages
      final monthlyAverages = _calculateMonthlyAverages(receipts);

      return {
        'totalSpending': totalSpending,
        'receiptCount': receipts.length,
        'categoryBreakdown': categoryBreakdown,
        'topItems': top10Items,
        'monthlyAverages': monthlyAverages,
      };
    } catch (e, st) {
      Logger.error('getAnalytics error', error: e, stackTrace: st, tag: 'ShoppingService');
      return {
        'totalSpending': 0.0,
        'receiptCount': 0,
        'categoryBreakdown': <String, double>{},
        'topItems': <Map<String, dynamic>>[],
        'monthlyAverages': <Map<String, dynamic>>[],
      };
    }
  }

  List<Map<String, dynamic>> _calculateMonthlyAverages(List<Receipt> receipts) {
    final Map<String, List<double>> monthlyTotals = {};

    for (final receipt in receipts) {
      final monthKey = '${receipt.date.year}-${receipt.date.month.toString().padLeft(2, '0')}';
      monthlyTotals.putIfAbsent(monthKey, () => []).add(receipt.total);
    }

    return monthlyTotals.entries.map((entry) {
      final totals = entry.value;
      final average = totals.reduce((a, b) => a + b) / totals.length;
      return {
        'month': entry.key,
        'average': average,
        'count': totals.length,
      };
    }).toList();
  }

  // ========== Auto-suggestions ==========

  Future<List<String>> getItemSuggestions(String query) async {
    final familyId = await _familyId;
    if (familyId == null) return [];

    try {
      // Get items from recent receipts
      final receipts = await getReceipts();
      final suggestions = <String, int>{};

      for (final receipt in receipts.take(50)) { // Last 50 receipts
        for (final item in receipt.items) {
          if (item.name.toLowerCase().contains(query.toLowerCase())) {
            suggestions[item.name] = (suggestions[item.name] ?? 0) + item.quantity;
          }
        }
      }

      // Get items from completed shopping lists
      final lists = await getShoppingLists();
      for (final list in lists) {
        if (list.isCompleted) {
          final items = await getShoppingListItems(list.id);
          for (final item in items) {
            if (item.name.toLowerCase().contains(query.toLowerCase())) {
              suggestions[item.name] = (suggestions[item.name] ?? 0) + item.quantity;
            }
          }
        }
      }

      // Sort by frequency and return top 10
      final sorted = suggestions.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.take(10).map((e) => e.key).toList();
    } catch (e, st) {
      Logger.warning('getItemSuggestions error', error: e, stackTrace: st, tag: 'ShoppingService');
      return [];
    }
  }
}
