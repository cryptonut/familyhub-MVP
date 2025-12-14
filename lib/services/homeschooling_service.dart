import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/student_profile.dart';
import '../models/assignment.dart';
import '../models/lesson_plan.dart';
import '../models/hub.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'hub_service.dart';
import 'subscription_service.dart';

/// Service for managing homeschooling hub features
class HomeschoolingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final HubService _hubService = HubService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final Uuid _uuid = const Uuid();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Create student profile
  Future<StudentProfile> createStudentProfile({
    required String hubId,
    required String userId,
    required String name,
    DateTime? dateOfBirth,
    String? gradeLevel,
    List<String>? subjects,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    // Verify hub is homeschooling type
    final hub = await _hubService.getHub(hubId);
    if (hub == null) {
      throw NotFoundException('Hub not found', code: 'hub-not-found');
    }

    if (hub.hubType != HubType.homeschooling) {
      throw ValidationException('Hub must be homeschooling type', code: 'invalid-hub-type');
    }

    // Verify user has premium access
    final hasAccess = await _subscriptionService.hasPremiumHubAccess('homeschooling');
    if (!hasAccess) {
      throw PermissionException(
        'Premium subscription required for homeschooling hubs',
        code: 'premium-required',
      );
    }

    try {
      final profile = StudentProfile(
        id: _uuid.v4(),
        hubId: hubId,
        userId: userId,
        name: name,
        dateOfBirth: dateOfBirth,
        gradeLevel: gradeLevel,
        subjects: subjects ?? [],
        createdAt: DateTime.now(),
        createdBy: currentUserId,
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'student_profiles'))
          .doc(profile.id)
          .set(profile.toJson());

      Logger.info('Student profile created: ${profile.id}', tag: 'HomeschoolingService');
      return profile;
    } catch (e) {
      Logger.error('Error creating student profile', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }

  /// Get student profiles for a hub
  Future<List<StudentProfile>> getStudentProfiles(String hubId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'student_profiles'))
          .get();

      return snapshot.docs
          .map((doc) => StudentProfile.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting student profiles', error: e, tag: 'HomeschoolingService');
      return [];
    }
  }

  /// Update student profile
  Future<void> updateStudentProfile(
    String hubId,
    String profileId, {
    String? name,
    DateTime? dateOfBirth,
    String? gradeLevel,
    List<String>? subjects,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final updates = <String, dynamic>{};

      if (name != null) {
        updates['name'] = name;
      }
      if (dateOfBirth != null) {
        updates['dateOfBirth'] = dateOfBirth.toIso8601String();
      }
      if (gradeLevel != null) {
        updates['gradeLevel'] = gradeLevel;
      }
      if (subjects != null) {
        updates['subjects'] = subjects;
      }

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'student_profiles'))
          .doc(profileId)
          .update(updates);

      Logger.info('Student profile updated: $profileId', tag: 'HomeschoolingService');
    } catch (e) {
      Logger.error('Error updating student profile', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }

  /// Delete student profile
  Future<void> deleteStudentProfile(String hubId, String profileId) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'student_profiles'))
          .doc(profileId)
          .delete();

      Logger.info('Student profile deleted: $profileId', tag: 'HomeschoolingService');
    } catch (e) {
      Logger.error('Error deleting student profile', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }

  /// Create assignment
  Future<Assignment> createAssignment({
    required String hubId,
    required String studentId,
    required String subject,
    required String title,
    String? description,
    required DateTime dueDate,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final assignment = Assignment(
        id: _uuid.v4(),
        hubId: hubId,
        studentId: studentId,
        subject: subject,
        title: title,
        description: description,
        dueDate: dueDate,
        createdAt: DateTime.now(),
        createdBy: currentUserId,
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'assignments'))
          .doc(assignment.id)
          .set(assignment.toJson());

      Logger.info('Assignment created: ${assignment.id}', tag: 'HomeschoolingService');
      return assignment;
    } catch (e) {
      Logger.error('Error creating assignment', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }

  /// Get assignments for a student
  Future<List<Assignment>> getAssignments({
    required String hubId,
    String? studentId,
    AssignmentStatus? status,
  }) async {
    try {
      var query = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'assignments'))
          .orderBy('dueDate', descending: false);

      if (studentId != null) {
        query = query.where('studentId', isEqualTo: studentId);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => Assignment.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting assignments', error: e, tag: 'HomeschoolingService');
      return [];
    }
  }

  /// Create lesson plan
  Future<LessonPlan> createLessonPlan({
    required String hubId,
    required String subject,
    required String title,
    String? description,
    List<String>? learningObjectives,
    List<String>? resources,
    DateTime? scheduledDate,
    int? estimatedDurationMinutes,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final lessonPlan = LessonPlan(
        id: _uuid.v4(),
        hubId: hubId,
        subject: subject,
        title: title,
        description: description,
        learningObjectives: learningObjectives ?? [],
        resources: resources ?? [],
        scheduledDate: scheduledDate,
        estimatedDurationMinutes: estimatedDurationMinutes ?? 60,
        createdAt: DateTime.now(),
        createdBy: currentUserId,
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'lessonPlans'))
          .doc(lessonPlan.id)
          .set(lessonPlan.toJson());

      Logger.info('Lesson plan created: ${lessonPlan.id}', tag: 'HomeschoolingService');
      return lessonPlan;
    } catch (e) {
      Logger.error('Error creating lesson plan', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }

  /// Get lesson plans for a hub
  Future<List<LessonPlan>> getLessonPlans({
    required String hubId,
    String? subject,
    LessonStatus? status,
  }) async {
    try {
      var query = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'lessonPlans'))
          .orderBy('scheduledDate', descending: false);

      if (subject != null) {
        query = query.where('subject', isEqualTo: subject);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map<LessonPlan>((doc) => LessonPlan.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting lesson plans', error: e, tag: 'HomeschoolingService');
      return [];
    }
  }

  /// Update assignment
  Future<void> updateAssignment({
    required String hubId,
    required String assignmentId,
    String? title,
    String? description,
    String? subject,
    String? studentId,
    DateTime? dueDate,
    AssignmentStatus? status,
    String? completedBy,
    double? grade,
    String? feedback,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (subject != null) updates['subject'] = subject;
      if (studentId != null) updates['studentId'] = studentId;
      if (dueDate != null) updates['dueDate'] = dueDate.toIso8601String();
      if (status != null) {
        updates['status'] = status.name;
        if (status == AssignmentStatus.completed || status == AssignmentStatus.graded) {
          updates['completedAt'] = DateTime.now().toIso8601String();
          if (completedBy != null) {
            updates['completedBy'] = completedBy;
          }
        }
      }
      if (grade != null) updates['grade'] = grade;
      if (feedback != null) updates['feedback'] = feedback;

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'assignments'))
          .doc(assignmentId)
          .update(updates);

      Logger.info('Assignment updated: $assignmentId', tag: 'HomeschoolingService');
    } catch (e) {
      Logger.error('Error updating assignment', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }

  /// Update assignment status
  Future<void> updateAssignmentStatus({
    required String hubId,
    required String assignmentId,
    required AssignmentStatus status,
    String? completedBy,
    double? grade,
    String? feedback,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.name,
      };

      if (status == AssignmentStatus.completed || status == AssignmentStatus.graded) {
        updates['completedAt'] = DateTime.now().toIso8601String();
        if (completedBy != null) {
          updates['completedBy'] = completedBy;
        }
      }

      if (grade != null) {
        updates['grade'] = grade;
      }

      if (feedback != null) {
        updates['feedback'] = feedback;
      }

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'assignments'))
          .doc(assignmentId)
          .update(updates);

      Logger.info('Assignment status updated: $assignmentId', tag: 'HomeschoolingService');
    } catch (e) {
      Logger.error('Error updating assignment status', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }

  /// Update lesson plan
  Future<void> updateLessonPlan({
    required String hubId,
    required String lessonPlanId,
    String? subject,
    String? title,
    String? description,
    List<String>? learningObjectives,
    List<String>? resources,
    DateTime? scheduledDate,
    int? estimatedDurationMinutes,
    LessonStatus? status,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final updates = <String, dynamic>{};

      if (subject != null) updates['subject'] = subject;
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (learningObjectives != null) updates['learningObjectives'] = learningObjectives;
      if (resources != null) updates['resources'] = resources;
      if (scheduledDate != null) updates['scheduledDate'] = scheduledDate.toIso8601String();
      if (estimatedDurationMinutes != null) updates['estimatedDurationMinutes'] = estimatedDurationMinutes;
      if (status != null) {
        updates['status'] = status.name;
        if (status == LessonStatus.completed) {
          updates['completedAt'] = DateTime.now().toIso8601String();
        }
      }

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'lessonPlans'))
          .doc(lessonPlanId)
          .update(updates);

      Logger.info('Lesson plan updated: $lessonPlanId', tag: 'HomeschoolingService');
    } catch (e) {
      Logger.error('Error updating lesson plan', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }
}

