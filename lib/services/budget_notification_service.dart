import '../core/services/logger_service.dart';
import '../models/budget.dart';
import '../services/budget_analytics_service.dart';
import '../services/notification_service.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Service for budget alerts and notifications
class BudgetNotificationService {
  final BudgetAnalyticsService _analyticsService = BudgetAnalyticsService();
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();

  /// Check and send budget alerts
  Future<void> checkAndSendBudgetAlerts(Budget budget) async {
    try {
      final health = await _analyticsService.getBudgetHealth(budget: budget);
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return;

      // Alert if over budget
      if (health.isOverBudget) {
        await _sendOverBudgetAlert(budget, health, userModel);
      }

      // Alert if approaching budget limit (80% used)
      if (health.percentUsed >= 80 && health.percentUsed < 100) {
        await _sendApproachingLimitAlert(budget, health, userModel);
      }

      // Alert if budget period ending soon (7 days)
      if (health.daysRemaining <= 7 && health.daysRemaining > 0) {
        await _sendPeriodEndingAlert(budget, health, userModel);
      }
    } catch (e) {
      Logger.error('Error checking budget alerts', error: e, tag: 'BudgetNotificationService');
    }
  }

  /// Send over budget alert
  Future<void> _sendOverBudgetAlert(
    Budget budget,
    BudgetHealthMetrics health,
    UserModel user,
  ) async {
    try {
      await _notificationService.createNotification(
        userId: user.uid,
        type: 'budget_over_limit',
        title: 'Budget Exceeded',
        message: '${budget.name} has exceeded its limit by \$${(-health.remaining).toStringAsFixed(2)}',
        data: {
          'budgetId': budget.id,
          'budgetName': budget.name,
          'overAmount': -health.remaining,
        },
      );
    } catch (e) {
      Logger.error('Error sending over budget alert', error: e, tag: 'BudgetNotificationService');
    }
  }

  /// Send approaching limit alert
  Future<void> _sendApproachingLimitAlert(
    Budget budget,
    BudgetHealthMetrics health,
    UserModel user,
  ) async {
    try {
      await _notificationService.createNotification(
        userId: user.uid,
        type: 'budget_approaching_limit',
        title: 'Budget Warning',
        message: '${budget.name} is ${health.percentUsed.toStringAsFixed(0)}% used. \$${health.remaining.toStringAsFixed(2)} remaining.',
        data: {
          'budgetId': budget.id,
          'budgetName': budget.name,
          'percentUsed': health.percentUsed,
          'remaining': health.remaining,
        },
      );
    } catch (e) {
      Logger.error('Error sending approaching limit alert', error: e, tag: 'BudgetNotificationService');
    }
  }

  /// Send period ending alert
  Future<void> _sendPeriodEndingAlert(
    Budget budget,
    BudgetHealthMetrics health,
    UserModel user,
  ) async {
    try {
      await _notificationService.createNotification(
        userId: user.uid,
        type: 'budget_period_ending',
        title: 'Budget Period Ending Soon',
        message: '${budget.name} period ends in ${health.daysRemaining} day${health.daysRemaining == 1 ? '' : 's'}.',
        data: {
          'budgetId': budget.id,
          'budgetName': budget.name,
          'daysRemaining': health.daysRemaining,
        },
      );
    } catch (e) {
      Logger.error('Error sending period ending alert', error: e, tag: 'BudgetNotificationService');
    }
  }
}

