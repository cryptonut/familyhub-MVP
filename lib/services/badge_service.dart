import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import '../games/chess/services/chess_service.dart';
import '../games/chess/models/chess_game.dart';
import 'task_service.dart';
import 'chat_service.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final ChessService _chessService = ChessService();
  final TaskService _taskService = TaskService();
  final ChatService _chatService = ChatService();

  /// Get unread message count
  Stream<int> getUnreadMessageCount() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(0);
    }

    return Stream.fromFuture(_authService.getCurrentUserModel()).asyncExpand((userModel) {
      if (userModel?.familyId == null) {
        return Stream.value(0);
      }

      // Simplified: count unread private messages
      // Full implementation would check readStatus subcollection
      return _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(userModel!.familyId)
          .collection('privateMessages')
          .where('participants', arrayContains: userId)
          .snapshots()
          .map((snapshot) {
        // Placeholder: return 0 for now
        // Full implementation would check readStatus
        return 0;
      });
    });
  }

  /// Get pending task count (tasks needing approval)
  Stream<int> getPendingTaskCount() {
    return _authService.getCurrentUserModel().asStream().asyncExpand((userModel) {
      if (userModel?.familyId == null) {
        return Stream.value(0);
      }

      return _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(userModel!.familyId)
          .collection('tasks')
          .where('createdBy', isEqualTo: _auth.currentUser?.uid)
          .where('claimStatus', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    });
  }

  /// Get waiting game count (chess challenges)
  Stream<int> getWaitingGameCount() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(0);
    }

    return _authService.getCurrentUserModel().asStream().asyncExpand((userModel) {
      if (userModel?.familyId == null) {
        return Stream.value(0);
      }

      return _chessService.streamWaitingFamilyGames(userModel!.familyId!).map((games) {
        return games.where((g) => g.invitedPlayerId == userId).length;
      });
    });
  }

  /// Get pending approval count (tasks completed by others, waiting for your approval)
  Stream<int> getPendingApprovalCount() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(0);
    }

    return _authService.getCurrentUserModel().asStream().asyncExpand((userModel) {
      if (userModel?.familyId == null) {
        return Stream.value(0);
      }

      return _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(userModel!.familyId)
          .collection('tasks')
          .where('createdBy', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .where('claimStatus', isEqualTo: 'pending')
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    });
  }

  /// Get all badge counts
  Stream<BadgeCounts> getAllBadgeCounts() {
    return Stream.fromFuture(_authService.getCurrentUserModel()).asyncExpand((userModel) {
      if (userModel?.familyId == null) {
        return Stream.value(BadgeCounts(
          unreadMessages: 0,
          pendingTasks: 0,
          waitingGames: 0,
          pendingApprovals: 0,
        ));
      }

      return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) async {
        final unread = await getUnreadMessageCount().first;
        final pending = await getPendingTaskCount().first;
        final games = await getWaitingGameCount().first;
        final approvals = await getPendingApprovalCount().first;

        return BadgeCounts(
          unreadMessages: unread,
          pendingTasks: pending,
          waitingGames: games,
          pendingApprovals: approvals,
        );
      });
    });
  }
}

class BadgeCounts {
  final int unreadMessages;
  final int pendingTasks;
  final int waitingGames;
  final int pendingApprovals;

  BadgeCounts({
    required this.unreadMessages,
    required this.pendingTasks,
    required this.waitingGames,
    required this.pendingApprovals,
  });

  int get total => unreadMessages + pendingTasks + waitingGames + pendingApprovals;
}

