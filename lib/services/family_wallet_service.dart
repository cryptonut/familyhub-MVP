import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/task.dart';
import 'auth_service.dart';

class FamilyWalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  /// Get family wallet balance
  Future<double> getFamilyWalletBalance() async {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null || userModel.familyId == null) return 0.0;

    try {
      final familyDoc = await _firestore
          .collection('families')
          .doc(userModel.familyId)
          .get();

      if (familyDoc.exists) {
        final data = familyDoc.data();
        return (data?['walletBalance'] as num?)?.toDouble() ?? 0.0;
      } else {
        // Family document doesn't exist yet, create it
        await _firestore
            .collection('families')
            .doc(userModel.familyId)
            .set({'walletBalance': 0.0});
        return 0.0;
      }
    } catch (e) {
      debugPrint('Error getting family wallet balance: $e');
      return 0.0;
    }
  }

  /// Credit family wallet (when job is created)
  Future<void> creditFamilyWallet(double amount) async {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null || userModel.familyId == null) {
      throw Exception('User not part of a family');
    }

    try {
      final familyRef = _firestore.collection('families').doc(userModel.familyId);
      
      debugPrint('FamilyWalletService.creditFamilyWallet: Starting transaction for amount $amount');
      debugPrint('FamilyWalletService.creditFamilyWallet: Family ID: ${userModel.familyId}');
      
      // Use transaction to ensure atomic update
      await _firestore.runTransaction((transaction) async {
        final familyDoc = await transaction.get(familyRef);
        final currentBalance = (familyDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final newBalance = currentBalance + amount;
        
        debugPrint('FamilyWalletService.creditFamilyWallet: Current balance: $currentBalance, New balance: $newBalance');
        
        transaction.set(familyRef, {
          'walletBalance': newBalance,
        }, SetOptions(merge: true));
      });
      
      // Verify the credit was applied
      final verifyDoc = await familyRef.get();
      final verifyBalance = (verifyDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
      debugPrint('FamilyWalletService.creditFamilyWallet: Verified balance after credit: $verifyBalance');
      
      if (verifyBalance < amount) {
        throw Exception('Wallet credit verification failed: Expected at least $amount, but balance is $verifyBalance');
      }
      
      debugPrint('FamilyWalletService.creditFamilyWallet: Successfully credited $amount to family wallet. New balance: $verifyBalance');
    } catch (e) {
      debugPrint('FamilyWalletService.creditFamilyWallet: Error crediting family wallet: $e');
      rethrow;
    }
  }

  /// Debit family wallet (when job is completed and paid out)
  Future<void> debitFamilyWallet(double amount) async {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null || userModel.familyId == null) {
      throw Exception('User not part of a family');
    }

    try {
      final familyRef = _firestore.collection('families').doc(userModel.familyId);
      
      // Use transaction to ensure atomic update
      await _firestore.runTransaction((transaction) async {
        final familyDoc = await transaction.get(familyRef);
        final currentBalance = (familyDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
        
        if (currentBalance < amount) {
          throw Exception('Insufficient family wallet balance');
        }
        
        transaction.set(familyRef, {
          'walletBalance': currentBalance - amount,
        }, SetOptions(merge: true));
      });
      
      debugPrint('FamilyWalletService: Debited $amount from family wallet');
    } catch (e) {
      debugPrint('Error debiting family wallet: $e');
      rethrow;
    }
  }

  /// Return funds to creator when job is cancelled
  Future<void> returnFundsToCreator(String creatorId, double amount) async {
    // This will be handled by updating the creator's personal balance
    // The family wallet balance will be debited
    await debitFamilyWallet(amount);
    
    // Note: Creator's personal balance update is handled in WalletService
    debugPrint('FamilyWalletService: Returning $amount to creator $creatorId');
  }

  /// Check if user can create a job with the given reward amount
  /// Returns (canCreate, userBalance, familyWalletBalance)
  /// Requires tasks list to be passed in to avoid circular dependency
  Future<Map<String, dynamic>> canCreateJobWithReward(double rewardAmount, List<Task> allTasks) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return {
        'canCreate': false,
        'reason': 'User not authenticated',
        'userBalance': 0.0,
        'familyWalletBalance': 0.0,
      };
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) {
      return {
        'canCreate': false,
        'reason': 'User not found',
        'userBalance': 0.0,
        'familyWalletBalance': 0.0,
      };
    }

    // Calculate user's current balance directly (avoiding circular dependency)
    final userBalance = _calculateUserBalance(currentUserId, userModel, allTasks);
    final familyWalletBalance = await getFamilyWalletBalance();

    // If user is Banker or Admin, they can go negative (mint AUD)
    if (userModel.isBanker() || userModel.isAdmin()) {
      return {
        'canCreate': true,
        'reason': 'Banker/Admin can mint AUD',
        'userBalance': userBalance,
        'familyWalletBalance': familyWalletBalance,
        'willGoNegative': userBalance < rewardAmount,
        'negativeAmount': rewardAmount - userBalance,
      };
    }

    // Non-Bankers must have sufficient balance
    if (userBalance < rewardAmount) {
      return {
        'canCreate': false,
        'reason': 'Insufficient balance. You need \$${rewardAmount.toStringAsFixed(2)} but only have \$${userBalance.toStringAsFixed(2)}',
        'userBalance': userBalance,
        'familyWalletBalance': familyWalletBalance,
      };
    }

    return {
      'canCreate': true,
      'reason': 'Sufficient balance',
      'userBalance': userBalance,
      'familyWalletBalance': familyWalletBalance,
    };
  }

  /// Calculate user's wallet balance (duplicated from WalletService to avoid circular dependency)
  double _calculateUserBalance(String userId, UserModel userModel, List<Task> allTasks) {
    double balance = 0.0;

    // Start with earnings from completed jobs
    final completedJobs = allTasks.where((task) => 
      task.isCompleted && 
      !task.isAwaitingApproval &&
      task.reward != null &&
      task.reward! > 0 &&
      (task.claimedBy == userId || task.assignedTo == userId)
    ).toList();
    
    for (var job in completedJobs) {
      balance += (job.reward ?? 0.0);
    }

    // For Bankers: subtract rewards from jobs they created (liability)
    // Uses positive balance first, then goes negative
    if (userModel.isBanker() || userModel.isAdmin()) {
      final createdJobs = allTasks.where((task) => 
        task.createdBy == userId &&
        task.reward != null &&
        task.reward! > 0
      ).toList();
      
      for (var job in createdJobs) {
        // For Bankers: liability persists even after job is paid
        // The negative balance represents "minted" money that hasn't been earned back
        // It only gets "paid back" when the Banker completes jobs themselves
        final rewardAmount = job.reward ?? 0.0;
        // If job is refunded, don't count it as a liability
        if (job.isRefunded == true) {
          continue;
        }
        // Always subtract the liability (even if completed and approved)
        // This maintains the negative balance to track net minting
        balance -= rewardAmount;
      }
    } else {
      // Non-Bankers: subtract from balance when creating jobs (must have sufficient funds)
      // The money is deducted when the job is completed and approved (paid out)
      final createdJobs = allTasks.where((task) => 
        task.createdBy == userId &&
        task.reward != null &&
        task.reward! > 0
      ).toList();
      
      for (var job in createdJobs) {
        // If job is refunded, don't count it as a liability
        if (job.isRefunded == true) {
          continue;
        }
        // For non-Bankers: subtract reward for all created jobs
        // This represents the money they've committed/spent
        balance -= (job.reward ?? 0.0);
      }
    }

    return balance;
  }
}

