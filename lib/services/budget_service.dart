import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/budget.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';

/// Service for managing budgets
class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  String? _cachedFamilyId;

  Future<String?> get _familyId async {
    final userModel = await _authService.getCurrentUserModel();
    final freshFamilyId = userModel?.familyId;
    if (_cachedFamilyId != freshFamilyId) {
      Logger.debug('_familyId: FamilyId changed from $_cachedFamilyId to $freshFamilyId', tag: 'BudgetService');
      _cachedFamilyId = freshFamilyId;
    }
    return _cachedFamilyId;
  }

  void clearFamilyIdCache() {
    Logger.debug('clearFamilyIdCache: Clearing cached familyId', tag: 'BudgetService');
    _cachedFamilyId = null;
  }

  /// Get all budgets for the family
  Future<List<Budget>> getBudgets({bool activeOnly = false}) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getBudgets: User not part of a family', tag: 'BudgetService');
      return [];
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets');
      Query query = _firestore.collection(collectionPath);

      // Try the indexed query first, fallback to simple query if index is building
      Query? indexedQuery;
      if (activeOnly) {
        try {
          indexedQuery = query.where('isActive', isEqualTo: true).orderBy('createdAt', descending: true);
        } catch (e) {
          Logger.debug('Indexed query not available, using fallback', tag: 'BudgetService');
        }
      } else {
        indexedQuery = query.orderBy('createdAt', descending: true);
      }

      // Try indexed query first
      if (indexedQuery != null) {
        try {
          final snapshot = await indexedQuery.get();
          final budgets = snapshot.docs.map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return Budget.fromJson({
                'id': doc.id,
                ...data,
              });
            } catch (e) {
              Logger.warning('Error parsing budget ${doc.id}', error: e, tag: 'BudgetService');
              return null;
            }
          }).whereType<Budget>().toList();

          // Filter in memory if activeOnly and index query worked
          final filteredBudgets = activeOnly 
              ? budgets.where((b) => b.isActive).toList()
              : budgets;
          
          Logger.debug('getBudgets: Loaded ${filteredBudgets.length} budgets', tag: 'BudgetService');
          return filteredBudgets;
        } catch (e) {
          // Index might be building, fall through to fallback
          Logger.debug('Index query failed, using fallback: $e', tag: 'BudgetService');
        }
      }

      // Fallback: Get all budgets and filter/sort in memory
      final snapshot = await query.get();
      var budgets = snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          return Budget.fromJson({
            'id': doc.id,
            ...data,
          });
        } catch (e) {
          Logger.warning('Error parsing budget ${doc.id}', error: e, tag: 'BudgetService');
          return null;
        }
      }).whereType<Budget>().toList();

      // Filter and sort in memory
      if (activeOnly) {
        budgets = budgets.where((b) => b.isActive).toList();
      }
      budgets.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      Logger.debug('getBudgets: Loaded ${budgets.length} budgets (fallback method)', tag: 'BudgetService');
      return budgets;
    } catch (e, stackTrace) {
      Logger.error('getBudgets error', error: e, stackTrace: stackTrace, tag: 'BudgetService');
      return [];
    }
  }

  /// Get a single budget by ID
  Future<Budget?> getBudget(String budgetId) async {
    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets');
      final doc = await _firestore.collection(collectionPath).doc(budgetId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      return Budget.fromJson({
        'id': doc.id,
        ...data,
      });
    } catch (e, stackTrace) {
      Logger.error('getBudget error', error: e, stackTrace: stackTrace, tag: 'BudgetService');
      rethrow;
    }
  }

  /// Stream of budgets for real-time updates
  Stream<List<Budget>> watchBudgets({bool activeOnly = false}) {
    return _familyId.then((familyId) {
      if (familyId == null) {
        return Stream.value(<Budget>[]);
      }

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets');
      Query query = _firestore.collection(collectionPath);

      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      query = query.orderBy('createdAt', descending: true);

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            return Budget.fromJson({
              'id': doc.id,
              ...data,
            });
          } catch (e) {
            Logger.warning('Error parsing budget ${doc.id}', error: e, tag: 'BudgetService');
            return null;
          }
        }).whereType<Budget>().toList();
      });
    }).asStream().asyncExpand((stream) => stream);
  }

  /// Create a new budget
  Future<Budget> createBudget({
    required String name,
    String description = '',
    required BudgetType type,
    String? userId,
    String? projectId,
    required double totalAmount,
    required DateTime startDate,
    required DateTime endDate,
    required String period,
    Map<String, double>? categoryLimits,
    String currency = 'AUD',
    double adherenceThreshold = 5.0, // Default 5% over budget
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    // Validate dates
    if (endDate.isBefore(startDate)) {
      throw ValidationException('End date must be after start date', code: 'invalid-dates');
    }

    // Validate amount
    if (totalAmount <= 0) {
      throw ValidationException('Total amount must be greater than zero', code: 'invalid-amount');
    }

    // Validate type-specific requirements
    if (type == BudgetType.individual && userId == null) {
      throw ValidationException('Individual budget requires userId', code: 'missing-user-id');
    }

    if (type == BudgetType.project && projectId == null) {
      throw ValidationException('Project budget requires projectId', code: 'missing-project-id');
    }

    try {
      final budgetId = _uuid.v4();
      final now = DateTime.now();

      final budget = Budget(
        id: budgetId,
        familyId: familyId,
        name: name,
        description: description,
        type: type,
        userId: userId,
        projectId: projectId,
        totalAmount: totalAmount,
        startDate: startDate,
        endDate: endDate,
        period: period,
        isActive: true,
        createdBy: currentUserId,
        createdAt: now,
        categoryLimits: categoryLimits ?? {},
        currency: currency,
        adherenceThreshold: adherenceThreshold,
        itemCount: 0,
        completedItemCount: 0,
      );

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets');
      await _firestore.collection(collectionPath).doc(budgetId).set(budget.toJson());

      Logger.debug('createBudget: Created budget $budgetId', tag: 'BudgetService');
      return budget;
    } catch (e, stackTrace) {
      Logger.error('createBudget error', error: e, stackTrace: stackTrace, tag: 'BudgetService');
      rethrow;
    }
  }

  /// Update an existing budget
  Future<Budget> updateBudget(Budget budget) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    // Validate dates
    if (budget.endDate.isBefore(budget.startDate)) {
      throw ValidationException('End date must be after start date', code: 'invalid-dates');
    }

    // Validate amount
    if (budget.totalAmount <= 0) {
      throw ValidationException('Total amount must be greater than zero', code: 'invalid-amount');
    }

    try {
      final updatedBudget = budget.copyWith(
        updatedAt: DateTime.now(),
      );

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets');
      await _firestore.collection(collectionPath).doc(budget.id).update(updatedBudget.toJson());

      Logger.debug('updateBudget: Updated budget ${budget.id}', tag: 'BudgetService');
      return updatedBudget;
    } catch (e, stackTrace) {
      Logger.error('updateBudget error', error: e, stackTrace: stackTrace, tag: 'BudgetService');
      rethrow;
    }
  }

  /// Delete a budget
  Future<void> deleteBudget(String budgetId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets');
      await _firestore.collection(collectionPath).doc(budgetId).delete();

      Logger.debug('deleteBudget: Deleted budget $budgetId', tag: 'BudgetService');
    } catch (e, stackTrace) {
      Logger.error('deleteBudget error', error: e, stackTrace: stackTrace, tag: 'BudgetService');
      rethrow;
    }
  }

  /// Archive a budget (set isActive to false)
  Future<void> archiveBudget(String budgetId) async {
    final budget = await getBudget(budgetId);
    if (budget == null) {
      throw NotFoundException('Budget not found', code: 'budget-not-found');
    }

    final updatedBudget = budget.copyWith(isActive: false);
    await updateBudget(updatedBudget);
  }

  /// Activate a budget (set isActive to true)
  Future<void> activateBudget(String budgetId) async {
    final budget = await getBudget(budgetId);
    if (budget == null) {
      throw NotFoundException('Budget not found', code: 'budget-not-found');
    }

    final updatedBudget = budget.copyWith(isActive: true);
    await updateBudget(updatedBudget);
  }
}

