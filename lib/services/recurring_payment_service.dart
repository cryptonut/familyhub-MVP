import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/recurring_payment.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class RecurringPaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  /// Create a recurring payment (pocket money)
  Future<RecurringPayment> createRecurringPayment({
    required String toUserId,
    required double amount,
    required String frequency,
    String? notes,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw AuthException('User not found', code: 'user-not-found');

    // Only Bankers can create recurring payments
    if (!userModel.isBanker() && !userModel.isAdmin()) {
      throw PermissionException('Only Bankers and Admins can set up recurring payments', code: 'insufficient-permissions');
    }

    final familyId = userModel.familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    // Validate amount
    if (amount <= 0) {
      throw ValidationException('Amount must be greater than zero', code: 'invalid-amount');
    }

    // Validate frequency
    if (frequency != 'weekly' && frequency != 'monthly') {
      throw ValidationException('Frequency must be weekly or monthly', code: 'invalid-frequency');
    }

    // Check if recipient is in the same family
    final recipientDoc = await _firestore.collection('users').doc(toUserId).get();
    if (!recipientDoc.exists) {
      throw FirestoreException('Recipient not found', code: 'not-found');
    }

    final recipientData = recipientDoc.data();
    if (recipientData?['familyId'] != familyId) {
      throw ValidationException('Recipient must be in the same family', code: 'invalid-recipient');
    }

    // Check for existing active recurring payment
    final existing = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('recurringPayments')
        .where('fromUserId', isEqualTo: currentUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('isActive', isEqualTo: true)
        .get();

    if (existing.docs.isNotEmpty) {
      throw ValidationException('An active recurring payment already exists for this recipient', code: 'duplicate-payment');
    }

    // Create the recurring payment
    final paymentId = _uuid.v4();
    final startDate = DateTime.now();
    final nextPaymentDate = _calculateNextPaymentDate(startDate, frequency);

    final payment = RecurringPayment(
      id: paymentId,
      fromUserId: currentUserId,
      toUserId: toUserId,
      amount: amount,
      frequency: frequency,
      startDate: startDate,
      nextPaymentDate: nextPaymentDate,
      isActive: true,
      notes: notes,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('recurringPayments')
        .doc(paymentId)
        .set(payment.toJson());

    Logger.info('createRecurringPayment: Created payment $paymentId', tag: 'RecurringPaymentService');
    return payment;
  }

  /// Get all recurring payments for the current user (as recipient)
  Future<List<RecurringPayment>> getUserRecurringPayments() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) return [];

    final familyId = userModel.familyId;
    if (familyId == null) return [];

    final snapshot = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('recurringPayments')
        .where('toUserId', isEqualTo: currentUserId)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => RecurringPayment.fromJson({'id': doc.id, ...doc.data()}))
        .toList();
  }

  /// Get all recurring payments created by the current user (as Banker)
  Future<List<RecurringPayment>> getCreatedRecurringPayments() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) return [];

    final familyId = userModel.familyId;
    if (familyId == null) return [];

    final snapshot = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('recurringPayments')
        .where('fromUserId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => RecurringPayment.fromJson({'id': doc.id, ...doc.data()}))
        .toList();
  }

  /// Process recurring payments that are due
  /// This should be called periodically (e.g., daily) to check for due payments
  Future<void> processDuePayments() async {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) return;

    final familyId = userModel.familyId;
    if (familyId == null) return;

    final now = DateTime.now();
    final snapshot = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('recurringPayments')
        .where('isActive', isEqualTo: true)
        .get();

    for (var doc in snapshot.docs) {
      final payment = RecurringPayment.fromJson({'id': doc.id, ...doc.data()});
      
      // Check if payment is due
      final nextPayment = payment.nextPaymentDate ?? payment.calculateNextPaymentDate();
      if (nextPayment.isBefore(now) || nextPayment.isAtSameMomentAs(now)) {
        await _processPayment(payment);
      }
    }
  }

  Future<void> _processPayment(RecurringPayment payment) async {
    try {
      // Add the amount to the recipient's wallet
      // This is done by creating a "pocket money" transaction
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return;

      final familyId = userModel.familyId;
      if (familyId == null) return;

      // Create a transaction record for the pocket money payment
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('pocketMoneyPayments')
          .add({
        'fromUserId': payment.fromUserId,
        'toUserId': payment.toUserId,
        'amount': payment.amount,
        'recurringPaymentId': payment.id,
        'paymentDate': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Update the recurring payment's next payment date
      final nextPaymentDate = payment.calculateNextPaymentDate();
      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('recurringPayments')
          .doc(payment.id)
          .update({
        'nextPaymentDate': nextPaymentDate.toIso8601String(),
        'lastPaymentDate': DateTime.now().toIso8601String(),
      });

      Logger.info('_processPayment: Processed payment ${payment.id}', tag: 'RecurringPaymentService');
    } catch (e) {
      Logger.error('_processPayment error', error: e, tag: 'RecurringPaymentService');
    }
  }

  /// Deactivate a recurring payment
  Future<void> deactivateRecurringPayment(String paymentId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw AuthException('User not found', code: 'user-not-found');

    if (!userModel.isBanker() && !userModel.isAdmin()) {
      throw PermissionException('Only Bankers and Admins can deactivate recurring payments', code: 'insufficient-permissions');
    }

    final familyId = userModel.familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('recurringPayments')
        .doc(paymentId)
        .update({
      'isActive': false,
    });

    Logger.info('deactivateRecurringPayment: Deactivated payment $paymentId', tag: 'RecurringPaymentService');
  }

  /// Get pocket money payments for a user
  Future<List<Map<String, dynamic>>> getUserPocketMoneyPayments(String userId) async {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) return [];

    final familyId = userModel.familyId;
    if (familyId == null) return [];

    final snapshot = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('pocketMoneyPayments')
        .where('toUserId', isEqualTo: userId)
        .orderBy('paymentDate', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  DateTime _calculateNextPaymentDate(DateTime startDate, String frequency) {
    switch (frequency) {
      case 'weekly':
        return startDate.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(startDate.year, startDate.month + 1, startDate.day);
      default:
        return startDate.add(const Duration(days: 7));
    }
  }
}

