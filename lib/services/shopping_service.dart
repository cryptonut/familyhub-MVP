import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/shopping_list.dart';
import '../models/shopping_item.dart';
import '../models/shopping_category.dart';
import '../models/shopping_receipt.dart';
import 'auth_service.dart';

/// Service for managing shopping lists, items, and receipts
class ShoppingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

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
    Logger.debug('clearFamilyIdCache: Clearing cached familyId', tag: 'ShoppingService');
    _cachedFamilyId = null;
  }

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  // ============== SHOPPING LIST OPERATIONS ==============

  /// Get all shopping lists for the family
  Future<List<ShoppingList>> getShoppingLists({bool forceRefresh = false}) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getShoppingLists: User not part of a family', tag: 'ShoppingService');
      return [];
    }

    try {
      final collectionPath = 'families/$familyId/shoppingLists';
      Logger.debug('getShoppingLists: Loading from $collectionPath', tag: 'ShoppingService');

      final snapshot = await _firestore
          .collection(collectionPath)
          .where('isArchived', isEqualTo: false)
          .orderBy('isDefault', descending: true)
          .orderBy('createdAt', descending: true)
          .get(GetOptions(source: forceRefresh ? Source.server : Source.cache));

      final lists = snapshot.docs.map((doc) {
        try {
          return ShoppingList.fromJson({
            'id': doc.id,
            ...doc.data(),
          });
        } catch (e, st) {
          Logger.warning('getShoppingLists: Error parsing list ${doc.id}', error: e, stackTrace: st, tag: 'ShoppingService');
          return null;
        }
      }).whereType<ShoppingList>().toList();

      Logger.debug('getShoppingLists: Loaded ${lists.length} lists', tag: 'ShoppingService');
      return lists;
    } catch (e, st) {
      Logger.error('getShoppingLists error', error: e, stackTrace: st, tag: 'ShoppingService');
      return [];
    }
  }

  /// Stream shopping lists for real-time updates
  Stream<List<ShoppingList>> streamShoppingLists() {
    return Stream.fromFuture(_familyId).asyncExpand((familyId) {
      if (familyId == null) {
        return Stream.value(<ShoppingList>[]);
      }

      return _firestore
          .collection('families/$familyId/shoppingLists')
          .where('isArchived', isEqualTo: false)
          .orderBy('isDefault', descending: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ShoppingList.fromJson({
                    'id': doc.id,
                    ...doc.data(),
                  }))
              .toList());
    });
  }

  /// Get a single shopping list by ID
  Future<ShoppingList?> getShoppingList(String listId) async {
    final familyId = await _familyId;
    if (familyId == null) return null;

    try {
      final doc = await _firestore
          .collection('families/$familyId/shoppingLists')
          .doc(listId)
          .get();

      if (!doc.exists) return null;

      return ShoppingList.fromJson({
        'id': doc.id,
        ...doc.data()!,
      });
    } catch (e, st) {
      Logger.error('getShoppingList error', error: e, stackTrace: st, tag: 'ShoppingService');
      return null;
    }
  }

  /// Create a new shopping list
  Future<ShoppingList> createShoppingList({
    required String name,
    String? description,
    bool isDefault = false,
    List<String>? sharedWith,
  }) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final listId = _uuid.v4();
    final now = DateTime.now();

    // If this is set as default, unset other defaults
    if (isDefault) {
      await _unsetOtherDefaults(familyId);
    }

    final list = ShoppingList(
      id: listId,
      name: name,
      description: description,
      creatorId: _currentUserId,
      createdAt: now,
      isDefault: isDefault,
      sharedWith: sharedWith ?? [],
    );

    await _firestore
        .collection('families/$familyId/shoppingLists')
        .doc(listId)
        .set(list.toJson()..remove('id'));

    Logger.info('createShoppingList: Created list "$name" ($listId)', tag: 'ShoppingService');
    return list;
  }

  /// Update an existing shopping list
  Future<void> updateShoppingList(ShoppingList list) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    // If setting as default, unset others first
    if (list.isDefault) {
      await _unsetOtherDefaults(familyId, excludeId: list.id);
    }

    final data = list.copyWith(updatedAt: DateTime.now()).toJson();
    data.remove('id');

    await _firestore
        .collection('families/$familyId/shoppingLists')
        .doc(list.id)
        .update(data);

    Logger.info('updateShoppingList: Updated list ${list.id}', tag: 'ShoppingService');
  }

  /// Delete (archive) a shopping list
  Future<void> deleteShoppingList(String listId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    // Soft delete by archiving
    await _firestore
        .collection('families/$familyId/shoppingLists')
        .doc(listId)
        .update({
      'isArchived': true,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    Logger.info('deleteShoppingList: Archived list $listId', tag: 'ShoppingService');
  }

  Future<void> _unsetOtherDefaults(String familyId, {String? excludeId}) async {
    final snapshot = await _firestore
        .collection('families/$familyId/shoppingLists')
        .where('isDefault', isEqualTo: true)
        .get();

    for (var doc in snapshot.docs) {
      if (doc.id != excludeId) {
        await doc.reference.update({'isDefault': false});
      }
    }
  }

  // ============== SHOPPING ITEM OPERATIONS ==============

  /// Get all items in a shopping list
  Future<List<ShoppingItem>> getShoppingItems(String listId, {bool forceRefresh = false}) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getShoppingItems: User not part of a family', tag: 'ShoppingService');
      return [];
    }

    try {
      final collectionPath = 'families/$familyId/shoppingLists/$listId/items';
      
      final snapshot = await _firestore
          .collection(collectionPath)
          .orderBy('categoryName')
          .orderBy('createdAt', descending: true)
          .get(GetOptions(source: forceRefresh ? Source.server : Source.cache));

      return snapshot.docs.map((doc) {
        try {
          return ShoppingItem.fromJson({
            'id': doc.id,
            ...doc.data(),
          });
        } catch (e, st) {
          Logger.warning('getShoppingItems: Error parsing item ${doc.id}', error: e, stackTrace: st, tag: 'ShoppingService');
          return null;
        }
      }).whereType<ShoppingItem>().toList();
    } catch (e, st) {
      Logger.error('getShoppingItems error', error: e, stackTrace: st, tag: 'ShoppingService');
      return [];
    }
  }

  /// Stream items for real-time updates
  Stream<List<ShoppingItem>> streamShoppingItems(String listId) {
    return Stream.fromFuture(_familyId).asyncExpand((familyId) {
      if (familyId == null) {
        return Stream.value(<ShoppingItem>[]);
      }

      return _firestore
          .collection('families/$familyId/shoppingLists/$listId/items')
          .orderBy('categoryName')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ShoppingItem.fromJson({
                    'id': doc.id,
                    ...doc.data(),
                  }))
              .toList());
    });
  }

  /// Add a new item to a shopping list
  Future<ShoppingItem> addShoppingItem({
    required String listId,
    required String name,
    int quantity = 1,
    String? unit,
    String? notes,
    String? categoryId,
    String? categoryName,
  }) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final itemId = _uuid.v4();
    final now = DateTime.now();

    final item = ShoppingItem(
      id: itemId,
      listId: listId,
      name: name,
      quantity: quantity,
      unit: unit,
      addedBy: _currentUserId,
      notes: notes,
      categoryId: categoryId,
      categoryName: categoryName ?? 'Other',
      createdAt: now,
    );

    await _firestore
        .collection('families/$familyId/shoppingLists/$listId/items')
        .doc(itemId)
        .set(item.toJson()..remove('id'));

    // Update item count on the list
    await _updateListItemCounts(familyId, listId);

    Logger.info('addShoppingItem: Added "$name" to list $listId', tag: 'ShoppingService');
    return item;
  }

  /// Update an existing item
  Future<void> updateShoppingItem(ShoppingItem item) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final data = item.copyWith(updatedAt: DateTime.now()).toJson();
    data.remove('id');

    await _firestore
        .collection('families/$familyId/shoppingLists/${item.listId}/items')
        .doc(item.id)
        .update(data);

    // Update counts if status changed
    await _updateListItemCounts(familyId, item.listId);

    Logger.info('updateShoppingItem: Updated item ${item.id}', tag: 'ShoppingService');
  }

  /// Update item quantity
  Future<void> updateItemQuantity(String listId, String itemId, int newQuantity) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    if (newQuantity < 1) {
      throw ValidationException('Quantity must be at least 1', code: 'invalid-quantity');
    }

    await _firestore
        .collection('families/$familyId/shoppingLists/$listId/items')
        .doc(itemId)
        .update({
      'quantity': newQuantity,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Mark item as purchased (Got It!)
  Future<void> markItemGotIt(String listId, String itemId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final now = DateTime.now();
    await _firestore
        .collection('families/$familyId/shoppingLists/$listId/items')
        .doc(itemId)
        .update({
      'status': ShoppingItemStatus.gotIt.name,
      'completedBy': _currentUserId,
      'completedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    await _updateListItemCounts(familyId, listId);
    await _incrementPurchaseCount(familyId, itemId);

    Logger.info('markItemGotIt: Marked item $itemId as purchased', tag: 'ShoppingService');
  }

  /// Mark item as unavailable
  Future<void> markItemUnavailable(String listId, String itemId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final now = DateTime.now();
    await _firestore
        .collection('families/$familyId/shoppingLists/$listId/items')
        .doc(itemId)
        .update({
      'status': ShoppingItemStatus.unavailable.name,
      'completedBy': _currentUserId,
      'completedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    await _updateListItemCounts(familyId, listId);

    Logger.info('markItemUnavailable: Marked item $itemId as unavailable', tag: 'ShoppingService');
  }

  /// Mark item as cancelled
  Future<void> markItemCancelled(String listId, String itemId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final now = DateTime.now();
    await _firestore
        .collection('families/$familyId/shoppingLists/$listId/items')
        .doc(itemId)
        .update({
      'status': ShoppingItemStatus.cancelled.name,
      'completedBy': _currentUserId,
      'completedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    });

    await _updateListItemCounts(familyId, listId);

    Logger.info('markItemCancelled: Marked item $itemId as cancelled', tag: 'ShoppingService');
  }

  /// Reset item to pending
  Future<void> resetItemToPending(String listId, String itemId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    await _firestore
        .collection('families/$familyId/shoppingLists/$listId/items')
        .doc(itemId)
        .update({
      'status': ShoppingItemStatus.pending.name,
      'completedBy': null,
      'completedAt': null,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    await _updateListItemCounts(familyId, listId);

    Logger.info('resetItemToPending: Reset item $itemId to pending', tag: 'ShoppingService');
  }

  /// Delete an item from a shopping list
  Future<void> deleteShoppingItem(String listId, String itemId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    await _firestore
        .collection('families/$familyId/shoppingLists/$listId/items')
        .doc(itemId)
        .delete();

    await _updateListItemCounts(familyId, listId);

    Logger.info('deleteShoppingItem: Deleted item $itemId', tag: 'ShoppingService');
  }

  Future<void> _updateListItemCounts(String familyId, String listId) async {
    try {
      final snapshot = await _firestore
          .collection('families/$familyId/shoppingLists/$listId/items')
          .get();

      int itemCount = 0;
      int completedCount = 0;

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status != ShoppingItemStatus.cancelled.name) {
          itemCount++;
          if (status == ShoppingItemStatus.gotIt.name || 
              status == ShoppingItemStatus.unavailable.name) {
            completedCount++;
          }
        }
      }

      await _firestore
          .collection('families/$familyId/shoppingLists')
          .doc(listId)
          .update({
        'itemCount': itemCount,
        'completedItemCount': completedCount,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      Logger.warning('_updateListItemCounts error', error: e, stackTrace: st, tag: 'ShoppingService');
    }
  }

  Future<void> _incrementPurchaseCount(String familyId, String itemId) async {
    // Store purchase history for smart suggestions
    try {
      await _firestore
          .collection('families/$familyId/purchaseHistory')
          .doc(itemId)
          .set({
        'lastPurchased': DateTime.now().toIso8601String(),
        'purchaseCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e, st) {
      Logger.warning('_incrementPurchaseCount error', error: e, stackTrace: st, tag: 'ShoppingService');
    }
  }

  // ============== CATEGORY OPERATIONS ==============

  /// Get all categories
  Future<List<ShoppingCategory>> getCategories() async {
    final familyId = await _familyId;
    if (familyId == null) {
      // Return default categories if no family
      return ShoppingCategory.defaultCategories;
    }

    try {
      final snapshot = await _firestore
          .collection('families/$familyId/shoppingCategories')
          .orderBy('order')
          .get();

      if (snapshot.docs.isEmpty) {
        // Initialize with default categories
        await _initializeDefaultCategories(familyId);
        return ShoppingCategory.defaultCategories;
      }

      return snapshot.docs.map((doc) {
        return ShoppingCategory.fromJson({
          'id': doc.id,
          ...doc.data(),
        });
      }).toList();
    } catch (e, st) {
      Logger.error('getCategories error', error: e, stackTrace: st, tag: 'ShoppingService');
      return ShoppingCategory.defaultCategories;
    }
  }

  Future<void> _initializeDefaultCategories(String familyId) async {
    final batch = _firestore.batch();
    for (var category in ShoppingCategory.defaultCategories) {
      final docRef = _firestore
          .collection('families/$familyId/shoppingCategories')
          .doc(category.id);
      batch.set(docRef, category.toJson()..remove('id'));
    }
    await batch.commit();
    Logger.info('_initializeDefaultCategories: Created default categories', tag: 'ShoppingService');
  }

  /// Auto-suggest category based on item name
  String? suggestCategory(String itemName) {
    final lowerName = itemName.toLowerCase();
    
    // Produce
    if (_matchesAny(lowerName, ['apple', 'banana', 'orange', 'lettuce', 'tomato', 'onion', 
        'potato', 'carrot', 'broccoli', 'cucumber', 'pepper', 'spinach', 'avocado',
        'garlic', 'lemon', 'lime', 'grape', 'strawberry', 'blueberry', 'watermelon',
        'mango', 'pineapple', 'celery', 'mushroom', 'zucchini', 'corn', 'beans',
        'fruit', 'vegetable', 'salad', 'herb'])) {
      return 'produce';
    }
    
    // Dairy
    if (_matchesAny(lowerName, ['milk', 'cheese', 'yogurt', 'butter', 'cream', 'egg',
        'cottage', 'sour cream', 'whipped', 'cheddar', 'mozzarella', 'parmesan'])) {
      return 'dairy';
    }
    
    // Meat & Seafood
    if (_matchesAny(lowerName, ['chicken', 'beef', 'pork', 'fish', 'salmon', 'tuna',
        'shrimp', 'bacon', 'sausage', 'ham', 'turkey', 'steak', 'lamb', 'meat',
        'seafood', 'crab', 'lobster', 'prawn'])) {
      return 'meat';
    }
    
    // Bakery
    if (_matchesAny(lowerName, ['bread', 'bagel', 'croissant', 'muffin', 'roll',
        'bun', 'tortilla', 'pita', 'cake', 'donut', 'pastry', 'baguette'])) {
      return 'bakery';
    }
    
    // Frozen
    if (_matchesAny(lowerName, ['frozen', 'ice cream', 'pizza', 'fries', 'nugget',
        'popsicle', 'waffle', 'ice'])) {
      return 'frozen';
    }
    
    // Pantry
    if (_matchesAny(lowerName, ['rice', 'pasta', 'cereal', 'flour', 'sugar', 'oil',
        'sauce', 'soup', 'can', 'bean', 'spice', 'salt', 'pepper', 'vinegar',
        'noodle', 'oat', 'honey', 'jam', 'peanut butter', 'syrup'])) {
      return 'pantry';
    }
    
    // Beverages
    if (_matchesAny(lowerName, ['water', 'juice', 'soda', 'coffee', 'tea', 'wine',
        'beer', 'drink', 'cola', 'sprite', 'energy', 'smoothie'])) {
      return 'beverages';
    }
    
    // Snacks
    if (_matchesAny(lowerName, ['chip', 'crisp', 'cookie', 'cracker', 'popcorn',
        'candy', 'chocolate', 'nut', 'pretzel', 'snack', 'bar', 'gum'])) {
      return 'snacks';
    }
    
    // Household
    if (_matchesAny(lowerName, ['paper', 'towel', 'tissue', 'soap', 'detergent',
        'cleaner', 'sponge', 'trash', 'bag', 'foil', 'wrap', 'battery',
        'light', 'bulb', 'candle'])) {
      return 'household';
    }
    
    // Personal Care
    if (_matchesAny(lowerName, ['shampoo', 'conditioner', 'toothpaste', 'brush',
        'deodorant', 'lotion', 'razor', 'makeup', 'skincare', 'sunscreen',
        'medicine', 'vitamin', 'bandage'])) {
      return 'personal';
    }
    
    return 'other';
  }

  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  // ============== RECEIPT OPERATIONS ==============

  /// Upload a receipt image and create a receipt record
  Future<ShoppingReceipt> uploadReceipt({
    String? listId,
    required File imageFile,
  }) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final receiptId = _uuid.v4();
    final now = DateTime.now();

    // Upload image to Firebase Storage
    final storagePath = 'families/$familyId/receipts/$receiptId.jpg';
    final ref = _storage.ref().child(storagePath);
    await ref.putFile(imageFile);
    final imageUrl = await ref.getDownloadURL();

    final receipt = ShoppingReceipt(
      id: receiptId,
      listId: listId,
      imageUrl: imageUrl,
      uploadedBy: _currentUserId,
      createdAt: now,
    );

    await _firestore
        .collection('families/$familyId/receipts')
        .doc(receiptId)
        .set(receipt.toJson()..remove('id'));

    Logger.info('uploadReceipt: Uploaded receipt $receiptId', tag: 'ShoppingService');
    return receipt;
  }

  /// Get all receipts
  Future<List<ShoppingReceipt>> getReceipts({bool forceRefresh = false}) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getReceipts: User not part of a family', tag: 'ShoppingService');
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection('families/$familyId/receipts')
          .orderBy('createdAt', descending: true)
          .get(GetOptions(source: forceRefresh ? Source.server : Source.cache));

      return snapshot.docs.map((doc) {
        return ShoppingReceipt.fromJson({
          'id': doc.id,
          ...doc.data(),
        });
      }).toList();
    } catch (e, st) {
      Logger.error('getReceipts error', error: e, stackTrace: st, tag: 'ShoppingService');
      return [];
    }
  }

  /// Update receipt with OCR data
  Future<void> updateReceiptWithOcrData(ShoppingReceipt receipt) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final data = receipt.copyWith(
      isProcessed: true,
      updatedAt: DateTime.now(),
    ).toJson();
    data.remove('id');

    await _firestore
        .collection('families/$familyId/receipts')
        .doc(receipt.id)
        .update(data);

    Logger.info('updateReceiptWithOcrData: Updated receipt ${receipt.id}', tag: 'ShoppingService');
  }

  /// Verify/correct receipt data
  Future<void> verifyReceipt(String receiptId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    await _firestore
        .collection('families/$familyId/receipts')
        .doc(receiptId)
        .update({
      'isVerified': true,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    Logger.info('verifyReceipt: Verified receipt $receiptId', tag: 'ShoppingService');
  }

  // ============== SMART LIST SUGGESTIONS ==============

  /// Get smart suggestions based on purchase history
  Future<List<ShoppingItem>> getSmartSuggestions() async {
    final familyId = await _familyId;
    if (familyId == null) return [];

    try {
      // Get frequently purchased items
      final historySnapshot = await _firestore
          .collection('families/$familyId/purchaseHistory')
          .orderBy('purchaseCount', descending: true)
          .limit(20)
          .get();

      // Get recent items from completed lists
      final listsSnapshot = await _firestore
          .collection('families/$familyId/shoppingLists')
          .where('isArchived', isEqualTo: false)
          .orderBy('updatedAt', descending: true)
          .limit(5)
          .get();

      final suggestedItems = <ShoppingItem>[];
      final seenNames = <String>{};

      // Add frequently purchased items
      for (var doc in historySnapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String? ?? doc.id;
        if (!seenNames.contains(name.toLowerCase())) {
          seenNames.add(name.toLowerCase());
          suggestedItems.add(ShoppingItem(
            id: doc.id,
            listId: '',
            name: name,
            addedBy: _currentUserId,
            createdAt: DateTime.now(),
            purchaseCount: data['purchaseCount'] as int? ?? 0,
            isRecurring: true,
          ));
        }
      }

      return suggestedItems;
    } catch (e, st) {
      Logger.error('getSmartSuggestions error', error: e, stackTrace: st, tag: 'ShoppingService');
      return [];
    }
  }

  // ============== ANALYTICS ==============

  /// Get spending analytics
  Future<Map<String, dynamic>> getSpendingAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final familyId = await _familyId;
    if (familyId == null) return {};

    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      final receiptsSnapshot = await _firestore
          .collection('families/$familyId/receipts')
          .where('isVerified', isEqualTo: true)
          .where('purchaseDate', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('purchaseDate', isLessThanOrEqualTo: end.toIso8601String())
          .get();

      double totalSpending = 0;
      final categorySpending = <String, double>{};
      final storeSpending = <String, double>{};
      final itemCounts = <String, int>{};
      final priceHistory = <String, List<Map<String, dynamic>>>{};

      for (var doc in receiptsSnapshot.docs) {
        final receipt = ShoppingReceipt.fromJson({
          'id': doc.id,
          ...doc.data(),
        });

        totalSpending += receipt.total ?? 0;

        if (receipt.storeName != null) {
          storeSpending[receipt.storeName!] = 
              (storeSpending[receipt.storeName!] ?? 0) + (receipt.total ?? 0);
        }

        for (var item in receipt.items) {
          itemCounts[item.name] = (itemCounts[item.name] ?? 0) + item.quantity;
          
          priceHistory.putIfAbsent(item.name, () => []);
          priceHistory[item.name]!.add({
            'date': receipt.purchaseDate?.toIso8601String(),
            'price': item.price,
            'store': receipt.storeName,
          });
        }
      }

      // Get top 10 most bought items
      final topItems = itemCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'totalSpending': totalSpending,
        'receiptCount': receiptsSnapshot.docs.length,
        'categorySpending': categorySpending,
        'storeSpending': storeSpending,
        'topItems': topItems.take(10).map((e) => {'name': e.key, 'count': e.value}).toList(),
        'priceHistory': priceHistory,
        'startDate': start.toIso8601String(),
        'endDate': end.toIso8601String(),
      };
    } catch (e, st) {
      Logger.error('getSpendingAnalytics error', error: e, stackTrace: st, tag: 'ShoppingService');
      return {};
    }
  }

  // ============== ROLE CHECKING ==============

  /// Check if current user has Shopper role
  Future<bool> isCurrentUserShopper() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return false;
      
      // Admins and Bankers are automatically Shoppers
      if (userModel.isAdmin() || userModel.isBanker()) return true;
      
      // Check for explicit Shopper role
      return userModel.hasRole('shopper');
    } catch (e, st) {
      Logger.error('isCurrentUserShopper error', error: e, stackTrace: st, tag: 'ShoppingService');
      return false;
    }
  }
}
