import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/recurring_transaction.dart';
import '../models/budget_transaction.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'budget_transaction_service.dart';
import 'subscription_service.dart';

/// Service for managing recurring budget transactions
class RecurringTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final BudgetTransactionService _transactionService = BudgetTransactionService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final Uuid _uuid = const Uuid();

  String? _cachedFamilyId;

  Future<String?> get _familyId async {
    final userModel = await _authService.getCurrentUserModel();
    final freshFamilyId = userModel?.familyId;
    if (_cachedFamilyId != freshFamilyId) {
      Logger.debug('_familyId: FamilyId changed from $_cachedFamilyId to $freshFamilyId', tag: 'RecurringTransactionService');
      _cachedFamilyId = freshFamilyId;
    }
    return _cachedFamilyId;
  }

  void clearFamilyIdCache() {
    Logger.debug('clearFamilyIdCache: Clearing cached familyId', tag: 'RecurringTransactionService');
    _cachedFamilyId = null;
  }

  /// Get all recurring transactions for a budget
  Future<List<RecurringTransaction>> getRecurringTransactions({
    required String budgetId,
    bool activeOnly = false,
  }) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getRecurringTransactions: User not part of a family', tag: 'RecurringTransactionService');
      return [];
    }

    try {
      final collectionPath = FirestorePathUtils.getBudgetSubcollectionPath(familyId, budgetId, 'recurringTransactions');
      Query query = _firestore.collection(collectionPath);
      
      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.orderBy('createdAt', descending: true).get();
      
      return snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          return RecurringTransaction.fromJson({'id': doc.id, ...data});
        } catch (e) {
          Logger.warning('Error parsing recurring transaction ${doc.id}', error: e, tag: 'RecurringTransactionService');
          return null;
        }
      }).whereType<RecurringTransaction>().toList();
    } catch (e, st) {
      Logger.error('getRecurringTransactions error', error: e, stackTrace: st, tag: 'RecurringTransactionService');
      return [];
    }
  }

  /// Stream recurring transactions for a budget
  Stream<List<RecurringTransaction>> streamRecurringTransactions({
    required String budgetId,
    bool activeOnly = false,
  }) {
    return Stream.fromFuture(_familyId).asyncExpand((familyId) {
      if (familyId == null) {
        return Stream.value(<RecurringTransaction>[]);
      }

      final collectionPath = FirestorePathUtils.getBudgetSubcollectionPath(familyId, budgetId, 'recurringTransactions');
      Query query = _firestore.collection(collectionPath);
      
      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      return query.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            return RecurringTransaction.fromJson({'id': doc.id, ...data});
          } catch (e) {
            Logger.warning('Error parsing recurring transaction ${doc.id}', error: e, tag: 'RecurringTransactionService');
            return null;
          }
        }).whereType<RecurringTransaction>().toList();
      });
    });
  }

  /// Create a recurring transaction
  Future<RecurringTransaction> createRecurringTransaction({
    required String budgetId,
    required String itemId,
    String? categoryId,
    required TransactionType type,
    required double amount,
    required String description,
    required RecurringFrequency frequency,
    required DateTime startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    // Check free tier limit (5 max recurring transactions)
    final hasPremium = await _subscriptionService.hasActiveSubscription();
    if (!hasPremium) {
      final existing = await getRecurringTransactions(budgetId: budgetId);
      if (existing.length >= 5) {
        throw ValidationException(
          'Free tier limit reached. Upgrade to Premium for unlimited recurring transactions.',
          code: 'free-tier-limit',
        );
      }
    }

    // Validate amount
    if (amount <= 0) {
      throw ValidationException('Amount must be greater than zero', code: 'invalid-amount');
    }

    // Validate dates
    if (endDate != null && endDate.isBefore(startDate)) {
      throw ValidationException('End date must be after start date', code: 'invalid-date');
    }

    try {
      final recurringId = _uuid.v4();
      final nextOccurrence = startDate.isBefore(DateTime.now()) || 
                            startDate.isAtSameMomentAs(DateTime.now())
          ? _calculateNextOccurrence(startDate, frequency)
          : startDate;

      final recurring = RecurringTransaction(
        id: recurringId,
        budgetId: budgetId,
        itemId: itemId,
        categoryId: categoryId,
        type: type,
        amount: amount,
        description: description,
        frequency: frequency,
        startDate: startDate,
        endDate: endDate,
        nextOccurrence: nextOccurrence,
        isActive: true,
        userId: userId ?? currentUserId,
        createdBy: currentUserId,
        createdAt: DateTime.now(),
      );

      final collectionPath = FirestorePathUtils.getBudgetSubcollectionPath(familyId, budgetId, 'recurringTransactions');
      await _firestore.collection(collectionPath).doc(recurringId).set(recurring.toJson());

      Logger.info('createRecurringTransaction: Created recurring transaction $recurringId', tag: 'RecurringTransactionService');
      return recurring;
    } catch (e) {
      Logger.error('createRecurringTransaction error', error: e, tag: 'RecurringTransactionService');
      rethrow;
    }
  }

  /// Update a recurring transaction
  Future<void> updateRecurringTransaction({
    required String budgetId,
    required String recurringId,
    String? itemId,
    String? categoryId,
    TransactionType? type,
    double? amount,
    String? description,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? userId,
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
      final collectionPath = FirestorePathUtils.getBudgetSubcollectionPath(familyId, budgetId, 'recurringTransactions');
      final docRef = _firestore.collection(collectionPath).doc(recurringId);
      final doc = await docRef.get();

      if (!doc.exists) {
        throw NotFoundException('Recurring transaction not found', code: 'not-found');
      }

      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (itemId != null) updateData['itemId'] = itemId;
      if (categoryId != null) updateData['categoryId'] = categoryId;
      if (type != null) updateData['type'] = type.name;
      if (amount != null) updateData['amount'] = amount;
      if (description != null) updateData['description'] = description;
      if (frequency != null) {
        updateData['frequency'] = frequency.name;
        // Recalculate next occurrence if frequency changed
        final existing = RecurringTransaction.fromJson({'id': doc.id, ...doc.data()!});
        final newNextOccurrence = _calculateNextOccurrence(
          existing.nextOccurrence ?? existing.startDate,
          frequency,
        );
        updateData['nextOccurrence'] = Timestamp.fromDate(newNextOccurrence);
      }
      if (startDate != null) {
        updateData['startDate'] = Timestamp.fromDate(startDate);
        // Recalculate next occurrence
        final existing = RecurringTransaction.fromJson({'id': doc.id, ...doc.data()!});
        final newNextOccurrence = _calculateNextOccurrence(startDate, existing.frequency);
        updateData['nextOccurrence'] = Timestamp.fromDate(newNextOccurrence);
      }
      if (endDate != null) updateData['endDate'] = Timestamp.fromDate(endDate);
      if (isActive != null) updateData['isActive'] = isActive;
      if (userId != null) updateData['userId'] = userId;

      await docRef.update(updateData);
      Logger.info('updateRecurringTransaction: Updated recurring transaction $recurringId', tag: 'RecurringTransactionService');
    } catch (e) {
      Logger.error('updateRecurringTransaction error', error: e, tag: 'RecurringTransactionService');
      rethrow;
    }
  }

  /// Delete a recurring transaction
  Future<void> deleteRecurringTransaction({
    required String budgetId,
    required String recurringId,
  }) async {
    final familyId = await _familyId;
    if (familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    try {
      final collectionPath = FirestorePathUtils.getBudgetSubcollectionPath(familyId, budgetId, 'recurringTransactions');
      await _firestore.collection(collectionPath).doc(recurringId).delete();
      Logger.info('deleteRecurringTransaction: Deleted recurring transaction $recurringId', tag: 'RecurringTransactionService');
    } catch (e) {
      Logger.error('deleteRecurringTransaction error', error: e, tag: 'RecurringTransactionService');
      rethrow;
    }
  }

  /// Process recurring transactions (create actual transactions for due items)
  /// This should be called periodically (e.g., daily via background job)
  Future<void> processRecurringTransactions({String? budgetId}) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('processRecurringTransactions: User not part of a family', tag: 'RecurringTransactionService');
      return;
    }

    try {
      // Get all active recurring transactions
      final budgets = budgetId != null ? [budgetId] : await _getAllBudgets(familyId);
      final now = DateTime.now();

      for (final budgetId in budgets) {
        final recurringTransactions = await getRecurringTransactions(budgetId: budgetId, activeOnly: true);
        
        for (final recurring in recurringTransactions) {
          if (!recurring.shouldProcessToday()) continue;
          if (recurring.endDate != null && now.isAfter(recurring.endDate!)) {
            // End date reached, deactivate
            await updateRecurringTransaction(
              budgetId: budgetId,
              recurringId: recurring.id,
              isActive: false,
            );
            continue;
          }

          // Check if transaction already exists for this occurrence
          final occurrenceDate = recurring.nextOccurrence ?? recurring.startDate;
          final existingTransactions = await _transactionService.getTransactions(
            budgetId: budgetId,
            startDate: DateTime(occurrenceDate.year, occurrenceDate.month, occurrenceDate.day),
            endDate: DateTime(occurrenceDate.year, occurrenceDate.month, occurrenceDate.day, 23, 59, 59),
          );

          // Check if a transaction with this recurringTransactionId already exists for today
          final alreadyProcessed = existingTransactions.any(
            (t) => t.recurringTransactionId == recurring.id &&
                   t.date.year == occurrenceDate.year &&
                   t.date.month == occurrenceDate.month &&
                   t.date.day == occurrenceDate.day,
          );

          if (alreadyProcessed) {
            // Already processed, just update next occurrence
            final nextOccurrence = recurring.calculateNextOccurrence(fromDate: occurrenceDate);
            final collectionPath = FirestorePathUtils.getBudgetSubcollectionPath(familyId, budgetId, 'recurringTransactions');
            await _firestore.collection(collectionPath).doc(recurring.id).update({
              'nextOccurrence': Timestamp.fromDate(nextOccurrence),
            });
            continue;
          }

          // Create the transaction
          await _transactionService.createTransaction(
            budgetId: budgetId,
            itemId: recurring.itemId,
            categoryId: recurring.categoryId,
            type: recurring.type,
            amount: recurring.amount,
            description: recurring.description,
            date: occurrenceDate,
            userId: recurring.userId,
            source: 'recurring',
            sourceId: recurring.id,
            isRecurring: true,
            recurringTransactionId: recurring.id,
          );

          // Update next occurrence
          final nextOccurrence = recurring.calculateNextOccurrence(fromDate: occurrenceDate);
          final collectionPath = FirestorePathUtils.getBudgetSubcollectionPath(familyId, budgetId, 'recurringTransactions');
          await _firestore.collection(collectionPath).doc(recurring.id).update({
            'nextOccurrence': Timestamp.fromDate(nextOccurrence),
          });

          Logger.info('processRecurringTransactions: Created transaction from recurring ${recurring.id}', tag: 'RecurringTransactionService');
        }
      }
    } catch (e, st) {
      Logger.error('processRecurringTransactions error', error: e, stackTrace: st, tag: 'RecurringTransactionService');
    }
  }

  /// Helper to calculate next occurrence date
  DateTime _calculateNextOccurrence(DateTime fromDate, RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return fromDate.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return fromDate.add(const Duration(days: 7));
      case RecurringFrequency.biweekly:
        return fromDate.add(const Duration(days: 14));
      case RecurringFrequency.monthly:
        return DateTime(fromDate.year, fromDate.month + 1, fromDate.day);
      case RecurringFrequency.quarterly:
        return DateTime(fromDate.year, fromDate.month + 3, fromDate.day);
      case RecurringFrequency.yearly:
        return DateTime(fromDate.year + 1, fromDate.month, fromDate.day);
    }
  }

  /// Helper to get all budget IDs for a family
  Future<List<String>> _getAllBudgets(String familyId) async {
    try {
      final budgetsPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'budgets');
      final snapshot = await _firestore.collection(budgetsPath).get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      Logger.warning('Error getting budgets', error: e, tag: 'RecurringTransactionService');
      return [];
    }
  }
}

