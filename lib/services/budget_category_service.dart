import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/budget_category.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';

/// Service for managing budget categories
class BudgetCategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  String? _cachedFamilyId;

  Future<String?> get _familyId async {
    final userModel = await _authService.getCurrentUserModel();
    final freshFamilyId = userModel?.familyId;
    if (_cachedFamilyId != freshFamilyId) {
      Logger.debug('_familyId: FamilyId changed from $_cachedFamilyId to $freshFamilyId', tag: 'BudgetCategoryService');
      _cachedFamilyId = freshFamilyId;
    }
    return _cachedFamilyId;
  }

  void clearFamilyIdCache() {
    Logger.debug('clearFamilyIdCache: Clearing cached familyId', tag: 'BudgetCategoryService');
    _cachedFamilyId = null;
  }

  /// Default categories for new budgets
  static List<BudgetCategory> getDefaultCategories(String budgetId) {
    final now = DateTime.now();
    return [
      BudgetCategory(
        id: 'food',
        budgetId: budgetId,
        name: 'Food & Groceries',
        icon: '🍔',
        color: '#FF9800',
        isDefault: true,
        createdAt: now,
      ),
      BudgetCategory(
        id: 'transport',
        budgetId: budgetId,
        name: 'Transport',
        icon: '🚗',
        color: '#2196F3',
        isDefault: true,
        createdAt: now,
      ),
      BudgetCategory(
        id: 'entertainment',
        budgetId: budgetId,
        name: 'Entertainment',
        icon: '🎬',
        color: '#9C27B0',
        isDefault: true,
        createdAt: now,
      ),
      BudgetCategory(
        id: 'utilities',
        budgetId: budgetId,
        name: 'Utilities',
        icon: '💡',
        color: '#F44336',
        isDefault: true,
        createdAt: now,
      ),
      BudgetCategory(
        id: 'shopping',
        budgetId: budgetId,
        name: 'Shopping',
        icon: '🛍️',
        color: '#E91E63',
        isDefault: true,
        createdAt: now,
      ),
      BudgetCategory(
        id: 'health',
        budgetId: budgetId,
        name: 'Health & Fitness',
        icon: '💊',
        color: '#4CAF50',
        isDefault: true,
        createdAt: now,
      ),
      BudgetCategory(
        id: 'education',
        budgetId: budgetId,
        name: 'Education',
        icon: '📚',
        color: '#00BCD4',
        isDefault: true,
        createdAt: now,
      ),
      BudgetCategory(
        id: 'other',
        budgetId: budgetId,
        name: 'Other',
        icon: '📦',
        color: '#9E9E9E',
        isDefault: true,
        createdAt: now,
      ),
    ];
  }

  /// Get all categories for a budget
  Future<List<BudgetCategory>> getCategories({
    required String budgetId,
    bool activeOnly = true,
  }) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getCategories: User not part of a family', tag: 'BudgetCategoryService');
      return [];
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/categories');
      Query query = _firestore.collection(collectionPath);

      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      query = query.orderBy('name', descending: false);

      final snapshot = await query.get();
      final categories = snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          return BudgetCategory.fromJson({
            'id': doc.id,
            ...data,
          });
        } catch (e) {
          Logger.warning('Error parsing category ${doc.id}', error: e, tag: 'BudgetCategoryService');
          return null;
        }
      }).whereType<BudgetCategory>().toList();

      Logger.debug('getCategories: Loaded ${categories.length} categories', tag: 'BudgetCategoryService');
      return categories;
    } catch (e, stackTrace) {
      Logger.error('getCategories error', error: e, stackTrace: stackTrace, tag: 'BudgetCategoryService');
      return [];
    }
  }

  /// Get a single category by ID
  Future<BudgetCategory?> getCategory(String budgetId, String categoryId) async {
    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/categories');
      final doc = await _firestore.collection(collectionPath).doc(categoryId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      return BudgetCategory.fromJson({
        'id': doc.id,
        ...data,
      });
    } catch (e, stackTrace) {
      Logger.error('getCategory error', error: e, stackTrace: stackTrace, tag: 'BudgetCategoryService');
      rethrow;
    }
  }

  /// Stream of categories for real-time updates
  Stream<List<BudgetCategory>> watchCategories({
    required String budgetId,
    bool activeOnly = true,
  }) {
    return _familyId.then((familyId) {
      if (familyId == null) {
        return Stream.value(<BudgetCategory>[]);
      }

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/categories');
      Query query = _firestore.collection(collectionPath);

      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      query = query.orderBy('name', descending: false);

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            return BudgetCategory.fromJson({
              'id': doc.id,
              ...data,
            });
          } catch (e) {
            Logger.warning('Error parsing category ${doc.id}', error: e, tag: 'BudgetCategoryService');
            return null;
          }
        }).whereType<BudgetCategory>().toList();
      });
    }).asStream().asyncExpand((stream) => stream);
  }

  /// Create a new category
  Future<BudgetCategory> createCategory({
    required String budgetId,
    required String name,
    String? description,
    String? icon,
    String color = '#2196F3',
    double? limit,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    // Validate name
    if (name.trim().isEmpty) {
      throw ValidationException('Category name cannot be empty', code: 'invalid-name');
    }

    try {
      final categoryId = _uuid.v4();
      final now = DateTime.now();

      final category = BudgetCategory(
        id: categoryId,
        budgetId: budgetId,
        name: name.trim(),
        description: description?.trim(),
        icon: icon,
        color: color,
        limit: limit,
        isDefault: false,
        isActive: true,
        createdAt: now,
      );

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/categories');
      await _firestore.collection(collectionPath).doc(categoryId).set(category.toJson());

      Logger.debug('createCategory: Created category $categoryId', tag: 'BudgetCategoryService');
      return category;
    } catch (e, stackTrace) {
      Logger.error('createCategory error', error: e, stackTrace: stackTrace, tag: 'BudgetCategoryService');
      rethrow;
    }
  }

  /// Initialize default categories for a budget
  Future<void> initializeDefaultCategories(String budgetId) async {
    final defaultCategories = getDefaultCategories(budgetId);
    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/categories');
      final batch = _firestore.batch();

      for (final category in defaultCategories) {
        final docRef = _firestore.collection(collectionPath).doc(category.id);
        batch.set(docRef, category.toJson());
      }

      await batch.commit();
      Logger.debug('initializeDefaultCategories: Initialized ${defaultCategories.length} default categories', tag: 'BudgetCategoryService');
    } catch (e, stackTrace) {
      Logger.error('initializeDefaultCategories error', error: e, stackTrace: stackTrace, tag: 'BudgetCategoryService');
      rethrow;
    }
  }

  /// Update an existing category
  Future<BudgetCategory> updateCategory(BudgetCategory category) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    // Validate name
    if (category.name.trim().isEmpty) {
      throw ValidationException('Category name cannot be empty', code: 'invalid-name');
    }

    try {
      final updatedCategory = category.copyWith(
        name: category.name.trim(),
        updatedAt: DateTime.now(),
      );

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/${category.budgetId}/categories');
      await _firestore.collection(collectionPath).doc(category.id).update(updatedCategory.toJson());

      Logger.debug('updateCategory: Updated category ${category.id}', tag: 'BudgetCategoryService');
      return updatedCategory;
    } catch (e, stackTrace) {
      Logger.error('updateCategory error', error: e, stackTrace: stackTrace, tag: 'BudgetCategoryService');
      rethrow;
    }
  }

  /// Delete a category
  Future<void> deleteCategory(String budgetId, String categoryId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    // Check if category is default (don't allow deletion of default categories)
    final category = await getCategory(budgetId, categoryId);
    if (category != null && category.isDefault) {
      throw ValidationException('Cannot delete default category', code: 'cannot-delete-default');
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/categories');
      await _firestore.collection(collectionPath).doc(categoryId).delete();

      Logger.debug('deleteCategory: Deleted category $categoryId', tag: 'BudgetCategoryService');
    } catch (e, stackTrace) {
      Logger.error('deleteCategory error', error: e, stackTrace: stackTrace, tag: 'BudgetCategoryService');
      rethrow;
    }
  }

  /// Archive a category (set isActive to false)
  Future<void> archiveCategory(String budgetId, String categoryId) async {
    final category = await getCategory(budgetId, categoryId);
    if (category == null) {
      throw NotFoundException('Category not found', code: 'category-not-found');
    }

    final updatedCategory = category.copyWith(isActive: false);
    await updateCategory(updatedCategory);
  }
}

