import '../core/services/logger_service.dart';
import '../models/budget_transaction.dart';
import '../models/shopping_receipt.dart';
import '../models/task.dart';
import 'budget_transaction_service.dart';
import 'shopping_service.dart';
import 'wallet_service.dart';
import 'task_service.dart';

/// Service for syncing transactions from other services (Shopping, Wallet, Tasks)
class BudgetSyncService {
  final BudgetTransactionService _transactionService = BudgetTransactionService();
  final ShoppingService _shoppingService = ShoppingService();
  final WalletService _walletService = WalletService();
  final TaskService _taskService = TaskService();

  /// Sync shopping receipt to budget transaction
  Future<void> syncShoppingReceiptToBudget({
    required String budgetId,
    required ShoppingReceipt receipt,
    String? categoryId,
  }) async {
    try {
      if (receipt.totalAmount == null || receipt.totalAmount! <= 0) {
        Logger.warning('Receipt has no valid total amount', tag: 'BudgetSyncService');
        return;
      }

      // Check if transaction already exists for this receipt
      final existingTransactions = await _transactionService.getTransactions(
        budgetId: budgetId,
        startDate: receipt.purchaseDate ?? receipt.createdAt,
        endDate: receipt.purchaseDate ?? receipt.createdAt,
      );

      final alreadySynced = existingTransactions.any(
        (t) => t.sourceId == receipt.id && t.source == 'shopping',
      );

      if (alreadySynced) {
        Logger.debug('Receipt already synced to budget', tag: 'BudgetSyncService');
        return;
      }

      await _transactionService.createTransaction(
        budgetId: budgetId,
        categoryId: categoryId,
        type: TransactionType.expense,
        amount: receipt.totalAmount!,
        description: receipt.storeName ?? 'Shopping Receipt',
        date: receipt.purchaseDate ?? receipt.createdAt,
        receiptUrl: receipt.imageUrl,
        receiptId: receipt.id,
        source: 'shopping',
        sourceId: receipt.id,
        metadata: {
          'listId': receipt.listId,
          'storeName': receipt.storeName,
        },
      );

      Logger.info('Synced shopping receipt to budget', tag: 'BudgetSyncService');
    } catch (e) {
      Logger.error('Error syncing shopping receipt', error: e, tag: 'BudgetSyncService');
      rethrow;
    }
  }

  /// Sync wallet payout to budget transaction (income)
  Future<void> syncWalletPayoutToBudget({
    required String budgetId,
    required double amount,
    required DateTime date,
    required String userId,
    String? categoryId,
  }) async {
    try {
      await _transactionService.createTransaction(
        budgetId: budgetId,
        categoryId: categoryId,
        type: TransactionType.income,
        amount: amount,
        description: 'Wallet Payout',
        date: date,
        source: 'wallet',
        userId: userId,
        metadata: {
          'type': 'payout',
        },
      );

      Logger.info('Synced wallet payout to budget', tag: 'BudgetSyncService');
    } catch (e) {
      Logger.error('Error syncing wallet payout', error: e, tag: 'BudgetSyncService');
      rethrow;
    }
  }

  /// Sync task reward to budget transaction (income)
  Future<void> syncTaskRewardToBudget({
    required String budgetId,
    required Task task,
    String? categoryId,
  }) async {
    try {
      if (task.reward == null || task.reward! <= 0 || !task.isCompleted) {
        return;
      }

      // Check if transaction already exists
      final existingTransactions = await _transactionService.getTransactions(
        budgetId: budgetId,
        startDate: task.completedAt ?? task.createdAt,
        endDate: task.completedAt ?? task.createdAt,
      );

      final alreadySynced = existingTransactions.any(
        (t) => t.sourceId == task.id && t.source == 'task',
      );

      if (alreadySynced) {
        return;
      }

      await _transactionService.createTransaction(
        budgetId: budgetId,
        categoryId: categoryId,
        type: TransactionType.income,
        amount: task.reward!,
        description: 'Task Reward: ${task.title}',
        date: task.completedAt ?? task.createdAt,
        source: 'task',
        sourceId: task.id,
        userId: task.claimedBy ?? task.assignedTo,
        metadata: {
          'taskId': task.id,
          'taskTitle': task.title,
        },
      );

      Logger.info('Synced task reward to budget', tag: 'BudgetSyncService');
    } catch (e) {
      Logger.error('Error syncing task reward', error: e, tag: 'BudgetSyncService');
      rethrow;
    }
  }

  /// Auto-sync all recent shopping receipts for a budget
  Future<void> autoSyncShoppingReceipts({
    required String budgetId,
    DateTime? since,
  }) async {
    try {
      final receipts = await _shoppingService.getReceipts();
      final receiptsToSync = since != null
          ? receipts.where((r) => r.createdAt.isAfter(since)).toList()
          : receipts;

      for (final receipt in receiptsToSync) {
        if (receipt.totalAmount != null && receipt.totalAmount! > 0) {
          await syncShoppingReceiptToBudget(
            budgetId: budgetId,
            receipt: receipt,
          );
        }
      }

      Logger.info('Auto-synced ${receiptsToSync.length} shopping receipts', tag: 'BudgetSyncService');
    } catch (e) {
      Logger.error('Error auto-syncing shopping receipts', error: e, tag: 'BudgetSyncService');
      rethrow;
    }
  }
}

