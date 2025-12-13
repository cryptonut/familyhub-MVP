import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/budget_transaction.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'budget_item_service.dart';

/// Service for managing budget transactions
class BudgetTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  String? _cachedFamilyId;

  Future<String?> get _familyId async {
    final userModel = await _authService.getCurrentUserModel();
    final freshFamilyId = userModel?.familyId;
    if (_cachedFamilyId != freshFamilyId) {
      Logger.debug('_familyId: FamilyId changed from $_cachedFamilyId to $freshFamilyId', tag: 'BudgetTransactionService');
      _cachedFamilyId = freshFamilyId;
    }
    return _cachedFamilyId;
  }

  void clearFamilyIdCache() {
    Logger.debug('clearFamilyIdCache: Clearing cached familyId', tag: 'BudgetTransactionService');
    _cachedFamilyId = null;
  }

  /// Get all transactions for a budget
  Future<List<BudgetTransaction>> getTransactions({
    required String budgetId,
    String? itemId, // Filter by item
    String? categoryId,
    TransactionType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getTransactions: User not part of a family', tag: 'BudgetTransactionService');
      return [];
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/transactions');
      Query query = _firestore.collection(collectionPath);

      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      query = query.orderBy('date', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final transactions = snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          return BudgetTransaction.fromJson({
            'id': doc.id,
            ...data,
          });
        } catch (e) {
          Logger.warning('Error parsing transaction ${doc.id}', error: e, tag: 'BudgetTransactionService');
          return null;
        }
      }).whereType<BudgetTransaction>().toList();

      Logger.debug('getTransactions: Loaded ${transactions.length} transactions', tag: 'BudgetTransactionService');
      return transactions;
    } catch (e, stackTrace) {
      Logger.error('getTransactions error', error: e, stackTrace: stackTrace, tag: 'BudgetTransactionService');
      return [];
    }
  }

  /// Get a single transaction by ID
  Future<BudgetTransaction?> getTransaction(String budgetId, String transactionId) async {
    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/transactions');
      final doc = await _firestore.collection(collectionPath).doc(transactionId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      return BudgetTransaction.fromJson({
        'id': doc.id,
        ...data,
      });
    } catch (e, stackTrace) {
      Logger.error('getTransaction error', error: e, stackTrace: stackTrace, tag: 'BudgetTransactionService');
      rethrow;
    }
  }

  /// Stream of transactions for real-time updates
  Stream<List<BudgetTransaction>> watchTransactions({
    required String budgetId,
    String? itemId, // Filter by item
    String? categoryId,
    TransactionType? type,
  }) {
    return _familyId.then((familyId) {
      if (familyId == null) {
        return Stream.value(<BudgetTransaction>[]);
      }

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/transactions');
      Query query = _firestore.collection(collectionPath);

      if (itemId != null) {
        query = query.where('itemId', isEqualTo: itemId);
      }

      if (categoryId != null) {
        query = query.where('categoryId', isEqualTo: categoryId);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      query = query.orderBy('date', descending: true);

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            return BudgetTransaction.fromJson({
              'id': doc.id,
              ...data,
            });
          } catch (e) {
            Logger.warning('Error parsing transaction ${doc.id}', error: e, tag: 'BudgetTransactionService');
            return null;
          }
        }).whereType<BudgetTransaction>().toList();
      });
    }).asStream().asyncExpand((stream) => stream);
  }

  /// Create a new transaction (requires itemId)
  Future<BudgetTransaction> createTransaction({
    required String budgetId,
    required String itemId, // REQUIRED: Every transaction must be linked to a budget item
    String? categoryId,
    required TransactionType type,
    required double amount,
    required String description,
    required DateTime date,
    String? userId,
    String? receiptUrl,
    String? receiptId,
    String source = 'manual',
    String? sourceId,
    bool isRecurring = false,
    String? recurringTransactionId,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    // Validate amount
    if (amount <= 0) {
      throw ValidationException('Amount must be greater than zero', code: 'invalid-amount');
    }

    try {
      final transactionId = _uuid.v4();
      final now = DateTime.now();

      // Validate itemId exists
      final budgetItemService = BudgetItemService();
      final item = await budgetItemService.getItem(budgetId, itemId);
      if (item == null) {
        throw NotFoundException('Budget item not found', code: 'item-not-found');
      }

      final transaction = BudgetTransaction(
        id: transactionId,
        budgetId: budgetId,
        itemId: itemId,
        categoryId: categoryId,
        type: type,
        amount: amount,
        description: description,
        date: date,
        userId: userId ?? currentUserId,
        receiptUrl: receiptUrl,
        receiptId: receiptId,
        source: source,
        sourceId: sourceId,
        isRecurring: isRecurring,
        recurringTransactionId: recurringTransactionId,
        createdBy: currentUserId,
        createdAt: now,
        metadata: metadata,
      );

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/transactions');
      await _firestore.collection(collectionPath).doc(transactionId).set(transaction.toJson());

      Logger.debug('createTransaction: Created transaction $transactionId', tag: 'BudgetTransactionService');
      return transaction;
    } catch (e, stackTrace) {
      Logger.error('createTransaction error', error: e, stackTrace: stackTrace, tag: 'BudgetTransactionService');
      rethrow;
    }
  }

  /// Update an existing transaction
  Future<BudgetTransaction> updateTransaction(BudgetTransaction transaction) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    // Validate amount
    if (transaction.amount <= 0) {
      throw ValidationException('Amount must be greater than zero', code: 'invalid-amount');
    }

    try {
      final updatedTransaction = transaction.copyWith(
        updatedAt: DateTime.now(),
      );

      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/${transaction.budgetId}/transactions');
      await _firestore.collection(collectionPath).doc(transaction.id).update(updatedTransaction.toJson());

      Logger.debug('updateTransaction: Updated transaction ${transaction.id}', tag: 'BudgetTransactionService');
      return updatedTransaction;
    } catch (e, stackTrace) {
      Logger.error('updateTransaction error', error: e, stackTrace: stackTrace, tag: 'BudgetTransactionService');
      rethrow;
    }
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String budgetId, String transactionId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets/$budgetId/transactions');
      await _firestore.collection(collectionPath).doc(transactionId).delete();

      Logger.debug('deleteTransaction: Deleted transaction $transactionId', tag: 'BudgetTransactionService');
    } catch (e, stackTrace) {
      Logger.error('deleteTransaction error', error: e, stackTrace: stackTrace, tag: 'BudgetTransactionService');
      rethrow;
    }
  }

  /// Calculate total income for a budget in a date range
  Future<double> getTotalIncome({
    required String budgetId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final transactions = await getTransactions(
      budgetId: budgetId,
      type: TransactionType.income,
      startDate: startDate,
      endDate: endDate,
    );

    return transactions.fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
  }

  /// Calculate total expenses for a budget in a date range
  Future<double> getTotalExpenses({
    required String budgetId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final transactions = await getTransactions(
      budgetId: budgetId,
      type: TransactionType.expense,
      startDate: startDate,
      endDate: endDate,
    );

    return transactions.fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
  }

  /// Calculate balance (income - expenses) for a budget in a date range
  Future<double> getBalance({
    required String budgetId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final income = await getTotalIncome(budgetId: budgetId, startDate: startDate, endDate: endDate);
    final expenses = await getTotalExpenses(budgetId: budgetId, startDate: startDate, endDate: endDate);
    return income - expenses;
  }
}

