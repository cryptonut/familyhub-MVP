import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payout_request.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'package:uuid/uuid.dart';

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
      throw Exception('User not authenticated');
    }

    // Validate amount
    if (amount <= 0) {
      throw Exception('Payout amount must be greater than zero');
    }
    
    if (amount > currentBalance) {
      throw Exception('Payout amount cannot exceed your wallet balance of \$${currentBalance.toStringAsFixed(2)}');
    }

    // Check for existing pending requests
    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw Exception('User not found');
    
    final familyId = userModel.familyId;
    if (familyId == null) throw Exception('User not part of a family');

    final pendingRequests = await _firestore
        .collection('families')
        .doc(familyId)
        .collection('payoutRequests')
        .where('userId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (pendingRequests.docs.isNotEmpty) {
      throw Exception('You already have a pending payout request');
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

    debugPrint('PayoutService.createPayoutRequest: Created request $requestId for user $currentUserId');
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
      throw Exception('User not authenticated');
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw Exception('User not found');

    if (!userModel.isBanker() && !userModel.isAdmin()) {
      throw Exception('Only Bankers and Admins can approve payouts');
    }

    final familyId = userModel.familyId;
    if (familyId == null) throw Exception('User not part of a family');

    final requestRef = _firestore
        .collection('families')
        .doc(familyId)
        .collection('payoutRequests')
        .doc(requestId);

    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      throw Exception('Payout request not found');
    }

    final requestData = requestDoc.data()!;
    final request = PayoutRequest.fromJson({'id': requestId, ...requestData});

    if (request.status != 'pending') {
      throw Exception('Payout request is not pending');
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

    debugPrint('PayoutService.approvePayoutRequest: Approved request $requestId');
  }

  /// Reject a payout request
  Future<void> rejectPayoutRequest(String requestId, String reason) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) throw Exception('User not found');

    if (!userModel.isBanker() && !userModel.isAdmin()) {
      throw Exception('Only Bankers and Admins can reject payouts');
    }

    final familyId = userModel.familyId;
    if (familyId == null) throw Exception('User not part of a family');

    final requestRef = _firestore
        .collection('families')
        .doc(familyId)
        .collection('payoutRequests')
        .doc(requestId);

    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      throw Exception('Payout request not found');
    }

    final requestData = requestDoc.data()!;
    final request = PayoutRequest.fromJson({'id': requestId, ...requestData});

    if (request.status != 'pending') {
      throw Exception('Payout request is not pending');
    }

    await requestRef.update({
      'status': 'rejected',
      'approvedBy': currentUserId,
      'approvedAt': DateTime.now().toIso8601String(),
      'rejectedReason': reason,
    });

    debugPrint('PayoutService.rejectPayoutRequest: Rejected request $requestId');
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

