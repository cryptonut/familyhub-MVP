import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'family_wallet_service.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final FamilyWalletService _familyWalletService = FamilyWalletService();
  
  String? _cachedFamilyId;
  
  Future<String?> get _familyId async {
    // Always fetch fresh familyId to ensure we have the latest value
    // (in case user joined a family or familyId was updated)
    final userModel = await _authService.getCurrentUserModel();
    final freshFamilyId = userModel?.familyId;
    
    // Update cache if it changed
    if (_cachedFamilyId != freshFamilyId) {
      debugPrint('TaskService._familyId: FamilyId changed from $_cachedFamilyId to $freshFamilyId');
      _cachedFamilyId = freshFamilyId;
    }
    
    return _cachedFamilyId;
  }
  
  /// Clear the cached familyId (useful when familyId might have changed)
  void clearFamilyIdCache() {
    debugPrint('TaskService.clearFamilyIdCache: Clearing cached familyId');
    _cachedFamilyId = null;
  }

  Future<String> get _collectionPath async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    return 'families/$familyId/tasks';
  }

  Future<List<Task>> getTasks({bool forceRefresh = false}) async {
    final familyId = await _familyId;
    if (familyId == null) {
      debugPrint('TaskService.getTasks: User not part of a family');
      return [];
    }
    
    try {
      final collectionPath = 'families/$familyId/tasks';
      debugPrint('TaskService.getTasks: Loading tasks from $collectionPath');
      
      QuerySnapshot snapshot;
      try {
        snapshot = await _firestore
            .collection(collectionPath)
            .orderBy('createdAt', descending: true)
            .get(GetOptions(source: forceRefresh ? Source.server : Source.cache));
      } catch (e) {
        debugPrint('TaskService.getTasks: orderBy failed, trying without orderBy: $e');
        snapshot = await _firestore
            .collection(collectionPath)
            .get(GetOptions(source: forceRefresh ? Source.server : Source.cache));
      }
      
      final tasks = snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          return Task.fromJson({
            'id': doc.id,
            ...data,
          });
        } catch (e) {
          debugPrint('TaskService.getTasks: Error parsing task ${doc.id}: $e');
          return null;
        }
      }).whereType<Task>().toList();
      
      // Sort by createdAt if we didn't use orderBy
      if (tasks.isNotEmpty && tasks.any((t) => t.createdAt != null)) {
        tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      debugPrint('TaskService.getTasks: Successfully loaded ${tasks.length} tasks');
      return tasks;
    } catch (e, stackTrace) {
      debugPrint('TaskService.getTasks error: $e');
      debugPrint('  Stack trace: $stackTrace');
      return [];
    }
  }

  Stream<List<Task>> getTasksStream() {
    return Stream.fromFuture(_familyId).asyncExpand((familyId) {
      if (familyId == null) {
        return Stream.value(<Task>[]);
      }
      
      return _firestore
          .collection('families/$familyId/tasks')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Task.fromJson({
                    'id': doc.id,
                    ...doc.data(),
                  }))
              .toList());
    });
  }

  Future<List<Task>> getActiveTasks({bool forceRefresh = false}) async {
    try {
      final allTasks = await getTasks(forceRefresh: forceRefresh);
      final active = allTasks.where((task) => !task.isCompleted).toList();
      debugPrint('TaskService.getActiveTasks: Found ${active.length} active tasks out of ${allTasks.length} total');
      return active;
    } catch (e) {
      debugPrint('TaskService.getActiveTasks error: $e');
      return [];
    }
  }

  Future<List<Task>> getCompletedTasks({bool forceRefresh = false}) async {
    try {
      final allTasks = await getTasks(forceRefresh: forceRefresh);
      final completed = allTasks.where((task) => task.isCompleted).toList();
      debugPrint('TaskService.getCompletedTasks: Found ${completed.length} completed tasks out of ${allTasks.length} total');
      return completed;
    } catch (e) {
      debugPrint('TaskService.getCompletedTasks error: $e');
      return [];
    }
  }

  Future<void> addTask(Task task) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    // Track if wallet was credited in case we need to rollback
    bool walletCredited = false;
    double? creditedAmount;
    
    try {
      // If task has a reward, handle family wallet and balance checks
      if (task.reward != null && task.reward! > 0) {
        final rewardAmount = task.reward!;
        final userModel = await _authService.getCurrentUserModel();
        if (userModel == null) throw Exception('User not authenticated');
        
        // Get all tasks to pass to canCreateJobWithReward (to avoid circular dependency)
        final allTasks = await getTasks();
        
        // Check if user can create job with this reward
        final canCreate = await _familyWalletService.canCreateJobWithReward(rewardAmount, allTasks);
        
        if (!canCreate['canCreate'] as bool) {
          throw Exception(canCreate['reason'] as String);
        }
        
        // Credit family wallet with the full reward amount
        await _familyWalletService.creditFamilyWallet(rewardAmount);
        walletCredited = true;
        creditedAmount = rewardAmount;
        debugPrint('TaskService.addTask: Credited $rewardAmount to family wallet');
      }
      
      final collectionPath = 'families/$familyId/tasks';
      debugPrint('TaskService.addTask: Adding task ${task.id} to $collectionPath');
      
      // Remove 'id' from the data since it's used as the document ID
      final data = task.toJson();
      data.remove('id');
      
      // Use set() with the task.id as document ID to ensure consistent IDs
      final docRef = _firestore.collection(collectionPath).doc(task.id);
      await docRef.set(data);
      
      debugPrint('TaskService.addTask: Task ${task.id} written to Firestore successfully');
      
      // Verify the task was actually written
      final verifyDoc = await docRef.get();
      if (!verifyDoc.exists) {
        throw Exception('Task was not saved to Firestore - verification failed');
      }
      
      debugPrint('TaskService.addTask: Task ${task.id} verified in Firestore');
    } catch (e) {
      debugPrint('TaskService.addTask error: $e');
      
      // If wallet was credited but task save failed, try to rollback
      if (walletCredited && creditedAmount != null) {
        try {
          debugPrint('TaskService.addTask: Attempting to rollback wallet credit of $creditedAmount');
          await _familyWalletService.debitFamilyWallet(creditedAmount!);
          debugPrint('TaskService.addTask: Wallet credit rolled back successfully');
        } catch (rollbackError) {
          debugPrint('TaskService.addTask: Failed to rollback wallet credit: $rollbackError');
          // Don't throw here - the original error is more important
        }
      }
      
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      final docRef = _firestore.collection('families/$familyId/tasks').doc(task.id);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw Exception('Task not found. Cannot update a task that does not exist.');
      }
      
      // Remove 'id' from the data since it's used as the document ID
      final data = task.toJson();
      data.remove('id');
      
      // Use update() since we've confirmed the document exists
      await docRef.update(data);
      
      debugPrint('TaskService.updateTask: Successfully updated task ${task.id}');
    } catch (e) {
      debugPrint('TaskService.updateTask error: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    final docRef = _firestore.collection('families/$familyId/tasks').doc(taskId);
    final taskDoc = await docRef.get();
    
    if (!taskDoc.exists) {
      throw Exception('Task not found');
    }
    
    // Get task data before deleting
    final taskData = taskDoc.data() as Map<String, dynamic>?;
    final reward = taskData?['reward'] as num?;
    final createdBy = taskData?['createdBy'] as String?;
    final isCompleted = taskData?['isCompleted'] == true;
    final isAwaitingApproval = taskData?['needsApproval'] == true && 
                               taskData?['isCompleted'] == true &&
                               taskData?['approvedBy'] == null;
    
    // If job has reward and is not completed/approved, return funds to creator
    if (reward != null && reward > 0 && !isCompleted && !isAwaitingApproval) {
      if (createdBy != null) {
        await _familyWalletService.returnFundsToCreator(createdBy, reward.toDouble());
        debugPrint('TaskService.deleteTask: Returning $reward to creator $createdBy');
      }
    }
    
    await docRef.delete();
  }

  Future<void> toggleTaskCompletion(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      final collectionPath = await _collectionPath;
      final docRef = _firestore.collection(collectionPath).doc(taskId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        debugPrint('TaskService.toggleTaskCompletion: Document not found: $taskId');
        return;
      }

      final task = Task.fromJson({'id': doc.id, ...doc.data()!});
      final newCompletedState = !task.isCompleted;
      
      // Use update() to ensure atomic operation
      await docRef.update({
        'isCompleted': newCompletedState,
        'completedAt': newCompletedState ? DateTime.now().toIso8601String() : null,
      });
      
      debugPrint('TaskService.toggleTaskCompletion: Task $taskId set to completed=$newCompletedState');
    } catch (e) {
      debugPrint('TaskService.toggleTaskCompletion error: $e');
      debugPrint('Task ID: $taskId');
      rethrow;
    }
  }

  /// Mark a task as completed (always sets to true, doesn't toggle)
  Future<void> completeTask(String taskId) async {
    final familyId = await _familyId;
    final userId = _auth.currentUser?.uid;
    if (familyId == null) throw Exception('User not part of a family');
    if (userId == null) throw Exception('User not authenticated');
    
    try {
      final docRef = _firestore.collection('families/$familyId/tasks').doc(taskId);
      final doc = await docRef.get(GetOptions(source: Source.server));
      
      if (!doc.exists) {
        throw Exception('Task not found: $taskId');
      }
      
      final currentData = doc.data() as Map<String, dynamic>?;
      debugPrint('TaskService.completeTask: Current task data for $taskId:');
      debugPrint('  - Document ID: ${doc.id}');
      debugPrint('  - isCompleted: ${currentData?['isCompleted']}');
      debugPrint('  - title: ${currentData?['title']}');
      debugPrint('  - All fields: ${currentData?.keys.toList()}');

      // Always set to completed (since Job Done! button only appears on active tasks)
      // Ensure assignedTo is set to the current user if not already set
      // This is important for wallet transactions to show who completed the job
      final updateData = <String, dynamic>{
        'isCompleted': true,
        'completedAt': DateTime.now().toIso8601String(),
      };
      
      // If assignedTo is empty but claimedBy is set, use claimedBy
      final currentAssignedTo = currentData?['assignedTo'] as String? ?? '';
      final currentClaimedBy = currentData?['claimedBy'] as String?;
      
      if (currentAssignedTo.isEmpty) {
        if (currentClaimedBy != null && currentClaimedBy.isNotEmpty) {
          updateData['assignedTo'] = currentClaimedBy;
        } else {
          // If neither is set, set assignedTo to current user
          if (userId != null) {
            updateData['assignedTo'] = userId;
          }
        }
      }
      
      // Ensure claimedBy is set if not already set
      if ((currentClaimedBy == null || currentClaimedBy.isEmpty) && userId != null) {
        updateData['claimedBy'] = userId;
      }
      
      await docRef.set(updateData, SetOptions(merge: true));
      
      debugPrint('TaskService.completeTask: Update sent for $taskId (document ID: ${doc.id})');
      
      // Send notification to job creator if job needs approval (fire and forget - don't wait)
      final needsApproval = currentData?['needsApproval'] == true;
      final jobTitle = currentData?['title'] as String? ?? 'A job';
      final creatorId = currentData?['createdBy'] as String?;
      final completerId = _auth.currentUser?.uid;
      if (needsApproval && creatorId != null && completerId != null && creatorId != completerId) {
        _notificationService.notifyJobCompleted(taskId, jobTitle, completerId).catchError((e) {
          debugPrint('Error sending completion notification: $e');
        });
      }
      
      // Verify the update succeeded by reading the document again
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        final updatedDoc = await docRef.get(GetOptions(source: Source.server));
        if (updatedDoc.exists) {
          final updatedData = updatedDoc.data() as Map<String, dynamic>?;
          final isCompleted = updatedData?['isCompleted'] as bool? ?? false;
          debugPrint('TaskService.completeTask: Verification attempt ${i + 1} for $taskId: isCompleted=$isCompleted');
          
          if (isCompleted) {
            debugPrint('TaskService.completeTask: Task $taskId successfully marked as completed');
            return;
          }
        }
      }
      
      // If verification failed, throw an error
      throw Exception('Update verification failed: task is still not marked as completed after 3 attempts');
    } catch (e) {
      debugPrint('TaskService.completeTask error: $e');
      debugPrint('Task ID: $taskId');
      rethrow;
    }
  }
  
  /// Force complete a task by ID (for fixing stuck tasks)
  Future<void> forceCompleteTask(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      final collectionPath = await _collectionPath;
      final docRef = _firestore.collection(collectionPath).doc(taskId);
      
      // First, get the current document to see what we're working with
      final currentDoc = await docRef.get(GetOptions(source: Source.server));
      if (!currentDoc.exists) {
        throw Exception('Task document does not exist at path: $collectionPath/$taskId');
      }
      
      final currentData = currentDoc.data()!;
      debugPrint('TaskService.forceCompleteTask: Current document data:');
      debugPrint('  Full data: $currentData');
      debugPrint('  isCompleted type: ${currentData['isCompleted'].runtimeType}');
      debugPrint('  isCompleted value: ${currentData['isCompleted']}');
      
      // Force set the task as completed - use set() to completely overwrite if needed
      // First try with merge
      await docRef.set({
        'isCompleted': true,
        'completedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      
      debugPrint('TaskService.forceCompleteTask: Set with merge completed');
      
      // Verify immediately
      await Future.delayed(const Duration(milliseconds: 500));
      final verifyDoc = await docRef.get(GetOptions(source: Source.server));
      if (verifyDoc.exists) {
        final verifyData = verifyDoc.data();
        final isCompleted = verifyData?['isCompleted'];
        debugPrint('TaskService.forceCompleteTask: Verification - isCompleted=$isCompleted (type: ${isCompleted.runtimeType})');
        
        // If still not true, try a different approach - get all fields and set them explicitly
        if (isCompleted != true) {
          debugPrint('TaskService.forceCompleteTask: Merge failed, trying explicit field update');
          final allData = Map<String, dynamic>.from(verifyData ?? {});
          allData['isCompleted'] = true;
          allData['completedAt'] = DateTime.now().toIso8601String();
          
          await docRef.set(allData);
          debugPrint('TaskService.forceCompleteTask: Set all fields explicitly');
          
          // Verify again
          await Future.delayed(const Duration(milliseconds: 500));
          final finalVerify = await docRef.get(GetOptions(source: Source.server));
          if (finalVerify.exists) {
            final finalData = finalVerify.data();
            debugPrint('TaskService.forceCompleteTask: Final verification - isCompleted=${finalData?['isCompleted']}');
          }
        }
      }
    } catch (e) {
      debugPrint('TaskService.forceCompleteTask error: $e');
      debugPrint('Task ID: $taskId');
      rethrow;
    }
  }
  
  /// Get detailed info about a task (for debugging)
  Future<Map<String, dynamic>?> getTaskInfo(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) return null;
    
    try {
      final collectionPath = await _collectionPath;
      final docRef = _firestore.collection(collectionPath).doc(taskId);
      final doc = await docRef.get(GetOptions(source: Source.server));
      
      if (!doc.exists) {
        debugPrint('TaskService.getTaskInfo: Document not found: $taskId');
        return {'exists': false, 'path': collectionPath};
      }
      
      final data = doc.data();
      return {
        'exists': true,
        'path': collectionPath,
        'id': doc.id,
        'data': data,
        'isCompleted': data?['isCompleted'],
        'isCompletedType': data?['isCompleted'].runtimeType.toString(),
      };
    } catch (e) {
      debugPrint('TaskService.getTaskInfo error: $e');
      return {'error': e.toString()};
    }
  }
  
  /// Delete a stuck task (last resort)
  Future<void> deleteStuckTask(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      final collectionPath = await _collectionPath;
      final docRef = _firestore.collection(collectionPath).doc(taskId);
      await docRef.delete();
      debugPrint('TaskService.deleteStuckTask: Deleted task $taskId');
    } catch (e) {
      debugPrint('TaskService.deleteStuckTask error: $e');
      rethrow;
    }
  }
  
  /// Delete a specific document by its Firestore document ID
  Future<void> deleteDocumentByDocId(String documentId) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      final collectionPath = await _collectionPath;
      debugPrint('TaskService.deleteDocumentByDocId: Attempting to delete document $documentId');
      debugPrint('  Collection path: $collectionPath');
      debugPrint('  Family ID: $familyId');
      
      final docRef = _firestore.collection(collectionPath).doc(documentId);
      
      // First check if it exists
      final doc = await docRef.get(GetOptions(source: Source.server));
      
      if (!doc.exists) {
        debugPrint('TaskService.deleteDocumentByDocId: Document $documentId does not exist');
        // Try to find it by querying for documents with that ID in the data
        final snapshot = await _firestore
            .collection(collectionPath)
            .where('id', isEqualTo: documentId)
            .get(GetOptions(source: Source.server));
        
        if (snapshot.docs.isNotEmpty) {
          debugPrint('TaskService.deleteDocumentByDocId: Found ${snapshot.docs.length} document(s) with id=$documentId in data');
          for (var doc in snapshot.docs) {
            debugPrint('  Deleting document ${doc.id}');
            await doc.reference.delete();
          }
          return;
        }
        throw Exception('Document $documentId not found');
      }
      
      final data = doc.data();
      debugPrint('TaskService.deleteDocumentByDocId: Document exists, data: $data');
      
      // Delete it
      await docRef.delete();
      debugPrint('TaskService.deleteDocumentByDocId: Delete command sent');
      
      // Verify deletion
      await Future.delayed(const Duration(milliseconds: 500));
      final verifyDoc = await docRef.get(GetOptions(source: Source.server));
      if (!verifyDoc.exists) {
        debugPrint('TaskService.deleteDocumentByDocId: Successfully deleted document $documentId');
      } else {
        debugPrint('TaskService.deleteDocumentByDocId: WARNING - Document still exists after deletion attempt');
        throw Exception('Document deletion verification failed');
      }
    } catch (e) {
      debugPrint('TaskService.deleteDocumentByDocId error: $e');
      rethrow;
    }
  }
  
  /// Delete duplicate document by querying for it
  Future<void> deleteDuplicateByTaskId(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      final collectionPath = await _collectionPath;
      debugPrint('TaskService.deleteDuplicateByTaskId: Finding duplicates for task ID $taskId');
      
      // Find all documents that have this task ID in their 'id' field
      final snapshot = await _firestore
          .collection(collectionPath)
          .where('id', isEqualTo: taskId)
          .get(GetOptions(source: Source.server));
      
      debugPrint('TaskService.deleteDuplicateByTaskId: Found ${snapshot.docs.length} document(s) with id=$taskId');
      
      final deleted = <String>[];
      for (var doc in snapshot.docs) {
        // Skip the one where document ID matches task ID (that's the correct one)
        if (doc.id != taskId) {
          debugPrint('TaskService.deleteDuplicateByTaskId: Deleting duplicate document ${doc.id}');
          await doc.reference.delete();
          deleted.add(doc.id);
        } else {
          debugPrint('TaskService.deleteDuplicateByTaskId: Keeping document ${doc.id} (document ID matches task ID)');
        }
      }
      
      if (deleted.isEmpty) {
        debugPrint('TaskService.deleteDuplicateByTaskId: No duplicates found to delete');
      } else {
        debugPrint('TaskService.deleteDuplicateByTaskId: Deleted ${deleted.length} duplicate(s): $deleted');
      }
    } catch (e) {
      debugPrint('TaskService.deleteDuplicateByTaskId error: $e');
      rethrow;
    }
  }
  
  /// Find and delete duplicate tasks
  Future<void> cleanupDuplicates() async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      final collectionPath = await _collectionPath;
      debugPrint('TaskService.cleanupDuplicates: Starting cleanup');
      
      // Get all documents directly
      final snapshot = await _firestore
          .collection(collectionPath)
          .get(GetOptions(source: Source.server));
      
      debugPrint('TaskService.cleanupDuplicates: Found ${snapshot.docs.length} documents');
      
      // Group by logical ID (from 'id' field in data)
      final logicalIdToDocs = <String, List<DocumentSnapshot>>{};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final logicalId = data['id'] as String? ?? doc.id;
        logicalIdToDocs.putIfAbsent(logicalId, () => []).add(doc);
      }
      
      final duplicatesToDelete = <String>[];
      
      for (var entry in logicalIdToDocs.entries) {
        final logicalId = entry.key;
        final docs = entry.value;
        
        if (docs.length > 1) {
          debugPrint('TaskService.cleanupDuplicates: Found ${docs.length} duplicates for logical ID $logicalId');
          
          // Find the preferred document (where doc ID matches logical ID)
          DocumentSnapshot? preferredDoc;
          for (var doc in docs) {
            if (doc.id == logicalId) {
              preferredDoc = doc;
              break;
            }
          }
          
          // If no preferred doc found, use the first one
          preferredDoc ??= docs.first;
          
          debugPrint('TaskService.cleanupDuplicates: Preferred document: ${preferredDoc.id}');
          
          // Delete all other documents
          for (var doc in docs) {
            if (doc.id != preferredDoc!.id) {
              debugPrint('TaskService.cleanupDuplicates: Deleting duplicate document ${doc.id}');
              await doc.reference.delete();
              duplicatesToDelete.add(doc.id);
            }
          }
        }
      }
      
      if (duplicatesToDelete.isEmpty) {
        debugPrint('TaskService.cleanupDuplicates: No duplicates found');
      } else {
        debugPrint('TaskService.cleanupDuplicates: Deleted ${duplicatesToDelete.length} duplicate document(s)');
      }
    } catch (e) {
      debugPrint('TaskService.cleanupDuplicates error: $e');
      rethrow;
    }
  }
  
  /// Claim a job (request to work on it)
  Future<void> claimJob(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      final collectionPath = await _collectionPath;
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');
      
      DocumentReference? docRef;
      
      // Find the document
      final directDocRef = _firestore.collection(collectionPath).doc(taskId);
      final directDoc = await directDocRef.get(GetOptions(source: Source.server));
      
      if (directDoc.exists) {
        docRef = directDocRef;
      } else {
        // Try querying by id field
        final querySnapshot = await _firestore
            .collection(collectionPath)
            .where('id', isEqualTo: taskId)
            .limit(1)
            .get(GetOptions(source: Source.server));
        
        if (querySnapshot.docs.isEmpty) {
          throw Exception('Task not found: $taskId');
        }
        
        docRef = querySnapshot.docs.first.reference;
      }
      
      if (docRef == null) {
        throw Exception('Could not determine document reference for task: $taskId');
      }
      
      // Check if already claimed
      final doc = await docRef.get(GetOptions(source: Source.server));
      if (!doc.exists) {
        throw Exception('Task not found');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      if (data['claimedBy'] != null && data['claimStatus'] == 'approved') {
        throw Exception('Job is already claimed by another member');
      }
      
      if (data['claimedBy'] == currentUserId && data['claimStatus'] == 'pending') {
        throw Exception('You have already claimed this job (pending approval)');
      }
      
      // Set claim status to pending
      await docRef.set({
        'claimedBy': currentUserId,
        'claimStatus': 'pending',
      }, SetOptions(merge: true));
      
      debugPrint('TaskService.claimJob: Job $taskId claimed by $currentUserId');
      
      // Send notification to job creator
      final jobTitle = data['title'] as String? ?? 'A job';
      final creatorId = data['createdBy'] as String?;
      if (creatorId != null && creatorId != currentUserId) {
        _notificationService.notifyJobClaimed(taskId, jobTitle, currentUserId);
      }
    } catch (e) {
      debugPrint('TaskService.claimJob error: $e');
      rethrow;
    }
  }
  
  /// Approve a claim on a job
  Future<void> approveClaim(String taskId, String claimerId) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      final collectionPath = await _collectionPath;
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');
      
      DocumentReference? docRef;
      
      // Find the document
      final directDocRef = _firestore.collection(collectionPath).doc(taskId);
      final directDoc = await directDocRef.get(GetOptions(source: Source.server));
      
      if (directDoc.exists) {
        docRef = directDocRef;
      } else {
        final querySnapshot = await _firestore
            .collection(collectionPath)
            .where('id', isEqualTo: taskId)
            .limit(1)
            .get(GetOptions(source: Source.server));
        
        if (querySnapshot.docs.isEmpty) {
          throw Exception('Task not found: $taskId');
        }
        
        docRef = querySnapshot.docs.first.reference;
      }
      
      if (docRef == null) {
        throw Exception('Could not determine document reference for task: $taskId');
      }
      
      // Verify the current user is the creator
      final doc = await docRef.get(GetOptions(source: Source.server));
      if (!doc.exists) {
        throw Exception('Task not found');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      
      // Check if user is creator OR has Approver role
      final userModel = await _authService.getCurrentUserModel();
      final isCreator = data['createdBy'] == currentUserId;
      final isApprover = userModel?.isApprover() ?? false;
      final isAdmin = userModel?.isAdmin() ?? false;
      
      if (!isCreator && !isApprover && !isAdmin) {
        throw Exception('Only the job creator, Approver, or Admin can approve claims');
      }
      
      // Approve the claim
      await docRef.set({
        'claimStatus': 'approved',
        'assignedTo': claimerId,
      }, SetOptions(merge: true));
      
      debugPrint('TaskService.approveClaim: Claim approved for job $taskId by claimer $claimerId');
    } catch (e) {
      debugPrint('TaskService.approveClaim error: $e');
      rethrow;
    }
  }
  
  /// Reject a claim on a job
  Future<void> rejectClaim(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      final collectionPath = await _collectionPath;
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');
      
      DocumentReference? docRef;
      
      // Find the document
      final directDocRef = _firestore.collection(collectionPath).doc(taskId);
      final directDoc = await directDocRef.get(GetOptions(source: Source.server));
      
      if (directDoc.exists) {
        docRef = directDocRef;
      } else {
        final querySnapshot = await _firestore
            .collection(collectionPath)
            .where('id', isEqualTo: taskId)
            .limit(1)
            .get(GetOptions(source: Source.server));
        
        if (querySnapshot.docs.isEmpty) {
          throw Exception('Task not found: $taskId');
        }
        
        docRef = querySnapshot.docs.first.reference;
      }
      
      if (docRef == null) {
        throw Exception('Could not determine document reference for task: $taskId');
      }
      
      // Verify the current user is the creator
      final doc = await docRef.get(GetOptions(source: Source.server));
      if (!doc.exists) {
        throw Exception('Task not found');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      
      // Check if user is creator OR has Approver role
      final userModel = await _authService.getCurrentUserModel();
      final isCreator = data['createdBy'] == currentUserId;
      final isApprover = userModel?.isApprover() ?? false;
      final isAdmin = userModel?.isAdmin() ?? false;
      
      if (!isCreator && !isApprover && !isAdmin) {
        throw Exception('Only the job creator, Approver, or Admin can reject claims');
      }
      
      // Reject the claim (clear claimedBy and claimStatus)
      await docRef.set({
        'claimedBy': null,
        'claimStatus': null,
        'assignedTo': '',
      }, SetOptions(merge: true));
      
      debugPrint('TaskService.rejectClaim: Claim rejected for job $taskId');
    } catch (e) {
      debugPrint('TaskService.rejectClaim error: $e');
      rethrow;
    }
  }
  
  /// Approve a completed job (for jobs that need approval)
  Future<void> approveJob(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw Exception('User not part of a family');
    
    try {
      final collectionPath = await _collectionPath;
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');
      
      DocumentReference? docRef;
      
      // Find the document
      final directDocRef = _firestore.collection(collectionPath).doc(taskId);
      final directDoc = await directDocRef.get(GetOptions(source: Source.server));
      
      if (directDoc.exists) {
        docRef = directDocRef;
      } else {
        final querySnapshot = await _firestore
            .collection(collectionPath)
            .where('id', isEqualTo: taskId)
            .limit(1)
            .get(GetOptions(source: Source.server));
        
        if (querySnapshot.docs.isEmpty) {
          throw Exception('Task not found: $taskId');
        }
        
        docRef = querySnapshot.docs.first.reference;
      }
      
      if (docRef == null) {
        throw Exception('Could not determine document reference for task: $taskId');
      }
      
      // Verify the current user is the creator
      final doc = await docRef.get(GetOptions(source: Source.server));
      if (!doc.exists) {
        throw Exception('Task not found');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      
      // Check if user is creator OR has Approver role
      final userModel = await _authService.getCurrentUserModel();
      final isCreator = data['createdBy'] == currentUserId;
      final isApprover = userModel?.isApprover() ?? false;
      final isAdmin = userModel?.isAdmin() ?? false;
      
      if (!isCreator && !isApprover && !isAdmin) {
        throw Exception('Only the job creator, Approver, or Admin can approve completion');
      }
      
      if (data['needsApproval'] != true) {
        throw Exception('This job does not require approval');
      }
      
      if (data['isCompleted'] != true) {
        throw Exception('Job must be completed before it can be approved');
      }
      
      // Approve the job
      await docRef.set({
        'approvedBy': currentUserId,
        'approvedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      
      // Pay out reward from family wallet to completer
      final reward = data['reward'] as num?;
      if (reward != null && reward > 0) {
        final completerId = data['claimedBy'] as String? ?? data['assignedTo'] as String?;
        if (completerId != null) {
          // Debit family wallet (money paid out)
          await _familyWalletService.debitFamilyWallet(reward.toDouble());
          debugPrint('TaskService.approveJob: Paid out $reward from family wallet to completer $completerId');
        }
      }
      
      debugPrint('TaskService.approveJob: Job $taskId approved by $currentUserId');
    } catch (e) {
      debugPrint('TaskService.approveJob error: $e');
      rethrow;
    }
  }

  /// Refund a completed job
  /// Returns the reward amount to the creator's wallet
  Future<void> refundJob(String taskId, String reason, {String? note}) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final collectionPath = await _collectionPath;
      final docRef = _firestore.collection(collectionPath).doc(taskId);
      final doc = await docRef.get(GetOptions(source: Source.server));

      if (!doc.exists) {
        throw Exception('Job not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Check if job is completed and approved (can only refund paid jobs)
      if (data['isCompleted'] != true) {
        throw Exception('Can only refund completed jobs');
      }
      
      if (data['isRefunded'] == true) {
        throw Exception('This job has already been refunded');
      }

      final reward = data['reward'] as num?;
      if (reward == null || reward <= 0) {
        throw Exception('This job has no reward to refund');
      }

      final creatorId = data['createdBy'] as String?;
      if (creatorId == null) {
        throw Exception('Job creator not found');
      }

      // Mark job as refunded
      await docRef.set({
        'isRefunded': true,
        'refundReason': reason,
        'refundNote': note,
        'refundedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      // Credit family wallet (return the money)
      await _familyWalletService.creditFamilyWallet(reward.toDouble());
      debugPrint('TaskService.refundJob: Credited $reward to family wallet');

      // Send notification to creator
      final jobTitle = data['title'] as String? ?? 'A job';
      await _notificationService.notifyJobRefunded(taskId, jobTitle, reason, note);
      
      debugPrint('TaskService.refundJob: Job $taskId refunded by $currentUserId');
    } catch (e) {
      debugPrint('TaskService.refundJob error: $e');
      rethrow;
    }
  }
}
