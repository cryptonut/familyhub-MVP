import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/logger_service.dart';
import '../models/task.dart';
import '../models/family_photo.dart';
import '../models/calendar_event.dart';
import '../models/user_model.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'task_service.dart';
import 'photo_service.dart';
import 'calendar_service.dart';

/// Achievement types
enum AchievementType {
  taskCompletion,
  taskCreation,
  photoSharing,
  eventPlanning,
  messaging,
  familyEngagement,
  streak,
  milestone,
}

/// Individual achievement
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final AchievementType type;
  final int points;
  final Map<String, dynamic> criteria;
  final bool isSecret;
  final DateTime? unlockedAt;
  final int progress;
  final int target;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
    required this.points,
    required this.criteria,
    this.isSecret = false,
    this.unlockedAt,
    this.progress = 0,
    this.target = 1,
  });

  bool get isUnlocked => unlockedAt != null;
  bool get isCompleted => progress >= target;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'icon': icon,
    'type': type.toString(),
    'points': points,
    'criteria': criteria,
    'isSecret': isSecret,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'progress': progress,
    'target': target,
  };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    icon: json['icon'] as String,
    type: AchievementType.values.firstWhere(
      (e) => e.toString() == json['type'] as String
    ),
    points: json['points'] as int,
    criteria: json['criteria'] as Map<String, dynamic>,
    isSecret: (json['isSecret'] as bool?) ?? false,
    unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt'] as String) : null,
    progress: (json['progress'] as int?) ?? 0,
    target: (json['target'] as int?) ?? 1,
  );
}

/// User achievement progress
class UserAchievements {
  final String userId;
  final String userName;
  final List<Achievement> achievements;
  final int totalPoints;
  final int unlockedCount;
  final Map<AchievementType, int> pointsByType;

  UserAchievements({
    required this.userId,
    required this.userName,
    required this.achievements,
    required this.totalPoints,
    required this.unlockedCount,
    required this.pointsByType,
  });
}

/// Service for managing achievements and gamification
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  final PhotoService _photoService = PhotoService();
  final CalendarService _calendarService = CalendarService();

  /// Predefined achievements
  final List<Achievement> _allAchievements = [
    // Task achievements
    Achievement(
      id: 'first_task',
      title: 'Getting Started',
      description: 'Complete your first task',
      icon: '🎯',
      type: AchievementType.taskCompletion,
      points: 10,
      criteria: {'completedTasks': 1},
    ),
    Achievement(
      id: 'task_master',
      title: 'Task Master',
      description: 'Complete 10 tasks',
      icon: '👑',
      type: AchievementType.taskCompletion,
      points: 50,
      criteria: {'completedTasks': 10},
    ),
    Achievement(
      id: 'task_creator',
      title: 'Job Creator',
      description: 'Create 5 tasks for family members',
      icon: '💼',
      type: AchievementType.taskCreation,
      points: 25,
      criteria: {'createdTasks': 5},
    ),

    // Photo achievements
    Achievement(
      id: 'first_photo',
      title: 'Family Photographer',
      description: 'Share your first family photo',
      icon: '📸',
      type: AchievementType.photoSharing,
      points: 15,
      criteria: {'uploadedPhotos': 1},
    ),
    Achievement(
      id: 'photo_album',
      title: 'Photo Album',
      description: 'Upload 10 photos to the family album',
      icon: '🖼️',
      type: AchievementType.photoSharing,
      points: 40,
      criteria: {'uploadedPhotos': 10},
    ),

    // Event achievements
    Achievement(
      id: 'event_planner',
      title: 'Event Planner',
      description: 'Create your first family event',
      icon: '📅',
      type: AchievementType.eventPlanning,
      points: 20,
      criteria: {'createdEvents': 1},
    ),
    Achievement(
      id: 'social_planner',
      title: 'Social Planner',
      description: 'Plan 5 family events',
      icon: '🎉',
      type: AchievementType.eventPlanning,
      points: 35,
      criteria: {'createdEvents': 5},
    ),

    // Communication achievements
    Achievement(
      id: 'first_message',
      title: 'Family Chat',
      description: 'Send your first family message',
      icon: '💬',
      type: AchievementType.messaging,
      points: 5,
      criteria: {'sentMessages': 1},
    ),
    Achievement(
      id: 'conversation_starter',
      title: 'Conversation Starter',
      description: 'Send 25 messages to keep the family connected',
      icon: '🗣️',
      type: AchievementType.messaging,
      points: 30,
      criteria: {'sentMessages': 25},
    ),

    // Streak achievements
    Achievement(
      id: 'week_warrior',
      title: 'Week Warrior',
      description: 'Complete tasks for 7 consecutive days',
      icon: '🔥',
      type: AchievementType.streak,
      points: 75,
      criteria: {'consecutiveDays': 7},
    ),

    // Milestone achievements
    Achievement(
      id: 'family_hero',
      title: 'Family Hero',
      description: 'Earn 500 achievement points',
      icon: '⭐',
      type: AchievementType.milestone,
      points: 100,
      criteria: {'totalPoints': 500},
    ),

    // Secret achievements
    Achievement(
      id: 'midnight_worker',
      title: 'Midnight Worker',
      description: 'Complete a task after midnight',
      icon: '🌙',
      type: AchievementType.taskCompletion,
      points: 25,
      criteria: {'completedAfterMidnight': true},
      isSecret: true,
    ),
  ];

  /// Get all available achievements
  List<Achievement> getAllAchievements() => _allAchievements;

  /// Get user achievements with progress
  Future<UserAchievements> getUserAchievements(String userId) async {
    try {
      // Get user model from Firestore directly
      final userDoc = await _firestore.collection(FirestorePathUtils.getUsersCollection()).doc(userId).get();
      if (!userDoc.exists) throw Exception('User not found');
      
      final userModel = UserModel.fromJson({
        'uid': userDoc.id,
        ...userDoc.data()!,
      });

      // Get achievement progress from Firestore
      final progressDoc = await _firestore
          .collection(FirestorePathUtils.getUsersCollection())
          .doc(userId)
          .collection('achievements')
          .doc('progress')
          .get();

      final progressData = progressDoc.data() ?? <String, dynamic>{};
      final unlockedIds = List<String>.from((progressData['unlockedAchievements'] as List<dynamic>?) ?? []);

      // Build achievements with progress
      final achievements = <Achievement>[];
      var totalPoints = 0;
      var unlockedCount = 0;
      final pointsByType = <AchievementType, int>{};

      for (final achievement in _allAchievements) {
        final isUnlocked = unlockedIds.contains(achievement.id);
        final progress = progressData['progress_${achievement.id}'] ?? 0;

        final updatedAchievement = Achievement(
          id: achievement.id,
          title: achievement.title,
          description: achievement.description,
          icon: achievement.icon,
          type: achievement.type,
          points: achievement.points,
          criteria: achievement.criteria,
          isSecret: achievement.isSecret,
          unlockedAt: isUnlocked ? DateTime.now() : null, // Simplified
          progress: (progress as int?) ?? 0,
          target: achievement.target,
        );

        achievements.add(updatedAchievement);

        if (isUnlocked) {
          totalPoints += achievement.points;
          unlockedCount++;
          pointsByType[achievement.type] = (pointsByType[achievement.type] ?? 0) + achievement.points;
        }
      }

      return UserAchievements(
        userId: userId,
        userName: userModel.displayName,
        achievements: achievements,
        totalPoints: totalPoints,
        unlockedCount: unlockedCount,
        pointsByType: pointsByType,
      );
    } catch (e, st) {
      Logger.error('Error getting user achievements', error: e, stackTrace: st, tag: 'AchievementService');
      rethrow;
    }
  }

  /// Check for newly unlocked achievements
  Future<List<Achievement>> checkAchievements(String userId) async {
    try {
      final userAchievements = await getUserAchievements(userId);
      final currentProgress = await _getCurrentUserStats(userId);

      final newlyUnlocked = <Achievement>[];

      for (final achievement in userAchievements.achievements) {
        if (achievement.isUnlocked) continue;

        if (_meetsCriteria(achievement, currentProgress)) {
          newlyUnlocked.add(achievement);
          await _unlockAchievement(userId, achievement);
          Logger.info('Achievement unlocked: ${achievement.title} for user $userId', tag: 'AchievementService');
        }
      }

      return newlyUnlocked;
    } catch (e, st) {
      Logger.error('Error checking achievements', error: e, stackTrace: st, tag: 'AchievementService');
      return [];
    }
  }

  /// Update user progress for achievements
  Future<void> updateProgress(String userId, AchievementType type, String metric, int value) async {
    try {
      await _firestore
          .collection(FirestorePathUtils.getUsersCollection())
          .doc(userId)
          .collection('achievements')
          .doc('progress')
          .set({
            'progress_${type}_${metric}': value,
            'lastUpdated': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));

      // Check if this unlocks any achievements
      await checkAchievements(userId);
    } catch (e, st) {
      Logger.error('Error updating achievement progress', error: e, stackTrace: st, tag: 'AchievementService');
    }
  }

  /// Get current user statistics for achievement checking
  Future<Map<String, dynamic>> _getCurrentUserStats(String userId) async {
    try {
      // Get user model from Firestore directly
      final userDoc = await _firestore.collection(FirestorePathUtils.getUsersCollection()).doc(userId).get();
      if (!userDoc.exists) return {};
      
      final userModel = UserModel.fromJson({
        'uid': userDoc.id,
        ...userDoc.data()!,
      });
      
      if (userModel.familyId == null || userModel.familyId!.isEmpty) return {};

      final familyId = userModel!.familyId!;

      // Get user stats from various services
      final tasks = await _taskService.getTasks(limit: 1000);
      final photos = await _photoService.getPhotos(familyId, limit: 1000);
      final events = await _calendarService.getEvents(limit: 1000);

      final userTasks = tasks.where((task) => task.createdBy == userId || task.assignedTo == userId);
      final userPhotos = photos.where((photo) => photo.uploadedBy == userId);
      final userEvents = events.where((event) => event.createdBy == userId);

      final completedTasks = userTasks.where((task) => task.isCompleted);

      return {
        'completedTasks': completedTasks.length,
        'createdTasks': userTasks.where((task) => task.createdBy == userId).length,
        'uploadedPhotos': userPhotos.length,
        'createdEvents': userEvents.length,
        'sentMessages': 0, // Would need message service integration
        'consecutiveDays': 0, // Would need streak tracking
        'totalPoints': 0, // Would be calculated from unlocked achievements
        'completedAfterMidnight': completedTasks.any((task) =>
          task.completedAt != null && task.completedAt!.hour >= 0 && task.completedAt!.hour < 6
        ),
      };
    } catch (e) {
      Logger.warning('Error getting user stats', error: e, tag: 'AchievementService');
      return {};
    }
  }

  /// Check if user meets achievement criteria
  bool _meetsCriteria(Achievement achievement, Map<String, dynamic> userStats) {
    for (final entry in achievement.criteria.entries) {
      final key = entry.key;
      final requiredValue = entry.value;

      final actualValue = userStats[key] ?? 0;

      if (actualValue is int && requiredValue is int) {
        if (actualValue < requiredValue) return false;
      } else if (actualValue is bool && requiredValue is bool) {
        if (actualValue != requiredValue) return false;
      } else {
        // Type mismatch or unsupported type
        return false;
      }
    }

    return true;
  }

  /// Unlock an achievement for a user
  Future<void> _unlockAchievement(String userId, Achievement achievement) async {
    try {
      final batch = _firestore.batch();

      // Update progress document
      final progressRef = _firestore
          .collection(FirestorePathUtils.getUsersCollection())
          .doc(userId)
          .collection('achievements')
          .doc('progress');

      batch.set(progressRef, {
        'unlockedAchievements': FieldValue.arrayUnion([achievement.id]),
        'unlockedAt_${achievement.id}': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      // Add to unlocked achievements collection
      final unlockedRef = _firestore
          .collection(FirestorePathUtils.getUsersCollection())
          .doc(userId)
          .collection('achievements')
          .doc(achievement.id);

      batch.set(unlockedRef, {
        'achievementId': achievement.id,
        'unlockedAt': DateTime.now().toIso8601String(),
        'points': achievement.points,
      });

      await batch.commit();

      Logger.info('Achievement "${achievement.title}" unlocked for user $userId', tag: 'AchievementService');
    } catch (e, st) {
      Logger.error('Error unlocking achievement', error: e, stackTrace: st, tag: 'AchievementService');
    }
  }

  /// Get family leaderboard
  Future<List<UserAchievements>> getFamilyLeaderboard(String familyId) async {
    try {
      // This would query all family members and their achievements
      // Simplified implementation
      final familyMembers = await _authService.getFamilyMembers();
      final leaderboard = <UserAchievements>[];

      for (final member in familyMembers) {
        final achievements = await getUserAchievements(member.uid);
        leaderboard.add(achievements);
      }

      // Sort by total points
      leaderboard.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

      return leaderboard;
    } catch (e, st) {
      Logger.error('Error getting family leaderboard', error: e, stackTrace: st, tag: 'AchievementService');
      return [];
    }
  }

  /// Get achievement recommendations for user
  Future<List<Achievement>> getRecommendedAchievements(String userId) async {
    try {
      final userAchievements = await getUserAchievements(userId);
      final userStats = await _getCurrentUserStats(userId);

      // Find achievements that are close to being unlocked
      final recommended = <Achievement>[];

      for (final achievement in userAchievements.achievements) {
        if (achievement.isUnlocked) continue;

        // Check if user is within 20% of target
        final progress = achievement.progress;
        final target = achievement.target;
        final progressRatio = progress / target;

        if (progressRatio >= 0.8) {
          recommended.add(achievement);
        }
      }

      // Sort by how close they are to completion
      recommended.sort((a, b) {
        final aRatio = a.progress / a.target;
        final bRatio = b.progress / b.target;
        return bRatio.compareTo(aRatio); // Higher progress first
      });

      return recommended.take(3).toList(); // Return top 3
    } catch (e, st) {
      Logger.warning('Error getting recommended achievements', error: e, tag: 'AchievementService');
      return [];
    }
  }
}
