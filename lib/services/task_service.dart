import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';
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
      Logger.debug('_familyId: FamilyId changed from $_cachedFamilyId to $freshFamilyId', tag: 'TaskService');
      _cachedFamilyId = freshFamilyId;
    }
    
    return _cachedFamilyId;
  }
  
  /// Clear the cached familyId (useful when familyId might have changed)
  void clearFamilyIdCache() {
    Logger.debug('clearFamilyIdCache: Clearing cached familyId', tag: 'TaskService');
    _cachedFamilyId = null;
  }

  Future<String> get _collectionPath async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    return 'families/$familyId/tasks';
  }

  Future<List<Task>> getTasks({bool forceRefresh = false}) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getTasks: User not part of a family', tag: 'TaskService');
      return [];
    }
    
    try {
      final collectionPath = 'families/$familyId/tasks';
      Logger.debug('getTasks: Loading tasks from $collectionPath', tag: 'TaskService');
      
      QuerySnapshot snapshot;
      try {
        snapshot = await _firestore
            .collection(collectionPath)
            .orderBy('createdAt', descending: true)
            .get(GetOptions(source: forceRefresh ? Source.server : Source.cache));
      } catch (e, st) {
        Logger.warning('getTasks: orderBy failed, trying without orderBy', error: e, stackTrace: st, tag: 'TaskService');
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
        } catch (e, st) {
          Logger.warning('getTasks: Error parsing task ${doc.id}', error: e, stackTrace: st, tag: 'TaskService');
          return null;
        }
      }).whereType<Task>().toList();
      
      // Sort by createdAt if we didn't use orderBy
      if (tasks.isNotEmpty && tasks.any((t) => t.createdAt != null)) {
        tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      Logger.debug('getTasks: Successfully loaded ${tasks.length} tasks', tag: 'TaskService');
      return tasks;
    } catch (e, stackTrace) {
      Logger.error('getTasks error', error: e, stackTrace: stackTrace, tag: 'TaskService');
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
      Logger.debug('getActiveTasks: Found ${active.length} active tasks out of ${allTasks.length} total', tag: 'TaskService');
      return active;
    } catch (e, st) {
      Logger.error('getActiveTasks error', error: e, stackTrace: st, tag: 'TaskService');
      return [];
    }
  }

  Future<List<Task>> getCompletedTasks({bool forceRefresh = false}) async {
    try {
      final allTasks = await getTasks(forceRefresh: forceRefresh);
      final completed = allTasks.where((task) => task.isCompleted).toList();
      Logger.debug('getCompletedTasks: Found ${completed.length} completed tasks out of ${allTasks.length} total', tag: 'TaskService');
      return completed;
    } catch (e, st) {
      Logger.error('getCompletedTasks error', error: e, stackTrace: st, tag: 'TaskService');
      return [];
    }
  }

  Future<void> addTask(Task task) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    // Track if wallet was credited in case we need to rollback
    bool walletCredited = false;
    double? creditedAmount;
    
    try {
      // If task has a reward, handle family wallet and balance checks
      if (task.reward != null && task.reward! > 0) {
        final rewardAmount = task.reward!;
        final userModel = await _authService.getCurrentUserModel();
        if (userModel == null) throw AuthException('User not authenticated', code: 'not-authenticated');
        
        // Get all tasks to pass to canCreateJobWithReward (to avoid circular dependency)
        final allTasks = await getTasks();
        
        // Check if user can create job with this reward
        final canCreate = await _familyWalletService.canCreateJobWithReward(rewardAmount, allTasks);
        
        if (!canCreate['canCreate'] as bool) {
          throw ValidationException(canCreate['reason'] as String);
        }
        
        // Credit family wallet with the full reward amount
        await _familyWalletService.creditFamilyWallet(rewardAmount);
        walletCredited = true;
        creditedAmount = rewardAmount;
        Logger.info('addTask: Credited $rewardAmount to family wallet', tag: 'TaskService');
      }
      
      final collectionPath = 'families/$familyId/tasks';
      Logger.debug('addTask: Adding task ${task.id} to $collectionPath', tag: 'TaskService');
      
      // Remove 'id' from the data since it's used as the document ID
      final data = task.toJson();
      data.remove('id');
      
      // Use set() with the task.id as document ID to ensure consistent IDs
      final docRef = _firestore.collection(collectionPath).doc(task.id);
      await docRef.set(data);
      
      Logger.info('addTask: Task ${task.id} written to Firestore successfully', tag: 'TaskService');
      
      // Verify the task was actually written
      final verifyDoc = await docRef.get();
      if (!verifyDoc.exists) {
        throw FirestoreException('Task was not saved to Firestore - verification failed', code: 'verification-failed');
      }
      
      Logger.debug('addTask: Task ${task.id} verified in Firestore', tag: 'TaskService');
    } catch (e, st) {
      Logger.error('addTask error', error: e, stackTrace: st, tag: 'TaskService');
      
      // If wallet was credited but task save failed, try to rollback
      if (walletCredited && creditedAmount != null) {
        try {
          Logger.warning('addTask: Attempting to rollback wallet credit of $creditedAmount', tag: 'TaskService');
          await _familyWalletService.debitFamilyWallet(creditedAmount!);
          Logger.info('addTask: Wallet credit rolled back successfully', tag: 'TaskService');
        } catch (rollbackError, rollbackSt) {
          Logger.error('addTask: Failed to rollback wallet credit', error: rollbackError, stackTrace: rollbackSt, tag: 'TaskService');
          // Don't throw here - the original error is more important
        }
      }
      
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final docRef = _firestore.collection('families/$familyId/tasks').doc(task.id);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw FirestoreException('Task not found. Cannot update a task that does not exist.', code: 'not-found');
      }
      
      // Remove 'id' from the data since it's used as the document ID
      final data = task.toJson();
      data.remove('id');
      
      // Use update() since we've confirmed the document exists
      await docRef.update(data);
      
      Logger.info('updateTask: Successfully updated task ${task.id}', tag: 'TaskService');
    } catch (e, st) {
      Logger.error('updateTask error', error: e, stackTrace: st, tag: 'TaskService');
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    final docRef = _firestore.collection('families/$familyId/tasks').doc(taskId);
    final taskDoc = await docRef.get();
    
    if (!taskDoc.exists) {
      throw FirestoreException('Task not found', code: 'not-found');
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
        Logger.info('deleteTask: Returning $reward to creator $createdBy', tag: 'TaskService');
      }
    }
    
    await docRef.delete();
  }

  Future<void> toggleTaskCompletion(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final collectionPath = await _collectionPath;
      final docRef = _firestore.collection(collectionPath).doc(taskId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        Logger.warning('toggleTaskCompletion: Document not found: $taskId', tag: 'TaskService');
        return;
      }

      final task = Task.fromJson({'id': doc.id, ...doc.data()!});
      final newCompletedState = !task.isCompleted;
      
      // Use update() to ensure atomic operation
      await docRef.update({
        'isCompleted': newCompletedState,
        'completedAt': newCompletedState ? DateTime.now().toIso8601String() : null,
      });
      
      Logger.debug('toggleTaskCompletion: Task $taskId set to completed=$newCompletedState', tag: 'TaskService');
    } catch (e, st) {
      Logger.error('toggleTaskCompletion error', error: e, stackTrace: st, tag: 'TaskService');
      Logger.debug('Task ID: $taskId', tag: 'TaskService');
      rethrow;
    }
  }

  /// Mark a task as completed (always sets to true, doesn't toggle)
  Future<void> completeTask(String taskId) async {
    final familyId = await _familyId;
    final userId = _auth.currentUser?.uid;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    if (userId == null) throw AuthException('User not authenticated', code: 'not-authenticated');
    
    try {
      final docRef = _firestore.collection('families/$familyId/tasks').doc(taskId);
      final doc = await docRef.get(GetOptions(source: Source.server));
      
      if (!doc.exists) {
        throw FirestoreException('Task not found: $taskId', code: 'not-found');
      }
      
      final currentData = doc.data() as Map<String, dynamic>?;
      Logger.debug('completeTask: Current task data for $taskId:', tag: 'TaskService');
      Logger.debug('  - Document ID: ${doc.id}', tag: 'TaskService');
      Logger.debug('  - isCompleted: ${currentData?['isCompleted']}', tag: 'TaskService');
      Logger.debug('  - title: ${currentData?['title']}', tag: 'TaskService');
      Logger.debug('  - All fields: ${currentData?.keys.toList()}', tag: 'TaskService');

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
      
      Logger.debug('completeTask: Update sent for $taskId (document ID: ${doc.id})', tag: 'TaskService');
      
      // Send notification to job creator if job needs approval (fire and forget - don't wait)
      final needsApproval = currentData?['needsApproval'] == true;
      final jobTitle = currentData?['title'] as String? ?? 'A job';
      final creatorId = currentData?['createdBy'] as String?;
      final completerId = _auth.currentUser?.uid;
      if (needsApproval && creatorId != null && completerId != null && creatorId != completerId) {
        _notificationService.notifyJobCompleted(taskId, jobTitle, completerId).catchError((e, st) {
          Logger.warning('Error sending completion notification', error: e, stackTrace: st, tag: 'TaskService');
        });
      }
      
      // Verify the update succeeded by reading the document again
      for (int i = 0; i < AppConstants.maxRetries; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        final updatedDoc = await docRef.get(GetOptions(source: Source.server));
        if (updatedDoc.exists) {
          final updatedData = updatedDoc.data() as Map<String, dynamic>?;
          final isCompleted = updatedData?['isCompleted'] as bool? ?? false;
          Logger.debug('completeTask: Verification attempt ${i + 1} for $taskId: isCompleted=$isCompleted', tag: 'TaskService');
          
          if (isCompleted) {
            Logger.info('completeTask: Task $taskId successfully marked as completed', tag: 'TaskService');
            return;
          }
        }
      }
      
      // If verification failed, throw an error
      throw FirestoreException('Update verification failed: task is still not marked as completed after ${AppConstants.maxRetries} attempts', code: 'verification-failed');
    } catch (e, st) {
      Logger.error('completeTask error', error: e, stackTrace: st, tag: 'TaskService');
      Logger.debug('Task ID: $taskId', tag: 'TaskService');
      rethrow;
    }
  }
  
  /// Force complete a task by ID (for fixing stuck tasks)
  Future<void> forceCompleteTask(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final collectionPath = await _collectionPath;
      final docRef = _firestore.collection(collectionPath).doc(taskId);
      
      // First, get the current document to see what we're working with
      final currentDoc = await docRef.get(GetOptions(source: Source.server));
      if (!currentDoc.exists) {
        throw FirestoreException('Task document does not exist at path: $collectionPath/$taskId', code: 'not-found');
      }
      
      final currentData = currentDoc.data()!;
      Logger.debug('forceCompleteTask: Current document data:', tag: 'TaskService');
      Logger.debug('  Full data: $currentData', tag: 'TaskService');
      Logger.debug('  isCompleted type: ${currentData['isCompleted'].runtimeType}', tag: 'TaskService');
      Logger.debug('  isCompleted value: ${currentData['isCompleted']}', tag: 'TaskService');
      
      // Force set the task as completed - use set() to completely overwrite if needed
      // First try with merge
      await docRef.set({
        'isCompleted': true,
        'completedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      
      Logger.debug('forceCompleteTask: Set with merge completed', tag: 'TaskService');
      
      // Verify immediately
      await Future.delayed(const Duration(milliseconds: 500));
      final verifyDoc = await docRef.get(GetOptions(source: Source.server));
      if (verifyDoc.exists) {
        final verifyData = verifyDoc.data();
        final isCompleted = verifyData?['isCompleted'];
        Logger.debug('forceCompleteTask: Verification - isCompleted=$isCompleted (type: ${isCompleted.runtimeType})', tag: 'TaskService');
        
        // If still not true, try a different approach - get all fields and set them explicitly
        if (isCompleted != true) {
          Logger.warning('forceCompleteTask: Merge failed, trying explicit field update', tag: 'TaskService');
          final allData = Map<String, dynamic>.from(verifyData ?? {});
          allData['isCompleted'] = true;
          allData['completedAt'] = DateTime.now().toIso8601String();
          
          await docRef.set(allData);
          Logger.debug('forceCompleteTask: Set all fields explicitly', tag: 'TaskService');
          
          // Verify again
          await Future.delayed(const Duration(milliseconds: 500));
          final finalVerify = await docRef.get(GetOptions(source: Source.server));
          if (finalVerify.exists) {
            final finalData = finalVerify.data();
            Logger.debug('forceCompleteTask: Final verification - isCompleted=${finalData?['isCompleted']}', tag: 'TaskService');
          }
        }
      }
    } catch (e, st) {
      Logger.error('forceCompleteTask error', error: e, stackTrace: st, tag: 'TaskService');
      Logger.debug('Task ID: $taskId', tag: 'TaskService');
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
        Logger.warning('getTaskInfo: Document not found: $taskId', tag: 'TaskService');
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
    } catch (e, st) {
      Logger.error('getTaskInfo error', error: e, stackTrace: st, tag: 'TaskService');
      return {'error': e.toString()};
    }
  }
  
  /// Delete a stuck task (last resort)
  Future<void> deleteStuckTask(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final collectionPath = await _collectionPath;
      final docRef = _firestore.collection(collectionPath).doc(taskId);
      await docRef.delete();
      Logger.info('deleteStuckTask: Deleted task $taskId', tag: 'TaskService');
    } catch (e, st) {
      Logger.error('deleteStuckTask error', error: e, stackTrace: st, tag: 'TaskService');
      rethrow;
    }
  }
  
  /// Delete a specific document by its Firestore document ID
  Future<void> deleteDocumentByDocId(String documentId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final collectionPath = await _collectionPath;
      Logger.debug('deleteDocumentByDocId: Attempting to delete document $documentId', tag: 'TaskService');
      Logger.debug('  Collection path: $collectionPath', tag: 'TaskService');
      Logger.debug('  Family ID: $familyId', tag: 'TaskService');
      
      final docRef = _firestore.collection(collectionPath).doc(documentId);
      
      // First check if it exists
      final doc = await docRef.get(GetOptions(source: Source.server));
      
      if (!doc.exists) {
        Logger.warning('deleteDocumentByDocId: Document $documentId does not exist', tag: 'TaskService');
        // Try to find it by querying for documents with that ID in the data
        final snapshot = await _firestore
            .collection(collectionPath)
            .where('id', isEqualTo: documentId)
            .get(GetOptions(source: Source.server));
        
        if (snapshot.docs.isNotEmpty) {
          Logger.debug('deleteDocumentByDocId: Found ${snapshot.docs.length} document(s) with id=$documentId in data', tag: 'TaskService');
          for (var doc in snapshot.docs) {
            Logger.debug('  Deleting document ${doc.id}', tag: 'TaskService');
            await doc.reference.delete();
          }
          return;
        }
        throw FirestoreException('Document $documentId not found', code: 'not-found');
      }
      
      final data = doc.data();
      Logger.debug('deleteDocumentByDocId: Document exists, data: $data', tag: 'TaskService');
      
      // Delete it
      await docRef.delete();
      Logger.debug('deleteDocumentByDocId: Delete command sent', tag: 'TaskService');
      
      // Verify deletion
      await Future.delayed(const Duration(milliseconds: 500));
      final verifyDoc = await docRef.get(GetOptions(source: Source.server));
      if (!verifyDoc.exists) {
        Logger.info('deleteDocumentByDocId: Successfully deleted document $documentId', tag: 'TaskService');
      } else {
        Logger.warning('deleteDocumentByDocId: WARNING - Document still exists after deletion attempt', tag: 'TaskService');
        throw FirestoreException('Document deletion verification failed', code: 'verification-failed');
      }
    } catch (e, st) {
      Logger.error('deleteDocumentByDocId error', error: e, stackTrace: st, tag: 'TaskService');
      rethrow;
    }
  }
  
  /// Delete duplicate document by querying for it
  Future<void> deleteDuplicateByTaskId(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final collectionPath = await _collectionPath;
      Logger.debug('deleteDuplicateByTaskId: Finding duplicates for task ID $taskId', tag: 'TaskService');
      
      // Find all documents that have this task ID in their 'id' field
      final snapshot = await _firestore
          .collection(collectionPath)
          .where('id', isEqualTo: taskId)
          .get(GetOptions(source: Source.server));
      
      Logger.debug('deleteDuplicateByTaskId: Found ${snapshot.docs.length} document(s) with id=$taskId', tag: 'TaskService');
      
      final deleted = <String>[];
      for (var doc in snapshot.docs) {
        // Skip the one where document ID matches task ID (that's the correct one)
        if (doc.id != taskId) {
          Logger.debug('deleteDuplicateByTaskId: Deleting duplicate document ${doc.id}', tag: 'TaskService');
          await doc.reference.delete();
          deleted.add(doc.id);
        } else {
          Logger.debug('deleteDuplicateByTaskId: Keeping document ${doc.id} (document ID matches task ID)', tag: 'TaskService');
        }
      }
      
      if (deleted.isEmpty) {
        Logger.debug('deleteDuplicateByTaskId: No duplicates found to delete', tag: 'TaskService');
      } else {
        Logger.info('deleteDuplicateByTaskId: Deleted ${deleted.length} duplicate(s): $deleted', tag: 'TaskService');
      }
    } catch (e) {
      Logger.error('deleteDuplicateByTaskId error', error: e, tag: 'TaskService');
      rethrow;
    }
  }
  
  /// Find and delete duplicate tasks
  Future<void> cleanupDuplicates() async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final collectionPath = await _collectionPath;
      Logger.info('cleanupDuplicates: Starting cleanup', tag: 'TaskService');
      
      // Get all documents directly
      final snapshot = await _firestore
          .collection(collectionPath)
          .get(GetOptions(source: Source.server));
      
      Logger.debug('cleanupDuplicates: Found ${snapshot.docs.length} documents', tag: 'TaskService');
      
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
          Logger.debug('cleanupDuplicates: Found ${docs.length} duplicates for logical ID $logicalId', tag: 'TaskService');
          
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
          
          Logger.debug('cleanupDuplicates: Preferred document: ${preferredDoc.id}', tag: 'TaskService');
          
          // Delete all other documents
          for (var doc in docs) {
            if (doc.id != preferredDoc!.id) {
              Logger.debug('cleanupDuplicates: Deleting duplicate document ${doc.id}', tag: 'TaskService');
              await doc.reference.delete();
              duplicatesToDelete.add(doc.id);
            }
          }
        }
      }
      
      if (duplicatesToDelete.isEmpty) {
        Logger.info('cleanupDuplicates: No duplicates found', tag: 'TaskService');
      } else {
        Logger.info('cleanupDuplicates: Deleted ${duplicatesToDelete.length} duplicate document(s)', tag: 'TaskService');
      }
    } catch (e) {
      Logger.cleanupDuplicates error: $e');
      rethrow;
    }
  }
  
  /// Claim a job (request to work on it)
  Future<void> claimJob(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final collectionPath = await _collectionPath;
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated', code: 'not-authenticated');
      
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
          throw FirestoreException('Task not found: $taskId', code: 'not-found');
        }
        
        docRef = querySnapshot.docs.first.reference;
      }
      
      if (docRef == null) {
        throw FirestoreException('Could not determine document reference for task: $taskId', code: 'reference-not-found');
      }
      
      // Check if already claimed
      final doc = await docRef.get(GetOptions(source: Source.server));
      if (!doc.exists) {
        throw FirestoreException('Task not found', code: 'not-found');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      if (data['claimedBy'] != null && data['claimStatus'] == 'approved') {
        throw ValidationException('Job is already claimed by another member', code: 'already-claimed');
      }
      
      if (data['claimedBy'] == currentUserId && data['claimStatus'] == 'pending') {
        throw ValidationException('You have already claimed this job (pending approval)', code: 'already-claimed');
      }
      
      // Set claim status to pending
      await docRef.set({
        'claimedBy': currentUserId,
        'claimStatus': 'pending',
      }, SetOptions(merge: true));
      
      Logger.info('claimJob: Job $taskId claimed by $currentUserId', tag: 'TaskService');
      
      // Send notification to job creator
      final jobTitle = data['title'] as String? ?? 'A job';
      final creatorId = data['createdBy'] as String?;
      if (creatorId != null && creatorId != currentUserId) {
        _notificationService.notifyJobClaimed(taskId, jobTitle, currentUserId);
      }
    } catch (e) {
      Logger.error('claimJob error', error: e, tag: 'TaskService');
      rethrow;
    }
  }
  
  /// Approve a claim on a job
  Future<void> approveClaim(String taskId, String claimerId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final collectionPath = await _collectionPath;
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated', code: 'not-authenticated');
      
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
          throw FirestoreException('Task not found: $taskId', code: 'not-found');
        }
        
        docRef = querySnapshot.docs.first.reference;
      }
      
      if (docRef == null) {
        throw FirestoreException('Could not determine document reference for task: $taskId', code: 'reference-not-found');
      }
      
      // Verify the current user is the creator
      final doc = await docRef.get(GetOptions(source: Source.server));
      if (!doc.exists) {
        throw FirestoreException('Task not found', code: 'not-found');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      
      // Check if user is creator OR has Approver role
      final userModel = await _authService.getCurrentUserModel();
      final isCreator = data['createdBy'] == currentUserId;
      final isApprover = userModel?.isApprover() ?? false;
      final isAdmin = userModel?.isAdmin() ?? false;
      
      if (!isCreator && !isApprover && !isAdmin) {
        throw PermissionException('Only the job creator, Approver, or Admin can approve claims', code: 'insufficient-permissions');
      }
      
      // Approve the claim
      await docRef.set({
        'claimStatus': 'approved',
        'assignedTo': claimerId,
      }, SetOptions(merge: true));
      
      Logger.info('approveClaim: Claim approved for job $taskId by claimer $claimerId', tag: 'TaskService');
    } catch (e) {
      Logger.error('approveClaim error', error: e, tag: 'TaskService');
      rethrow;
    }
  }
  
  /// Reject a claim on a job
  Future<void> rejectClaim(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final collectionPath = await _collectionPath;
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated', code: 'not-authenticated');
      
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
          throw FirestoreException('Task not found: $taskId', code: 'not-found');
        }
        
        docRef = querySnapshot.docs.first.reference;
      }
      
      if (docRef == null) {
        throw FirestoreException('Could not determine document reference for task: $taskId', code: 'reference-not-found');
      }
      
      // Verify the current user is the creator
      final doc = await docRef.get(GetOptions(source: Source.server));
      if (!doc.exists) {
        throw FirestoreException('Task not found', code: 'not-found');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      
      // Check if user is creator OR has Approver role
      final userModel = await _authService.getCurrentUserModel();
      final isCreator = data['createdBy'] == currentUserId;
      final isApprover = userModel?.isApprover() ?? false;
      final isAdmin = userModel?.isAdmin() ?? false;
      
      if (!isCreator && !isApprover && !isAdmin) {
        throw PermissionException('Only the job creator, Approver, or Admin can reject claims', code: 'insufficient-permissions');
      }
      
      // Reject the claim (clear claimedBy and claimStatus)
      await docRef.set({
        'claimedBy': null,
        'claimStatus': null,
        'assignedTo': '',
      }, SetOptions(merge: true));
      
      Logger.info('rejectClaim: Claim rejected for job $taskId', tag: 'TaskService');
    } catch (e) {
      Logger.error('rejectClaim error', error: e, tag: 'TaskService');
      rethrow;
    }
  }
  
  /// Approve a completed job (for jobs that need approval)
  Future<void> approveJob(String taskId) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      final collectionPath = await _collectionPath;
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw AuthException('User not authenticated', code: 'not-authenticated');
      
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
          throw FirestoreException('Task not found: $taskId', code: 'not-found');
        }
        
        docRef = querySnapshot.docs.first.reference;
      }
      
      if (docRef == null) {
        throw FirestoreException('Could not determine document reference for task: $taskId', code: 'reference-not-found');
      }
      
      // Verify the current user is the creator
      final doc = await docRef.get(GetOptions(source: Source.server));
      if (!doc.exists) {
        throw FirestoreException('Task not found', code: 'not-found');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      
      // Check if user is creator OR has Approver role
      final userModel = await _authService.getCurrentUserModel();
      final isCreator = data['createdBy'] == currentUserId;
      final isApprover = userModel?.isApprover() ?? false;
      final isAdmin = userModel?.isAdmin() ?? false;
      
      if (!isCreator && !isApprover && !isAdmin) {
        throw PermissionException('Only the job creator, Approver, or Admin can approve completion', code: 'insufficient-permissions');
      }
      
      if (data['needsApproval'] != true) {
        throw ValidationException('This job does not require approval', code: 'no-approval-needed');
      }
      
      if (data['isCompleted'] != true) {
        throw ValidationException('Job must be completed before it can be approved', code: 'not-completed');
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
          Logger.info('approveJob: Paid out $reward from family wallet to completer $completerId', tag: 'TaskService');
        }
      }
      
      Logger.info('approveJob: Job $taskId approved by $currentUserId', tag: 'TaskService');
    } catch (e) {
      Logger.error('approveJob error', error: e, tag: 'TaskService');
      rethrow;
    }
  }

  /// Refund a completed job
  /// Returns the reward amount to the creator's wallet
  Future<void> refundJob(String taskId, String reason, {String? note}) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        throw AuthException('User not authenticated', code: 'not-authenticated');
      }

      final collectionPath = await _collectionPath;
      final docRef = _firestore.collection(collectionPath).doc(taskId);
      final doc = await docRef.get(GetOptions(source: Source.server));

      if (!doc.exists) {
        throw FirestoreException('Job not found', code: 'not-found');
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Check if job is completed and approved (can only refund paid jobs)
      if (data['isCompleted'] != true) {
        throw ValidationException('Can only refund completed jobs', code: 'not-completed');
      }
      
      if (data['isRefunded'] == true) {
        throw ValidationException('This job has already been refunded', code: 'already-refunded');
      }

      final reward = data['reward'] as num?;
      if (reward == null || reward <= 0) {
        throw ValidationException('This job has no reward to refund', code: 'no-reward');
      }

      final creatorId = data['createdBy'] as String?;
      if (creatorId == null) {
        throw FirestoreException('Job creator not found', code: 'creator-not-found');
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
      Logger.info('refundJob: Credited $reward to family wallet', tag: 'TaskService');

      // Send notification to creator
      final jobTitle = data['title'] as String? ?? 'A job';
      await _notificationService.notifyJobRefunded(taskId, jobTitle, reason, note);
      
      Logger.info('refundJob: Job $taskId refunded by $currentUserId', tag: 'TaskService');
    } catch (e) {
      Logger.refundJob error: $e');
      rethrow;
    }
  }
}
