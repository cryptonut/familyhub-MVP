import '../core/services/logger_service.dart';
import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../models/budget_category.dart';
import '../models/budget_item.dart';
import 'budget_transaction_service.dart';
import 'budget_category_service.dart';
import 'budget_item_service.dart';

/// Service for budget analytics and insights
class BudgetAnalyticsService {
  final BudgetTransactionService _transactionService = BudgetTransactionService();
  final BudgetCategoryService _categoryService = BudgetCategoryService();
  final BudgetItemService _itemService = BudgetItemService();

  /// Get spending by category for a budget
  Future<Map<String, double>> getSpendingByCategory({
    required String budgetId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final transactions = await _transactionService.getTransactions(
        budgetId: budgetId,
        type: TransactionType.expense,
        startDate: startDate,
        endDate: endDate,
      );

      final spendingByCategory = <String, double>{};
      for (final transaction in transactions) {
        final categoryId = transaction.categoryId ?? 'uncategorized';
        spendingByCategory[categoryId] =
            (spendingByCategory[categoryId] ?? 0.0) + transaction.amount;
      }

      return spendingByCategory;
    } catch (e) {
      Logger.error('Error getting spending by category', error: e, tag: 'BudgetAnalyticsService');
      return {};
    }
  }

  /// Get spending trends over time
  Future<Map<DateTime, double>> getSpendingTrends({
    required String budgetId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final transactions = await _transactionService.getTransactions(
        budgetId: budgetId,
        type: TransactionType.expense,
        startDate: startDate,
        endDate: endDate,
      );

      final trends = <DateTime, double>{};
      for (final transaction in transactions) {
        // Group by day
        final day = DateTime(
          transaction.date.year,
          transaction.date.month,
          transaction.date.day,
        );
        trends[day] = (trends[day] ?? 0.0) + transaction.amount;
      }

      return trends;
    } catch (e) {
      Logger.error('Error getting spending trends', error: e, tag: 'BudgetAnalyticsService');
      return {};
    }
  }

  /// Get category breakdown with percentages
  Future<List<CategorySpending>> getCategoryBreakdown({
    required String budgetId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final spendingByCategory = await getSpendingByCategory(
        budgetId: budgetId,
        startDate: startDate,
        endDate: endDate,
      );

      final totalSpending = spendingByCategory.values.fold(0.0, (sum, amount) => sum + amount);
      final categories = await _categoryService.getCategories(budgetId: budgetId);
      final categoryMap = {for (var c in categories) c.id: c};

      final breakdown = <CategorySpending>[];
      for (final entry in spendingByCategory.entries) {
        final category = categoryMap[entry.key];
        final percentage = totalSpending > 0
            ? (entry.value / totalSpending * 100)
            : 0.0;

        breakdown.add(CategorySpending(
          categoryId: entry.key,
          categoryName: category?.name ?? 'Uncategorized',
          amount: entry.value,
          percentage: percentage,
          color: category?.color ?? '#9E9E9E',
          icon: category?.icon,
        ));
      }

      breakdown.sort((a, b) => b.amount.compareTo(a.amount));
      return breakdown;
    } catch (e) {
      Logger.error('Error getting category breakdown', error: e, tag: 'BudgetAnalyticsService');
      return [];
    }
  }

  /// Get budget health metrics
  Future<BudgetHealthMetrics> getBudgetHealth({
    required Budget budget,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final expenses = await _transactionService.getTotalExpenses(
        budgetId: budget.id,
        startDate: startDate ?? budget.startDate,
        endDate: endDate ?? budget.endDate,
      );

      final income = await _transactionService.getTotalIncome(
        budgetId: budget.id,
        startDate: startDate ?? budget.startDate,
        endDate: endDate ?? budget.endDate,
      );

      final remaining = budget.totalAmount - expenses;
      final percentUsed = budget.totalAmount > 0
          ? (expenses / budget.totalAmount * 100)
          : 0.0;
      final savingsRate = income > 0 ? ((income - expenses) / income * 100) : 0.0;

      return BudgetHealthMetrics(
        totalBudget: budget.totalAmount,
        spent: expenses,
        remaining: remaining,
        percentUsed: percentUsed,
        income: income,
        balance: income - expenses,
        savingsRate: savingsRate,
        isOverBudget: expenses > budget.totalAmount,
        daysRemaining: budget.endDate.difference(DateTime.now()).inDays,
      );
    } catch (e) {
      Logger.error('Error getting budget health', error: e, tag: 'BudgetAnalyticsService');
      rethrow;
    }
  }

  /// Get progress metrics for a budget (items and dollars)
  Future<BudgetProgressMetrics> getProgressMetrics({
    required Budget budget,
    bool isPremium = false,
  }) async {
    try {
      final items = await _itemService.getItems(budget.id);
      final completedItems = items.where((i) => i.status == BudgetItemStatus.complete).toList();
      
      // Item-based progress
      final itemProgress = items.isEmpty 
          ? 0.0 
          : (completedItems.length / items.length * 100);
      
      // Dollar-based progress (sum of actual amounts vs total estimated)
      final totalEstimated = items.fold<double>(0.0, (sum, item) => sum + item.estimatedAmount);
      final totalActual = completedItems.fold<double>(
        0.0, 
        (sum, item) => sum + (item.actualAmount ?? 0.0),
      );
      final dollarProgress = totalEstimated > 0 
          ? (totalActual / totalEstimated * 100)
          : 0.0;
      
      // Budget-level adherence - check if estimated amounts exceed budget
      final budgetAdherence = _calculateBudgetAdherence(
        totalEstimated: totalEstimated,
        totalActual: totalActual,
        budgetTotal: budget.totalAmount,
        threshold: budget.adherenceThreshold,
      );
      
      return BudgetProgressMetrics(
        itemProgress: itemProgress,
        dollarProgress: dollarProgress,
        totalItems: items.length,
        completedItems: completedItems.length,
        totalEstimated: totalEstimated,
        totalActual: totalActual,
        budgetAdherence: budgetAdherence,
        isPremium: isPremium,
      );
    } catch (e) {
      Logger.error('Error getting progress metrics', error: e, tag: 'BudgetAnalyticsService');
      rethrow;
    }
  }

  /// Calculate budget-level adherence status
  /// Checks both: (1) if estimated amounts exceed budget, (2) if actual spending exceeds estimated
  BudgetAdherenceStatus _calculateBudgetAdherence({
    required double totalEstimated,
    required double totalActual,
    required double budgetTotal,
    required double threshold,
  }) {
    // CRITICAL: If cumulative estimated amounts exceed budget total, show warning
    if (totalEstimated > budgetTotal) {
      return BudgetAdherenceStatus.warning;
    }
    
    // If no estimated amounts, consider on track
    if (totalEstimated == 0) return BudgetAdherenceStatus.onTrack;
    
    // Check if actual spending exceeds estimated amounts
    final percentage = ((totalActual - totalEstimated) / totalEstimated) * 100;
    
    if (percentage <= 0) {
      return BudgetAdherenceStatus.onTrack;
    } else if (percentage <= threshold) {
      return BudgetAdherenceStatus.warning;
    } else {
      return BudgetAdherenceStatus.overBudget;
    }
  }
}

class CategorySpending {
  final String categoryId;
  final String categoryName;
  final double amount;
  final double percentage;
  final String color;
  final String? icon;

  CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.percentage,
    required this.color,
    this.icon,
  });
}

class BudgetHealthMetrics {
  final double totalBudget;
  final double spent;
  final double remaining;
  final double percentUsed;
  final double income;
  final double balance;
  final double savingsRate;
  final bool isOverBudget;
  final int daysRemaining;

  BudgetHealthMetrics({
    required this.totalBudget,
    required this.spent,
    required this.remaining,
    required this.percentUsed,
    required this.income,
    required this.balance,
    required this.savingsRate,
    required this.isOverBudget,
    required this.daysRemaining,
  });
}

class BudgetProgressMetrics {
  final double itemProgress; // Percentage of items completed
  final double dollarProgress; // Percentage of budget spent (actual vs estimated)
  final int totalItems;
  final int completedItems;
  final double totalEstimated;
  final double totalActual;
  final BudgetAdherenceStatus budgetAdherence;
  final bool isPremium;

  BudgetProgressMetrics({
    required this.itemProgress,
    required this.dollarProgress,
    required this.totalItems,
    required this.completedItems,
    required this.totalEstimated,
    required this.totalActual,
    required this.budgetAdherence,
    required this.isPremium,
  });
}

