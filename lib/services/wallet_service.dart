import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../models/user_model.dart';
import 'task_service.dart';
import 'auth_service.dart';
import 'family_wallet_service.dart';
import 'payout_service.dart';
import 'recurring_payment_service.dart';

class WalletService {
  final TaskService _taskService = TaskService();
  final AuthService _authService = AuthService();
  final FamilyWalletService _familyWalletService = FamilyWalletService();
  final PayoutService _payoutService = PayoutService();
  final RecurringPaymentService _recurringPaymentService = RecurringPaymentService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate wallet balance for the current user
  /// For Bankers: can go negative when creating jobs (minting AUD)
  /// Uses positive balance first, then goes negative
  /// For all users: positive balance for jobs they completed with rewards
  /// 
  /// If [tasks] is provided, uses that list instead of fetching from Firestore
  Future<double> calculateWalletBalance({List<Task>? tasks}) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 0.0;

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) return 0.0;

    final allTasks = tasks ?? await _taskService.getTasks(forceRefresh: true);
    double balance = 0.0;
    
    debugPrint('WalletService.calculateWalletBalance: Starting calculation for user ${currentUserId}');
    debugPrint('WalletService.calculateWalletBalance: User is Banker: ${userModel.isBanker()}, Admin: ${userModel.isAdmin()}');

    // Start with earnings from completed jobs
    final completedJobs = allTasks.where((task) => 
      task.isCompleted && 
      !task.isAwaitingApproval &&
      task.reward != null &&
      task.reward! > 0 &&
      (task.claimedBy == currentUserId || task.assignedTo == currentUserId)
    ).toList();
    
    debugPrint('WalletService.calculateWalletBalance: Found ${completedJobs.length} completed jobs');
    debugPrint('WalletService.calculateWalletBalance: Total tasks: ${allTasks.length}');
    
    for (var job in completedJobs) {
      balance += (job.reward ?? 0.0);
    }
    
    debugPrint('WalletService.calculateWalletBalance: Balance after completed jobs: $balance');

    // For Bankers: subtract rewards from jobs they created (liability)
    // Uses positive balance first, then goes negative
    if (userModel.isBanker() || userModel.isAdmin()) {
      final createdJobs = allTasks.where((task) => 
        task.createdBy == currentUserId &&
        task.reward != null &&
        task.reward! > 0
      ).toList();
      
      debugPrint('WalletService.calculateWalletBalance: Found ${createdJobs.length} created jobs for Banker/Admin');
      
      for (var job in createdJobs) {
        // For Bankers: liability persists even after job is paid
        // The negative balance represents "minted" money that hasn't been earned back
        // It only gets "paid back" when the Banker completes jobs themselves
        final rewardAmount = job.reward ?? 0.0;
        // If job is refunded, don't count it as a liability
        if (job.isRefunded == true) {
          debugPrint('WalletService.calculateWalletBalance: Skipping refunded job ${job.id}');
          continue;
        }
        // Always subtract the liability (even if completed and approved)
        // This maintains the negative balance to track net minting
        debugPrint('WalletService.calculateWalletBalance: Subtracting ${rewardAmount} for job ${job.id} (${job.title})');
        balance -= rewardAmount;
      }
    } else {
      // Non-Bankers: subtract from balance when creating jobs (must have sufficient funds)
      // The liability exists until the job is completed and approved (money paid out)
      final createdJobs = allTasks.where((task) => 
        task.createdBy == currentUserId &&
        task.reward != null &&
        task.reward! > 0
      ).toList();
      
      debugPrint('WalletService.calculateWalletBalance: Found ${createdJobs.length} created jobs for non-Banker');
      
      for (var job in createdJobs) {
        // If job is refunded, don't count it as a liability
        if (job.isRefunded == true) {
          debugPrint('WalletService.calculateWalletBalance: Skipping refunded job ${job.id}');
          continue;
        }
        // For non-Bankers: subtract reward for all created jobs
        // The money is deducted when the job is completed and approved (paid out)
        // So we always subtract it (whether pending, completed, or approved)
        // This represents the money they've committed/spent
        debugPrint('WalletService.calculateWalletBalance: Subtracting ${job.reward} for job ${job.id} (${job.title})');
        balance -= (job.reward ?? 0.0);
      }
    }
    
    debugPrint('WalletService.calculateWalletBalance: Balance after created jobs: $balance');

    // Add pocket money payments (recurring payments received)
    // Wrap in try-catch to handle missing Firestore indexes gracefully
    try {
      final pocketMoneyPayments = await _recurringPaymentService.getUserPocketMoneyPayments(currentUserId);
      for (var payment in pocketMoneyPayments) {
        final amount = payment['amount'] as num?;
        if (amount != null) {
          balance += amount.toDouble();
        }
      }
      debugPrint('WalletService.calculateWalletBalance: Added pocket money payments');
    } catch (e) {
      debugPrint('WalletService.calculateWalletBalance: Error loading pocket money payments (non-critical): $e');
      // Continue with balance calculation even if this fails
    }

    // Subtract approved payouts (money that has been paid out outside the app)
    // Wrap in try-catch to handle missing Firestore indexes gracefully
    try {
      final approvedPayouts = await _payoutService.getUserApprovedPayouts(currentUserId);
      for (var payout in approvedPayouts) {
        final amount = payout['amount'] as num?;
        if (amount != null) {
          balance -= amount.toDouble();
        }
      }
      debugPrint('WalletService.calculateWalletBalance: Subtracted approved payouts');
    } catch (e) {
      debugPrint('WalletService.calculateWalletBalance: Error loading approved payouts (non-critical): $e');
      // Continue with balance calculation even if this fails
    }

    debugPrint('WalletService.calculateWalletBalance: Final balance: $balance');
    return balance;
  }

  /// Get all transactions (both created jobs and completed jobs)
  /// Only returns transactions for the current user
  /// 
  /// If [tasks] is provided, uses that list instead of fetching from Firestore
  Future<Map<String, List<Task>>> getTransactions({List<Task>? tasks}) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return {'created': [], 'completed': []};

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) return {'created': [], 'completed': []};

    final allTasks = tasks ?? await _taskService.getTasks(forceRefresh: true);
    
    // Jobs created by current user (show for ALL users, not just Bankers/Admins)
    // Only show jobs created by THIS user
    final createdJobs = allTasks.where((task) {
      final matchesCreatedBy = task.createdBy != null && task.createdBy == currentUserId;
      final hasReward = task.reward != null && task.reward! > 0;
      
      if (hasReward) {
        debugPrint('WalletService.getTransactions: Checking created task ${task.id}');
        debugPrint('  - createdBy: ${task.createdBy}');
        debugPrint('  - currentUserId: $currentUserId');
        debugPrint('  - matchesCreatedBy: $matchesCreatedBy');
      }
      
      return matchesCreatedBy && hasReward;
    }).toList();
    
    // Jobs completed by current user
    // Only show jobs where THIS user completed them
    // Note: For older tasks that might not have claimedBy/assignedTo set,
    // we check if the task was completed and has a reward - if it's in the completed list
    // and the user has a positive balance from it, we include it
    final completedJobs = allTasks.where((task) {
      final matchesClaimedBy = task.claimedBy != null && task.claimedBy == currentUserId;
      final matchesAssignedTo = task.assignedTo.isNotEmpty && task.assignedTo == currentUserId;
      final isCompleted = task.isCompleted && !task.isAwaitingApproval;
      final hasReward = task.reward != null && task.reward! > 0;
      
      // For backward compatibility: if task is completed, has reward, but no assignedTo/claimedBy,
      // we can't definitively say who completed it, so we exclude it
      // (This prevents showing other users' completed tasks)
      final hasCompleterInfo = (task.claimedBy != null && task.claimedBy!.isNotEmpty) ||
                               (task.assignedTo.isNotEmpty);
      
      if (isCompleted && hasReward) {
        debugPrint('WalletService.getTransactions: Checking task ${task.id}');
        debugPrint('  - createdBy: ${task.createdBy}');
        debugPrint('  - claimedBy: ${task.claimedBy}');
        debugPrint('  - assignedTo: ${task.assignedTo}');
        debugPrint('  - currentUserId: $currentUserId');
        debugPrint('  - matchesClaimedBy: $matchesClaimedBy');
        debugPrint('  - matchesAssignedTo: $matchesAssignedTo');
        debugPrint('  - hasCompleterInfo: $hasCompleterInfo');
        debugPrint('  - isCompleted: $isCompleted');
        debugPrint('  - hasReward: $hasReward');
      }
      
      return isCompleted && 
             hasReward &&
             hasCompleterInfo &&
             (matchesClaimedBy || matchesAssignedTo);
    }).toList();

    // Sort by date
    createdJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    completedJobs.sort((a, b) {
      if (a.completedAt != null && b.completedAt != null) {
        return b.completedAt!.compareTo(a.completedAt!);
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    debugPrint('WalletService.getTransactions: Summary for user $currentUserId');
    debugPrint('  - Total tasks: ${allTasks.length}');
    debugPrint('  - Created jobs: ${createdJobs.length}');
    debugPrint('  - Completed jobs: ${completedJobs.length}');
    if (completedJobs.isNotEmpty) {
      debugPrint('  - Completed job IDs: ${completedJobs.map((t) => t.id).join(", ")}');
    }

    return {
      'created': createdJobs,
      'completed': completedJobs,
    };
  }
}

