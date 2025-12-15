import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/coparenting_schedule.dart';
import '../models/schedule_change_request.dart' show ScheduleChangeRequest, ScheduleChangeStatus;
import '../models/coparenting_expense.dart' show CoparentingExpense, ExpenseStatus;
import '../models/coparenting_message_template.dart';
import '../models/child_profile.dart';
import '../models/hub.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'hub_service.dart';
import 'subscription_service.dart';

/// Service for managing co-parenting hub features
class CoparentingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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

  /// Get all custody schedules for a hub
  Future<List<CustodySchedule>> getCustodySchedules(String hubId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'custodySchedules'))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => CustodySchedule.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting custody schedules', error: e, tag: 'CoparentingService');
      return [];
    }
  }

  /// Update custody schedule
  Future<void> updateCustodySchedule({
    required String hubId,
    required String scheduleId,
    ScheduleType? type,
    Map<String, String>? weeklySchedule,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final updates = <String, dynamic>{};
      if (type != null) updates['type'] = type.name;
      if (weeklySchedule != null) updates['weeklySchedule'] = weeklySchedule;
      if (startDate != null) updates['startDate'] = startDate.toIso8601String();
      if (endDate != null) updates['endDate'] = endDate.toIso8601String();

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'custodySchedules'))
          .doc(scheduleId)
          .update(updates);

      Logger.info('Custody schedule updated: $scheduleId', tag: 'CoparentingService');
    } catch (e) {
      Logger.error('Error updating custody schedule', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Add exception to custody schedule
  Future<void> addScheduleException({
    required String hubId,
    required String scheduleId,
    required ScheduleException exception,
  }) async {
    try {
      final scheduleDoc = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'custodySchedules'))
          .doc(scheduleId)
          .get();

      if (!scheduleDoc.exists) {
        throw NotFoundException('Schedule not found', code: 'schedule-not-found');
      }

      final schedule = CustodySchedule.fromJson({
        'id': scheduleDoc.id,
        ...scheduleDoc.data()!,
      });

      final updatedExceptions = List<ScheduleException>.from(schedule.exceptions)..add(exception);

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'custodySchedules'))
          .doc(scheduleId)
          .update({
        'exceptions': updatedExceptions.map((e) => e.toJson()).toList(),
      });

      Logger.info('Exception added to schedule: $scheduleId', tag: 'CoparentingService');
    } catch (e) {
      Logger.error('Error adding schedule exception', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Delete custody schedule
  Future<void> deleteCustodySchedule({
    required String hubId,
    required String scheduleId,
  }) async {
    try {
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'custodySchedules'))
          .doc(scheduleId)
          .delete();

      Logger.info('Custody schedule deleted: $scheduleId', tag: 'CoparentingService');
    } catch (e) {
      Logger.error('Error deleting custody schedule', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Get all schedule change requests for a hub
  Future<List<ScheduleChangeRequest>> getScheduleChangeRequests({
    required String hubId,
    String? childId,
    ScheduleChangeStatus? status,
  }) async {
    try {
      var query = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'scheduleChangeRequests'))
          .orderBy('createdAt', descending: true);

      if (childId != null) {
        query = query.where('childId', isEqualTo: childId);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => ScheduleChangeRequest.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting schedule change requests', error: e, tag: 'CoparentingService');
      return [];
    }
  }

  /// Get pending schedule change requests count
  Future<int> getPendingScheduleChangeRequestsCount(String hubId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'scheduleChangeRequests'))
          .where('status', isEqualTo: ScheduleChangeStatus.pending.name)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      Logger.error('Error getting pending schedule change requests count', error: e, tag: 'CoparentingService');
      return 0;
    }
  }

  /// Get expense by ID
  Future<CoparentingExpense?> getExpense({
    required String hubId,
    required String expenseId,
  }) async {
    try {
      final doc = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'expenses'))
          .doc(expenseId)
          .get();

      if (!doc.exists) return null;

      return CoparentingExpense.fromJson({
        'id': doc.id,
        ...doc.data()!,
      });
    } catch (e) {
      Logger.error('Error getting expense', error: e, tag: 'CoparentingService');
      return null;
    }
  }

  /// Mark expense as paid
  Future<void> markExpenseAsPaid({
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
        'status': ExpenseStatus.paid.name,
      });

      Logger.info('Expense marked as paid: $expenseId', tag: 'CoparentingService');
    } catch (e) {
      Logger.error('Error marking expense as paid', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Reject expense with reason
  Future<void> rejectExpenseWithReason({
    required String hubId,
    required String expenseId,
    required String reason,
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
        'rejectionReason': reason,
      });

      Logger.info('Expense rejected with reason: $expenseId', tag: 'CoparentingService');
    } catch (e) {
      Logger.error('Error rejecting expense with reason', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  // ========== Message Templates ==========

  /// Create message template
  Future<CoparentingMessageTemplate> createMessageTemplate({
    required String hubId,
    required String title,
    required String content,
    required MessageCategory category,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final template = CoparentingMessageTemplate(
        id: _uuid.v4(),
        hubId: hubId,
        title: title,
        content: content,
        category: category,
        createdAt: DateTime.now(),
        createdBy: currentUserId,
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'message_templates'))
          .doc(template.id)
          .set(template.toJson());

      Logger.info('Message template created: ${template.id}', tag: 'CoparentingService');
      return template;
    } catch (e) {
      Logger.error('Error creating message template', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Get message templates for a hub
  Future<List<CoparentingMessageTemplate>> getMessageTemplates({
    required String hubId,
    MessageCategory? category,
  }) async {
    try {
      var query = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'message_templates'))
          .orderBy('createdAt', descending: true);

      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => CoparentingMessageTemplate.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting message templates', error: e, tag: 'CoparentingService');
      return [];
    }
  }

  /// Delete message template
  Future<void> deleteMessageTemplate({
    required String hubId,
    required String templateId,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'message_templates'))
          .doc(templateId)
          .delete();

      Logger.info('Message template deleted: $templateId', tag: 'CoparentingService');
    } catch (e) {
      Logger.error('Error deleting message template', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  // ========== Child Profiles ==========

  /// Create child profile
  Future<ChildProfile> createChildProfile({
    required String hubId,
    required String name,
    DateTime? dateOfBirth,
    String? medicalInfo,
    String? schoolName,
    String? schoolGrade,
    String? schoolContact,
    List<String>? activitySchedules,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final profile = ChildProfile(
        id: _uuid.v4(),
        hubId: hubId,
        name: name,
        dateOfBirth: dateOfBirth,
        medicalInfo: medicalInfo,
        schoolName: schoolName,
        schoolGrade: schoolGrade,
        schoolContact: schoolContact,
        activitySchedules: activitySchedules ?? [],
        createdAt: DateTime.now(),
        createdBy: currentUserId,
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'child_profiles'))
          .doc(profile.id)
          .set(profile.toJson());

      Logger.info('Child profile created: ${profile.id}', tag: 'CoparentingService');
      return profile;
    } catch (e) {
      Logger.error('Error creating child profile', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Get child profiles for a hub
  Future<List<ChildProfile>> getChildProfiles(String hubId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'child_profiles'))
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => ChildProfile.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting child profiles', error: e, tag: 'CoparentingService');
      return [];
    }
  }

  /// Update child profile
  Future<void> updateChildProfile({
    required String hubId,
    required String profileId,
    String? name,
    DateTime? dateOfBirth,
    String? medicalInfo,
    String? schoolName,
    String? schoolGrade,
    String? schoolContact,
    List<String>? activitySchedules,
    List<String>? documentUrls,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': currentUserId,
      };

      if (name != null) updates['name'] = name;
      if (dateOfBirth != null) updates['dateOfBirth'] = dateOfBirth.toIso8601String();
      if (medicalInfo != null) updates['medicalInfo'] = medicalInfo;
      if (schoolName != null) updates['schoolName'] = schoolName;
      if (schoolGrade != null) updates['schoolGrade'] = schoolGrade;
      if (schoolContact != null) updates['schoolContact'] = schoolContact;
      if (activitySchedules != null) updates['activitySchedules'] = activitySchedules;
      if (documentUrls != null) updates['documentUrls'] = documentUrls;

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'child_profiles'))
          .doc(profileId)
          .update(updates);

      Logger.info('Child profile updated: $profileId', tag: 'CoparentingService');
    } catch (e) {
      Logger.error('Error updating child profile', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }

  /// Delete child profile
  Future<void> deleteChildProfile({
    required String hubId,
    required String profileId,
  }) async {
    try {
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'child_profiles'))
          .doc(profileId)
          .delete();

      Logger.info('Child profile deleted: $profileId', tag: 'CoparentingService');
    } catch (e) {
      Logger.error('Error deleting child profile', error: e, tag: 'CoparentingService');
      rethrow;
    }
  }
}


