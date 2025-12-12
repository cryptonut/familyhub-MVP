import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/logger_service.dart';
import '../models/task.dart';
import '../models/task_dependency.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'package:uuid/uuid.dart';

class TaskDependencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  /// Add a dependency to a task
  Future<void> addDependency(String taskId, String dependsOnTaskId, DependencyType type, String familyId) async {
    try {
      // Check for circular dependencies
      if (await _hasCircularDependency(taskId, dependsOnTaskId, familyId)) {
        throw Exception('Circular dependency detected');
      }

      final dependencyId = const Uuid().v4();
      final dependency = TaskDependency(
        id: dependencyId,
        taskId: taskId,
        dependsOnTaskId: dependsOnTaskId,
        type: type,
      );

      await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection('tasks')
          .doc(taskId)
          .collection('dependencies')
          .doc(dependencyId)
          .set(dependency.toJson());

      // Update task status if blocked
      await _updateTaskBlockedStatus(taskId, familyId);

      Logger.info('Dependency added: $taskId depends on $dependsOnTaskId', tag: 'TaskDependencyService');
    } catch (e, st) {
      Logger.error('Error adding dependency', error: e, stackTrace: st, tag: 'TaskDependencyService');
      rethrow;
    }
  }

  /// Remove a dependency
  Future<void> removeDependency(String taskId, String dependencyId, String familyId) async {
    try {
      await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection('tasks')
          .doc(taskId)
          .collection('dependencies')
          .doc(dependencyId)
          .delete();

      // Update task status
      await _updateTaskBlockedStatus(taskId, familyId);

      Logger.info('Dependency removed: $dependencyId', tag: 'TaskDependencyService');
    } catch (e, st) {
      Logger.error('Error removing dependency', error: e, stackTrace: st, tag: 'TaskDependencyService');
      rethrow;
    }
  }

  /// Get dependencies for a task
  Future<List<TaskDependency>> getDependencies(String taskId, String familyId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection('tasks')
          .doc(taskId)
          .collection('dependencies')
          .get();

      return snapshot.docs
          .map((doc) => TaskDependency.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e, st) {
      Logger.error('Error getting dependencies', error: e, stackTrace: st, tag: 'TaskDependencyService');
      return [];
    }
  }

  /// Get tasks that depend on this task
  Future<List<Task>> getDependentTasks(String taskId, String familyId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection('tasks')
          .where('dependencies', arrayContains: taskId)
          .get();

      return snapshot.docs
          .map((doc) => Task.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e, st) {
      Logger.error('Error getting dependent tasks', error: e, stackTrace: st, tag: 'TaskDependencyService');
      return [];
    }
  }

  /// Check if a task is blocked by dependencies
  Future<bool> isTaskBlocked(Task task, String familyId) async {
    try {
      final dependencies = await getDependencies(task.id, familyId);
      if (dependencies.isEmpty) return false;

      for (var dependency in dependencies) {
        if (dependency.type == DependencyType.hard) {
          final dependsOnTask = await _firestore
              .collection('families')
              .doc(familyId)
              .collection('tasks')
              .doc(dependency.dependsOnTaskId)
              .get();

          if (dependsOnTask.exists) {
            final dependsOnTaskData = dependsOnTask.data();
            final isCompleted = dependsOnTaskData?['isCompleted'] == true;
            if (!isCompleted) {
              return true; // Blocked
            }
          }
        }
      }

      return false;
    } catch (e, st) {
      Logger.error('Error checking if task is blocked', error: e, stackTrace: st, tag: 'TaskDependencyService');
      return false;
    }
  }

  /// Update task blocked status when a dependency completes
  Future<void> checkAndUpdateBlockedStatus(String completedTaskId, String familyId) async {
    try {
      final dependentTasks = await getDependentTasks(completedTaskId, familyId);
      for (var task in dependentTasks) {
        await _updateTaskBlockedStatus(task.id, familyId);
      }
    } catch (e, st) {
      Logger.error('Error updating blocked status', error: e, stackTrace: st, tag: 'TaskDependencyService');
    }
  }

  Future<void> _updateTaskBlockedStatus(String taskId, String familyId) async {
    try {
      final taskDoc = await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection('tasks')
          .doc(taskId)
          .get();

      if (!taskDoc.exists) return;

      final task = Task.fromJson({
        'id': taskDoc.id,
        ...taskDoc.data()!,
      });

      final isBlocked = await isTaskBlocked(task, familyId);
      await taskDoc.reference.update({
        'status': isBlocked ? 'blocked' : 'pending',
      });
    } catch (e, st) {
      Logger.error('Error updating task blocked status', error: e, stackTrace: st, tag: 'TaskDependencyService');
    }
  }

  Future<bool> _hasCircularDependency(String taskId, String dependsOnTaskId, String familyId) async {
    // Simple check: if dependsOnTaskId depends on taskId, it's circular
    final reverseDeps = await getDependencies(dependsOnTaskId, familyId);
    return reverseDeps.any((dep) => dep.dependsOnTaskId == taskId);
  }
}

