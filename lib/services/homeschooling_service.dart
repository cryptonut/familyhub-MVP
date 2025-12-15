import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/student_profile.dart';
import '../models/assignment.dart';
import '../models/lesson_plan.dart';
import '../models/educational_resource.dart';
import '../models/progress_report.dart';
import '../models/learning_milestone.dart';
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
      
      // Check for automatic milestones when assignment is completed
      if (status == AssignmentStatus.completed || status == AssignmentStatus.graded) {
        final assignment = await getAssignments(hubId: hubId).then(
          (assignments) => assignments.firstWhere((a) => a.id == assignmentId),
        );
        if (assignment.studentId != null) {
          // Trigger milestone check in background (don't await)
          checkAndCreateAutomaticMilestones(
            hubId: hubId,
            studentId: assignment.studentId,
          ).catchError((e) {
            Logger.warning(
              'Error checking milestones after assignment completion',
              error: e,
              tag: 'HomeschoolingService',
            );
          });
        }
      }
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
      
      // Check for automatic milestones when lesson is completed
      if (status == LessonStatus.completed) {
        // Get all students in the hub to check milestones
        final students = await getStudentProfiles(hubId);
        for (var student in students) {
          // Trigger milestone check in background (don't await)
          checkAndCreateAutomaticMilestones(
            hubId: hubId,
            studentId: student.id,
          ).catchError((e) {
            Logger.warning(
              'Error checking milestones after lesson completion',
              error: e,
              tag: 'HomeschoolingService',
            );
          });
        }
      }
    } catch (e) {
      Logger.error('Error updating lesson plan', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }

  // ========== Educational Resources ==========

  /// Create educational resource
  Future<EducationalResource> createEducationalResource({
    required String hubId,
    required String title,
    String? description,
    required ResourceType type,
    String? url,
    String? fileUrl,
    String? thumbnailUrl,
    List<String>? subjects,
    String? gradeLevel,
    List<String>? tags,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final resource = EducationalResource(
        id: _uuid.v4(),
        hubId: hubId,
        title: title,
        description: description,
        type: type,
        url: url,
        fileUrl: fileUrl,
        thumbnailUrl: thumbnailUrl,
        subjects: subjects ?? [],
        gradeLevel: gradeLevel,
        tags: tags ?? [],
        createdAt: DateTime.now(),
        createdBy: currentUserId,
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'educational_resources'))
          .doc(resource.id)
          .set(resource.toJson());

      Logger.info('Educational resource created: ${resource.id}', tag: 'HomeschoolingService');
      return resource;
    } catch (e) {
      Logger.error('Error creating educational resource', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }

  /// Get educational resources for a hub
  Future<List<EducationalResource>> getEducationalResources({
    required String hubId,
    String? subject,
    String? gradeLevel,
    ResourceType? type,
  }) async {
    try {
      var query = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'educational_resources'))
          .orderBy('createdAt', descending: true);

      if (subject != null) {
        query = query.where('subjects', arrayContains: subject);
      }

      if (gradeLevel != null) {
        query = query.where('gradeLevel', isEqualTo: gradeLevel);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => EducationalResource.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting educational resources', error: e, tag: 'HomeschoolingService');
      return [];
    }
  }

  // ========== Progress Reports ==========

  /// Generate progress report for a student
  Future<ProgressReport> generateProgressReport({
    required String hubId,
    required String studentId,
    required String reportPeriod,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      // Get all assignments for the student in the period
      final assignments = await getAssignments(
        hubId: hubId,
        studentId: studentId,
      );

      final periodAssignments = assignments.where((a) {
        return a.createdAt.isAfter(startDate) && a.createdAt.isBefore(endDate);
      }).toList();

      // Get all lesson plans for the hub in the period
      final lessonPlans = await getLessonPlans(hubId: hubId);
      final periodLessons = lessonPlans.where((l) {
        return l.scheduledDate != null &&
            l.scheduledDate!.isAfter(startDate) &&
            l.scheduledDate!.isBefore(endDate);
      }).toList();

      // Calculate subject progress
      final subjectProgress = <String, SubjectProgress>{};
      final subjectGrades = <String, List<double>>{};
      final subjectAssignments = <String, List<Assignment>>{};
      final subjectLessons = <String, List<LessonPlan>>{};

      // Group by subject
      for (var assignment in periodAssignments) {
        if (!subjectAssignments.containsKey(assignment.subject)) {
          subjectAssignments[assignment.subject] = [];
        }
        subjectAssignments[assignment.subject]!.add(assignment);

        if (assignment.grade != null) {
          if (!subjectGrades.containsKey(assignment.subject)) {
            subjectGrades[assignment.subject] = [];
          }
          subjectGrades[assignment.subject]!.add(assignment.grade!);
        }
      }

      for (var lesson in periodLessons) {
        if (!subjectLessons.containsKey(lesson.subject)) {
          subjectLessons[lesson.subject] = [];
        }
        subjectLessons[lesson.subject]!.add(lesson);
      }

      // Calculate averages and progress
      for (var subject in subjectAssignments.keys) {
        final grades = subjectGrades[subject] ?? [];
        final avgGrade = grades.isEmpty
            ? 0.0
            : grades.reduce((a, b) => a + b) / grades.length;

        final completed = subjectAssignments[subject]!
            .where((a) => a.status == AssignmentStatus.completed ||
                a.status == AssignmentStatus.graded)
            .length;

        final lessons = subjectLessons[subject] ?? [];
        final completedLessons = lessons
            .where((l) => l.status == LessonStatus.completed)
            .length;

        subjectProgress[subject] = SubjectProgress(
          subject: subject,
          averageGrade: avgGrade,
          assignmentsCompleted: completed,
          assignmentsTotal: subjectAssignments[subject]!.length,
          lessonsCompleted: completedLessons,
        );
      }

      // Calculate overall average
      final allGrades = subjectGrades.values.expand((g) => g).toList();
      final overallAverage = allGrades.isEmpty
          ? 0.0
          : allGrades.reduce((a, b) => a + b) / allGrades.length;

      // Generate strengths and areas for improvement
      final strengths = <String>[];
      final areasForImprovement = <String>[];

      for (var entry in subjectProgress.entries) {
        if (entry.value.averageGrade >= 85) {
          strengths.add('${entry.key}: Strong performance');
        } else if (entry.value.averageGrade < 70) {
          areasForImprovement.add('${entry.key}: Needs improvement');
        }
      }

      final report = ProgressReport(
        id: _uuid.v4(),
        hubId: hubId,
        studentId: studentId,
        reportPeriod: reportPeriod,
        startDate: startDate,
        endDate: endDate,
        subjectProgress: subjectProgress,
        overallAverage: overallAverage,
        strengths: strengths,
        areasForImprovement: areasForImprovement,
        createdAt: DateTime.now(),
        createdBy: currentUserId,
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'progress_reports'))
          .doc(report.id)
          .set(report.toJson());

      Logger.info('Progress report generated: ${report.id}', tag: 'HomeschoolingService');
      return report;
    } catch (e) {
      Logger.error('Error generating progress report', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }

  /// Get progress reports for a student
  Future<List<ProgressReport>> getProgressReports({
    required String hubId,
    required String studentId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'progress_reports'))
          .where('studentId', isEqualTo: studentId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ProgressReport.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting progress reports', error: e, tag: 'HomeschoolingService');
      return [];
    }
  }

  // ========== Learning Milestones ==========

  /// Create learning milestone
  Future<LearningMilestone> createLearningMilestone({
    required String hubId,
    required String studentId,
    required String title,
    String? description,
    required MilestoneType type,
    String? subject,
    String? iconName,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final milestone = LearningMilestone(
        id: _uuid.v4(),
        hubId: hubId,
        studentId: studentId,
        title: title,
        description: description,
        type: type,
        subject: subject,
        achievedAt: DateTime.now(),
        iconName: iconName,
      );

      await _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'learning_milestones'))
          .doc(milestone.id)
          .set(milestone.toJson());

      Logger.info('Learning milestone created: ${milestone.id}', tag: 'HomeschoolingService');
      return milestone;
    } catch (e) {
      Logger.error('Error creating learning milestone', error: e, tag: 'HomeschoolingService');
      rethrow;
    }
  }

  /// Get learning milestones for a student
  Future<List<LearningMilestone>> getLearningMilestones({
    required String hubId,
    required String studentId,
    MilestoneType? type,
    String? subject,
  }) async {
    try {
      var query = _firestore
          .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'learning_milestones'))
          .where('studentId', isEqualTo: studentId)
          .orderBy('achievedAt', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      if (subject != null) {
        query = query.where('subject', isEqualTo: subject);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => LearningMilestone.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting learning milestones', error: e, tag: 'HomeschoolingService');
      return [];
    }
  }

  /// Check and create automatic milestones (e.g., streak, completion milestones)
  Future<void> checkAndCreateAutomaticMilestones({
    required String hubId,
    required String studentId,
  }) async {
    try {
      // Get assignments and lessons for the student
      final assignments = await getAssignments(hubId: hubId, studentId: studentId);
      final lessonPlans = await getLessonPlans(hubId: hubId);
      final existingMilestones = await getLearningMilestones(
        hubId: hubId,
        studentId: studentId,
      );

      // Check for completion milestones
      final completedAssignments = assignments
          .where((a) => a.status == AssignmentStatus.completed ||
              a.status == AssignmentStatus.graded)
          .length;

      // Create milestone for 10, 25, 50, 100 completed assignments
      final completionMilestones = [10, 25, 50, 100];
      for (var target in completionMilestones) {
        if (completedAssignments >= target) {
          final milestoneTitle = 'Completed $target Assignments';
          final exists = existingMilestones.any(
            (m) => m.title == milestoneTitle && m.type == MilestoneType.completion,
          );
          if (!exists) {
            await createLearningMilestone(
              hubId: hubId,
              studentId: studentId,
              title: milestoneTitle,
              description: 'Great job completing $target assignments!',
              type: MilestoneType.completion,
              iconName: 'assignment_turned_in',
            );
          }
        }
      }

      // Check for streak milestones (consecutive days with completed lessons)
      final now = DateTime.now();
      final recentLessons = lessonPlans
          .where((l) =>
              l.status == LessonStatus.completed &&
              l.completedAt != null &&
              l.completedAt!.isAfter(now.subtract(const Duration(days: 30))))
          .toList();

      // Simple streak calculation (days with at least one completed lesson)
      final lessonDates = recentLessons
          .map((l) => DateTime(
                l.completedAt!.year,
                l.completedAt!.month,
                l.completedAt!.day,
              ))
          .toSet()
          .toList()
        ..sort();

      int currentStreak = 0;
      DateTime? lastDate;
      for (var date in lessonDates.reversed) {
        if (lastDate == null) {
          if (date.isAtSameMomentAs(DateTime(now.year, now.month, now.day)) ||
              date.isAtSameMomentAs(DateTime(now.year, now.month, now.day - 1))) {
            currentStreak = 1;
            lastDate = date;
          }
        } else {
          final daysDiff = lastDate.difference(date).inDays;
          if (daysDiff == 1) {
            currentStreak++;
            lastDate = date;
          } else {
            break;
          }
        }
      }

      // Create streak milestones
      final streakMilestones = [7, 14, 30, 60];
      for (var target in streakMilestones) {
        if (currentStreak >= target) {
          final milestoneTitle = '$target Day Learning Streak';
          final exists = existingMilestones.any(
            (m) => m.title == milestoneTitle && m.type == MilestoneType.streak,
          );
          if (!exists) {
            await createLearningMilestone(
              hubId: hubId,
              studentId: studentId,
              title: milestoneTitle,
              description: 'Amazing! You\'ve maintained a $target day learning streak!',
              type: MilestoneType.streak,
              iconName: 'local_fire_department',
            );
          }
        }
      }
    } catch (e) {
      Logger.error(
        'Error checking automatic milestones',
        error: e,
        tag: 'HomeschoolingService',
      );
    }
  }
}

