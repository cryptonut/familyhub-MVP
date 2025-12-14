import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/coparenting_schedule.dart';
import '../models/schedule_change_request.dart' show ScheduleChangeRequest, ScheduleChangeStatus;
import '../models/coparenting_expense.dart' show CoparentingExpense, ExpenseStatus;
import '../models/hub.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'hub_service.dart';
import 'subscription_service.dart';

/// Service for managing co-parenting hub features
class CoparentingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final HubService _hubService = HubService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final Uuid _uuid = const Uuid();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Create custody schedule
  Future<CustodySchedule> createCustodySchedule({
    required String hubId,
    required String childId,
    required ScheduleType type,
    Map<String, String>? weeklySchedule,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    // Verify hub is co-parenting type
    final hub = await _hubService.getHub(hubId);
    if (hub == null) {
      throw NotFoundException('Hub not found', code: 'hub-not-found');
    }

    if (hub.hubType != HubType.coparenting) {
      throw ValidationException('Hub must be co-parenting type', code: 'invalid-hub-type');
    }

    // Verify user has premium access
    final hasAccess = await _subscriptionService.hasPremiumHubAccess('coparenting');
    if (!hasAccess) {
      throw PermissionException(
        'Premium subscription required for co-parenting hubs',
        code: 'premium-required',
      );
    }

    try {
      final schedule = CustodySchedule(
        id: _uuid.v4(),
        hubId: hubId,
        childId: childId,
        type: type,
        weeklySchedule: weeklySchedule ?? {},
        startDate: startDate,
        endDate: endDate,
        createdAt: DateTime.now(),
        createdBy: currentUserId,
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'custodySchedules'))
          .doc(schedule.id)
          .set(schedule.toJson());

      Logger.info('Custody schedule created: ${schedule.id}', tag: 'CoparentingService');
      return schedule;
    } catch (e) {
      Logger.error('Error creating custody schedule', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Get custody schedule for a child
  Future<CustodySchedule?> getCustodySchedule({
    required String hubId,
    required String childId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'custodySchedules'))
          .where('childId', isEqualTo: childId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return CustodySchedule.fromJson({
        'id': snapshot.docs.first.id,
        ...snapshot.docs.first.data(),
      });
    } catch (e) {
      Logger.error('Error getting custody schedule', error: e, tag: 'CoparentingService');
      return null;
    }
  }

  /// Request schedule change
  Future<ScheduleChangeRequest> requestScheduleChange({
    required String hubId,
    required String childId,
    required DateTime requestedDate,
    String? swapWithDate,
    String? reason,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final request = ScheduleChangeRequest(
        id: _uuid.v4(),
        hubId: hubId,
        childId: childId,
        requestedDate: requestedDate,
        requestedBy: currentUserId,
        swapWithDate: swapWithDate,
        reason: reason,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'scheduleChangeRequests'))
          .doc(request.id)
          .set(request.toJson());

      Logger.info('Schedule change request created: ${request.id}', tag: 'CoparentingService');
      return request;
    } catch (e) {
      Logger.error('Error creating schedule change request', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Approve/reject schedule change request
  Future<void> respondToScheduleChange({
    required String hubId,
    required String requestId,
    required ScheduleChangeStatus status,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'scheduleChangeRequests'))
          .doc(requestId)
          .update({
        'status': status.name,
        'respondedBy': currentUserId,
        'respondedAt': DateTime.now().toIso8601String(),
      });

      Logger.info('Schedule change request responded: $requestId', tag: 'CoparentingService');
    } catch (e) {
      Logger.error('Error responding to schedule change', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Create co-parenting expense
  Future<CoparentingExpense> createExpense({
    required String hubId,
    required String childId,
    required String category,
    required String description,
    required double amount,
    required String paidBy,
    double? splitRatio,
    String? receiptUrl,
    required DateTime expenseDate,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final expense = CoparentingExpense(
        id: _uuid.v4(),
        hubId: hubId,
        childId: childId,
        category: category,
        description: description,
        amount: amount,
        paidBy: paidBy,
        splitRatio: splitRatio ?? 50.0,
        receiptUrl: receiptUrl,
        expenseDate: expenseDate,
        createdAt: DateTime.now(),
        createdBy: currentUserId,
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'expenses'))
          .doc(expense.id)
          .set(expense.toJson());

      Logger.info('Co-parenting expense created: ${expense.id}', tag: 'CoparentingService');
      return expense;
    } catch (e) {
      Logger.error('Error creating expense', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Get expenses for a hub
  Future<List<CoparentingExpense>> getExpenses({
    required String hubId,
    String? childId,
    ExpenseStatus? status,
  }) async {
    try {
      var query = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'expenses'))
          .orderBy('expenseDate', descending: true);

      if (childId != null) {
        query = query.where('childId', isEqualTo: childId);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => CoparentingExpense.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting expenses', error: e, tag: 'CoparentingService');
      return [];
    }
  }

  /// Approve expense
  Future<void> approveExpense({
    required String hubId,
    required String expenseId,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'expenses'))
          .doc(expenseId)
          .update({
        'status': ExpenseStatus.approved.name,
        'approvedBy': currentUserId,
        'approvedAt': DateTime.now().toIso8601String(),
      });

      Logger.info('Expense approved: $expenseId', tag: 'CoparentingService');
    } catch (e) {
      Logger.error('Error approving expense', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Reject expense
  Future<void> rejectExpense({
    required String hubId,
    required String expenseId,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'expenses'))
          .doc(expenseId)
          .update({
        'status': ExpenseStatus.rejected.name,
        'approvedBy': currentUserId,
        'approvedAt': DateTime.now().toIso8601String(),
      });

      Logger.info('Expense rejected: $expenseId', tag: 'CoparentingService');
    } catch (e) {
      Logger.error('Error rejecting expense', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Get pending approvals count
  Future<int> getPendingApprovalsCount(String hubId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'expenses'))
          .where('status', isEqualTo: ExpenseStatus.pending.name)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      Logger.error('Error getting pending approvals count', error: e, tag: 'CoparentingService');
      return 0;
    }
  }
}

