import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/payout_request.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class PayoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final Uuid _uuid = const Uuid();

  /// Create a payout request
  /// [currentBalance] should be the user's current wallet balance (passed from caller to avoid circular dependency)
  Future<PayoutRequest> createPayoutRequest(double amount, double currentBalance) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    // Validate amount
    if (amount <= 0) {
      throw ValidationException('Payout amount must be greater than zero', code: 'invalid-amount');
    }
    
    if (amount > currentBalance) {
      throw ValidationException('Payout amount cannot exceed your wallet balance of \$${currentBalance.toStringAsFixed(2)}', code: 'insufficient-balance');
    }

    // Check for existing pending requests
    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw AuthException('User not found', code: 'user-not-found');
    
    final familyId = userModel.familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final pendingRequests = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('payoutRequests')
        .where('userId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (pendingRequests.docs.isNotEmpty) {
      throw ValidationException('You already have a pending payout request', code: 'pending-request-exists');
    }

    // Create the payout request
    final requestId = _uuid.v4();
    final request = PayoutRequest(
      id: requestId,
      userId: currentUserId,
      amount: amount,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('payoutRequests')
        .doc(requestId)
        .set(request.toJson());

    Logger.info('createPayoutRequest: Created request $requestId for user $currentUserId', tag: 'PayoutService');
    return request;
  }

  /// Get all payout requests for the current user
  Future<List<PayoutRequest>> getUserPayoutRequests() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) return [];

    final familyId = userModel.familyId;
    if (familyId == null) return [];

    final snapshot = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('payoutRequests')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => PayoutRequest.fromJson({'id': doc.id, ...doc.data()}))
        .toList();
  }

  /// Get all pending payout requests (for Bankers to approve)
  Future<List<PayoutRequest>> getPendingPayoutRequests() async {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) return [];

    final familyId = userModel.familyId;
    if (familyId == null) return [];

    // Check if user is a Banker
    if (!userModel.isBanker() && !userModel.isAdmin()) {
      return [];
    }

    final snapshot = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('payoutRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt')
        .get();

    return snapshot.docs
        .map((doc) => PayoutRequest.fromJson({'id': doc.id, ...doc.data()}))
        .toList();
  }

  /// Approve a payout request
  Future<void> approvePayoutRequest(
    String requestId,
    String paymentMethod, {
    String? notes,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw AuthException('User not found', code: 'user-not-found');

    if (!userModel.isBanker() && !userModel.isAdmin()) {
      throw PermissionException('Only Bankers and Admins can approve payouts', code: 'insufficient-permissions');
    }

    final familyId = userModel.familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final requestRef = _firestore
        .collection('families')
        .doc(familyId)
        .collection('payoutRequests')
        .doc(requestId);

    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      throw FirestoreException('Payout request not found', code: 'not-found');
    }

    final requestData = requestDoc.data()!;
    final request = PayoutRequest.fromJson({'id': requestId, ...requestData});

    if (request.status != 'pending') {
      throw ValidationException('Payout request is not pending', code: 'invalid-status');
    }

    // Update the request
    await requestRef.update({
      'status': 'approved',
      'approvedBy': currentUserId,
      'approvedAt': DateTime.now().toIso8601String(),
      'paymentMethod': paymentMethod,
      'notes': notes,
    });

    // Deduct the amount from the user's wallet balance
    // This is done by creating a "payout" transaction record
    // The actual balance calculation will need to account for approved payouts
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('payouts')
        .add({
      'userId': request.userId,
      'amount': request.amount,
      'requestId': requestId,
      'paymentMethod': paymentMethod,
      'approvedBy': currentUserId,
      'approvedAt': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    });

    Logger.info('approvePayoutRequest: Approved request $requestId', tag: 'PayoutService');
  }

  /// Reject a payout request
  Future<void> rejectPayoutRequest(String requestId, String reason) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw AuthException('User not found', code: 'user-not-found');

    if (!userModel.isBanker() && !userModel.isAdmin()) {
      throw PermissionException('Only Bankers and Admins can reject payouts', code: 'insufficient-permissions');
    }

    final familyId = userModel.familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    final requestRef = _firestore
        .collection('families')
        .doc(familyId)
        .collection('payoutRequests')
        .doc(requestId);

    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      throw FirestoreException('Payout request not found', code: 'not-found');
    }

    final requestData = requestDoc.data()!;
    final request = PayoutRequest.fromJson({'id': requestId, ...requestData});

    if (request.status != 'pending') {
      throw ValidationException('Payout request is not pending', code: 'invalid-status');
    }

    await requestRef.update({
      'status': 'rejected',
      'approvedBy': currentUserId,
      'approvedAt': DateTime.now().toIso8601String(),
      'rejectedReason': reason,
    });

    Logger.info('rejectPayoutRequest: Rejected request $requestId', tag: 'PayoutService');
  }

  /// Get approved payouts for a user (to deduct from balance)
  Future<List<Map<String, dynamic>>> getUserApprovedPayouts(String userId) async {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) return [];

    final familyId = userModel.familyId;
    if (familyId == null) return [];

    final snapshot = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('payouts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}

