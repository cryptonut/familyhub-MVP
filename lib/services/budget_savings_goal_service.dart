import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/savings_goal.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'budget_transaction_service.dart';
import '../models/budget_transaction.dart';

/// Service for managing savings goals (Premium feature)
class BudgetSavingsGoalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final BudgetTransactionService _transactionService = BudgetTransactionService();
  final Uuid _uuid = const Uuid();

  String? _cachedFamilyId;

  Future<String?> get _familyId async {
    final userModel = await _authService.getCurrentUserModel();
    final freshFamilyId = userModel?.familyId;
    if (_cachedFamilyId != freshFamilyId) {
      Logger.debug('_familyId: FamilyId changed from $_cachedFamilyId to $freshFamilyId', tag: 'BudgetSavingsGoalService');
      _cachedFamilyId = freshFamilyId;
    }
    return _cachedFamilyId;
  }

  void clearFamilyIdCache() {
    Logger.debug('clearFamilyIdCache: Clearing cached familyId', tag: 'BudgetSavingsGoalService');
    _cachedFamilyId = null;
  }

  /// Get all savings goals for a budget
  Future<List<SavingsGoal>> getSavingsGoals({
    required String budgetId,
    bool includeCompleted = true,
  }) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getSavingsGoals: User not part of a family', tag: 'BudgetSavingsGoalService');
      return [];
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/savingsGoals');
      Query query = _firestore.collection(collectionPath);

      if (!includeCompleted) {
        query = query.where('isCompleted', isEqualTo: false);
      }

      query = query.orderBy('targetDate', descending: false);

      final snapshot = await query.get();
      final goals = snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          return SavingsGoal.fromJson({
            'id': doc.id,
            ...data,
          });
        } catch (e) {
          Logger.warning('Error parsing savings goal ${doc.id}', error: e, tag: 'BudgetSavingsGoalService');
          return null;
        }
      }).whereType<SavingsGoal>().toList();

      // Update current amounts from transactions
      for (final goal in goals) {
        final updatedGoal = await _updateGoalProgress(goal);
        final index = goals.indexOf(goal);
        goals[index] = updatedGoal;
      }

      Logger.debug('getSavingsGoals: Loaded ${goals.length} savings goals', tag: 'BudgetSavingsGoalService');
      return goals;
    } catch (e, stackTrace) {
      Logger.error('getSavingsGoals error', error: e, stackTrace: stackTrace, tag: 'BudgetSavingsGoalService');
      return [];
    }
  }

  /// Update goal progress based on transactions
  Future<SavingsGoal> _updateGoalProgress(SavingsGoal goal) async {
    try {
      // Get all income transactions for this budget
      final transactions = await _transactionService.getTransactions(
        budgetId: goal.budgetId,
        type: TransactionType.income,
      );

      // Calculate current amount (simplified - could be more sophisticated)
      // For now, we'll use a simple calculation based on budget balance
      final balance = await _transactionService.getBalance(budgetId: goal.budgetId);
      final currentAmount = balance > 0 ? balance.clamp(0.0, goal.targetAmount) : 0.0;

      final isCompleted = currentAmount >= goal.targetAmount;

      return goal.copyWith(
        currentAmount: currentAmount,
        isCompleted: isCompleted,
        completedAt: isCompleted && goal.completedAt == null ? DateTime.now() : goal.completedAt,
      );
    } catch (e) {
      Logger.error('Error updating goal progress', error: e, tag: 'BudgetSavingsGoalService');
      return goal;
    }
  }

  /// Create a new savings goal
  Future<SavingsGoal> createSavingsGoal({
    required String budgetId,
    required String name,
    String? description,
    required double targetAmount,
    required DateTime targetDate,
    String? icon,
    String color = '#4CAF50',
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    // Validate target date
    if (targetDate.isBefore(DateTime.now())) {
      throw ValidationException('Target date must be in the future', code: 'invalid-date');
    }

    // Validate amount
    if (targetAmount <= 0) {
      throw ValidationException('Target amount must be greater than zero', code: 'invalid-amount');
    }

    try {
      final goalId = _uuid.v4();
      final now = DateTime.now();

      final goal = SavingsGoal(
        id: goalId,
        budgetId: budgetId,
        name: name,
        description: description,
        targetAmount: targetAmount,
        currentAmount: 0.0,
        targetDate: targetDate,
        isCompleted: false,
        createdBy: currentUserId,
        createdAt: now,
        icon: icon,
        color: color,
      );

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/savingsGoals');
      await _firestore.collection(collectionPath).doc(goalId).set(goal.toJson());

      Logger.debug('createSavingsGoal: Created savings goal $goalId', tag: 'BudgetSavingsGoalService');
      return goal;
    } catch (e, stackTrace) {
      Logger.error('createSavingsGoal error', error: e, stackTrace: stackTrace, tag: 'BudgetSavingsGoalService');
      rethrow;
    }
  }

  /// Update a savings goal
  Future<SavingsGoal> updateSavingsGoal(SavingsGoal goal) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final updatedGoal = goal.copyWith(
        updatedAt: DateTime.now(),
      );

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/${goal.budgetId}/savingsGoals');
      await _firestore.collection(collectionPath).doc(goal.id).update(updatedGoal.toJson());

      Logger.debug('updateSavingsGoal: Updated savings goal ${goal.id}', tag: 'BudgetSavingsGoalService');
      return updatedGoal;
    } catch (e, stackTrace) {
      Logger.error('updateSavingsGoal error', error: e, stackTrace: stackTrace, tag: 'BudgetSavingsGoalService');
      rethrow;
    }
  }

  /// Delete a savings goal
  Future<void> deleteSavingsGoal(String budgetId, String goalId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/savingsGoals');
      await _firestore.collection(collectionPath).doc(goalId).delete();

      Logger.debug('deleteSavingsGoal: Deleted savings goal $goalId', tag: 'BudgetSavingsGoalService');
    } catch (e, stackTrace) {
      Logger.error('deleteSavingsGoal error', error: e, stackTrace: stackTrace, tag: 'BudgetSavingsGoalService');
      rethrow;
    }
  }
}

