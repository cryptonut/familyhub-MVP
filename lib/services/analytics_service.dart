import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/logger_service.dart';
import '../models/task.dart';
import '../models/calendar_event.dart';
import '../models/family_photo.dart';
import 'auth_service.dart';
import 'task_service.dart';
import 'calendar_service.dart';
import 'photo_service.dart';
import 'family_wallet_service.dart';

/// Family analytics data
class FamilyAnalytics {
  final String familyId;
  final DateTime periodStart;
  final DateTime periodEnd;

  // Task analytics
  final int totalTasks;
  final int completedTasks;
  final int activeTasks;
  final double taskCompletionRate;
  final Map<String, int> tasksByMember;
  final Map<String, double> averageCompletionTime;

  // Message analytics
  final int totalMessages;
  final Map<String, int> messagesByMember;
  final Map<String, int> messageActivityByHour;

  // Calendar analytics
  final int totalEvents;
  final int upcomingEvents;
  final Map<String, int> eventsByType;
  final double eventAttendanceRate;

  // Photo analytics
  final int totalPhotos;
  final Map<String, int> photosByMember;
  final Map<String, int> photoUploadsByDay;

  // Game analytics
  final int totalGamesPlayed;
  final Map<String, int> gamesWonByMember;
  final Map<String, double> averageGameDuration;

  // Wallet analytics
  final double totalEarned;
  final double totalSpent;
  final Map<String, double> earningsByMember;
  final List<WalletTransaction> recentTransactions;

  // Activity trends
  final Map<String, int> dailyActivity;
  final Map<String, int> weeklyActivity;

  FamilyAnalytics({
    required this.familyId,
    required this.periodStart,
    required this.periodEnd,
    required this.totalTasks,
    required this.completedTasks,
    required this.activeTasks,
    required this.taskCompletionRate,
    required this.tasksByMember,
    required this.averageCompletionTime,
    required this.totalMessages,
    required this.messagesByMember,
    required this.messageActivityByHour,
    required this.totalEvents,
    required this.upcomingEvents,
    required this.eventsByType,
    required this.eventAttendanceRate,
    required this.totalPhotos,
    required this.photosByMember,
    required this.photoUploadsByDay,
    required this.totalGamesPlayed,
    required this.gamesWonByMember,
    required this.averageGameDuration,
    required this.totalEarned,
    required this.totalSpent,
    required this.earningsByMember,
    required this.recentTransactions,
    required this.dailyActivity,
    required this.weeklyActivity,
  });
}

/// Wallet transaction for analytics
class WalletTransaction {
  final String id;
  final String type;
  final double amount;
  final String description;
  final DateTime timestamp;
  final String userId;
  final String userName;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    required this.userId,
    required this.userName,
  });
}

/// Service for comprehensive family analytics and insights
class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  final CalendarService _calendarService = CalendarService();
  final PhotoService _photoService = PhotoService();
  final FamilyWalletService _familyWalletService = FamilyWalletService();

  /// Get comprehensive family analytics for the last 30 days
  Future<FamilyAnalytics> getFamilyAnalytics({
    String? familyId,
    int days = 30,
  }) async {
    try {
      final fid = familyId ?? await _getCurrentFamilyId();
      if (fid == null) throw Exception('No family ID available');

      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      Logger.info('Generating analytics for family $fid (${days} days)', tag: 'AnalyticsService');

      // Gather all analytics data in parallel
      final results = await Future.wait([
        _getTaskAnalytics(fid, startDate, endDate),
        _getMessageAnalytics(fid, startDate, endDate),
        _getCalendarAnalytics(fid, startDate, endDate),
        _getPhotoAnalytics(fid, startDate, endDate),
        _getGameAnalytics(fid, startDate, endDate),
        _getWalletAnalytics(fid, startDate, endDate),
        _getActivityTrends(fid, startDate, endDate),
      ]);

      final taskData = results[0] as Map<String, dynamic>;
      final messageData = results[1] as Map<String, dynamic>;
      final calendarData = results[2] as Map<String, dynamic>;
      final photoData = results[3] as Map<String, dynamic>;
      final gameData = results[4] as Map<String, dynamic>;
      final walletData = results[5] as Map<String, dynamic>;
      final activityData = results[6] as Map<String, dynamic>;

      return FamilyAnalytics(
        familyId: fid,
        periodStart: startDate,
        periodEnd: endDate,
        // Task analytics
        totalTasks: taskData['totalTasks'],
        completedTasks: taskData['completedTasks'],
        activeTasks: taskData['activeTasks'],
        taskCompletionRate: taskData['completionRate'],
        tasksByMember: taskData['tasksByMember'],
        averageCompletionTime: taskData['averageCompletionTime'],
        // Message analytics
        totalMessages: messageData['totalMessages'],
        messagesByMember: messageData['messagesByMember'],
        messageActivityByHour: messageData['activityByHour'],
        // Calendar analytics
        totalEvents: calendarData['totalEvents'],
        upcomingEvents: calendarData['upcomingEvents'],
        eventsByType: calendarData['eventsByType'],
        eventAttendanceRate: calendarData['attendanceRate'],
        // Photo analytics
        totalPhotos: photoData['totalPhotos'],
        photosByMember: photoData['photosByMember'],
        photoUploadsByDay: photoData['uploadsByDay'],
        // Game analytics
        totalGamesPlayed: gameData['totalGames'],
        gamesWonByMember: gameData['winsByMember'],
        averageGameDuration: gameData['averageDuration'],
        // Wallet analytics
        totalEarned: walletData['totalEarned'],
        totalSpent: walletData['totalSpent'],
        earningsByMember: walletData['earningsByMember'],
        recentTransactions: walletData['recentTransactions'],
        // Activity trends
        dailyActivity: activityData['dailyActivity'],
        weeklyActivity: activityData['weeklyActivity'],
      );
    } catch (e, st) {
      Logger.error('Error generating family analytics', error: e, stackTrace: st, tag: 'AnalyticsService');
      rethrow;
    }
  }

  /// Get current family ID
  Future<String?> _getCurrentFamilyId() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      return userModel?.familyId;
    } catch (e) {
      Logger.warning('Error getting current family ID', error: e, tag: 'AnalyticsService');
      return null;
    }
  }

  /// Get task analytics
  Future<Map<String, dynamic>> _getTaskAnalytics(String familyId, DateTime startDate, DateTime endDate) async {
    try {
      // Get family members to map IDs to names
      final familyMembers = await _authService.getFamilyMembers();
      final memberNameMap = <String, String>{};
      for (final member in familyMembers) {
        memberNameMap[member.uid] = member.displayName ?? member.email ?? 'Unknown';
      }

      // Get all tasks (this could be optimized with better queries)
      final allTasks = await _taskService.getTasks(limit: 1000);
      final periodTasks = allTasks.where((task) =>
        task.createdAt.isAfter(startDate) && task.createdAt.isBefore(endDate)
      ).toList();

      final completedTasks = periodTasks.where((task) => task.isCompleted).toList();
      final activeTasks = periodTasks.where((task) => !task.isCompleted).toList();

      // Calculate completion rate
      final completionRate = periodTasks.isNotEmpty
          ? completedTasks.length / periodTasks.length
          : 0.0;

      // Tasks by member
      final tasksByMember = <String, int>{};
      for (final task in periodTasks) {
        final memberName = task.assignedTo.isNotEmpty
            ? (memberNameMap[task.assignedTo] ?? 'Unassigned')
            : 'Unassigned';
        tasksByMember[memberName] = (tasksByMember[memberName] ?? 0) + 1;
      }

      // Average completion time (simplified calculation)
      final averageCompletionTime = <String, double>{};
      for (final task in completedTasks) {
        if (task.completedAt != null) {
          final duration = task.completedAt!.difference(task.createdAt).inHours.toDouble();
          final memberName = task.assignedTo.isNotEmpty
              ? (memberNameMap[task.assignedTo] ?? 'Unassigned')
              : 'Unassigned';
          if (!averageCompletionTime.containsKey(memberName)) {
            averageCompletionTime[memberName] = duration;
          } else {
            averageCompletionTime[memberName] =
                (averageCompletionTime[memberName]! + duration) / 2;
          }
        }
      }

      return {
        'totalTasks': periodTasks.length,
        'completedTasks': completedTasks.length,
        'activeTasks': activeTasks.length,
        'completionRate': completionRate,
        'tasksByMember': tasksByMember,
        'averageCompletionTime': averageCompletionTime,
      };
    } catch (e) {
      Logger.warning('Error getting task analytics', error: e, tag: 'AnalyticsService');
      return {
        'totalTasks': 0,
        'completedTasks': 0,
        'activeTasks': 0,
        'completionRate': 0.0,
        'tasksByMember': <String, int>{},
        'averageCompletionTime': <String, double>{},
      };
    }
  }

  /// Get message analytics
  Future<Map<String, dynamic>> _getMessageAnalytics(String familyId, DateTime startDate, DateTime endDate) async {
    try {
      // This is a simplified implementation - in reality, we'd query message counts
      // For now, return placeholder data
      return {
        'totalMessages': 0, // Would need to implement message counting
        'messagesByMember': <String, int>{},
        'activityByHour': <String, int>{},
      };
    } catch (e) {
      Logger.warning('Error getting message analytics', error: e, tag: 'AnalyticsService');
      return {
        'totalMessages': 0,
        'messagesByMember': <String, int>{},
        'activityByHour': <String, int>{},
      };
    }
  }

  /// Get calendar analytics
  Future<Map<String, dynamic>> _getCalendarAnalytics(String familyId, DateTime startDate, DateTime endDate) async {
    try {
      final events = await _calendarService.getEvents(limit: 500);
      final periodEvents = events.where((event) =>
        event.startTime.isAfter(startDate) && event.startTime.isBefore(endDate)
      ).toList();

      final upcomingEvents = events.where((event) =>
        event.startTime.isAfter(DateTime.now())
      ).length;

      // Events by type (simplified - would categorize by event properties)
      final eventsByType = <String, int>{
        'meetings': periodEvents.length, // Placeholder categorization
      };

      return {
        'totalEvents': periodEvents.length,
        'upcomingEvents': upcomingEvents,
        'eventsByType': eventsByType,
        'attendanceRate': 0.0, // Would need attendance tracking
      };
    } catch (e) {
      Logger.warning('Error getting calendar analytics', error: e, tag: 'AnalyticsService');
      return {
        'totalEvents': 0,
        'upcomingEvents': 0,
        'eventsByType': <String, int>{},
        'attendanceRate': 0.0,
      };
    }
  }

  /// Get photo analytics
  Future<Map<String, dynamic>> _getPhotoAnalytics(String familyId, DateTime startDate, DateTime endDate) async {
    try {
      final photos = await _photoService.getPhotos(familyId, limit: 500);
      final periodPhotos = photos.where((photo) =>
        photo.uploadedAt.isAfter(startDate) && photo.uploadedAt.isBefore(endDate)
      ).toList();

      // Photos by member
      final photosByMember = <String, int>{};
      for (final photo in periodPhotos) {
        final memberName = photo.uploadedByName;
        photosByMember[memberName] = (photosByMember[memberName] ?? 0) + 1;
      }

      // Uploads by day (simplified)
      final uploadsByDay = <String, int>{};
      for (final photo in periodPhotos) {
        final dayKey = photo.uploadedAt.toIso8601String().split('T')[0];
        uploadsByDay[dayKey] = (uploadsByDay[dayKey] ?? 0) + 1;
      }

      return {
        'totalPhotos': periodPhotos.length,
        'photosByMember': photosByMember,
        'uploadsByDay': uploadsByDay,
      };
    } catch (e) {
      Logger.warning('Error getting photo analytics', error: e, tag: 'AnalyticsService');
      return {
        'totalPhotos': 0,
        'photosByMember': <String, int>{},
        'uploadsByDay': <String, int>{},
      };
    }
  }

  /// Get game analytics (placeholder - would integrate with actual game services)
  Future<Map<String, dynamic>> _getGameAnalytics(String familyId, DateTime startDate, DateTime endDate) async {
    // Placeholder implementation
    return {
      'totalGames': 0,
      'winsByMember': <String, int>{},
      'averageDuration': <String, double>{},
    };
  }

  /// Get wallet analytics
  Future<Map<String, dynamic>> _getWalletAnalytics(String familyId, DateTime startDate, DateTime endDate) async {
    try {
      // This would integrate with actual wallet transaction history
      // For now, return placeholder data
      return {
        'totalEarned': 0.0,
        'totalSpent': 0.0,
        'earningsByMember': <String, double>{},
        'recentTransactions': <WalletTransaction>[],
      };
    } catch (e) {
      Logger.warning('Error getting wallet analytics', error: e, tag: 'AnalyticsService');
      return {
        'totalEarned': 0.0,
        'totalSpent': 0.0,
        'earningsByMember': <String, double>{},
        'recentTransactions': <WalletTransaction>[],
      };
    }
  }

  /// Get activity trends
  Future<Map<String, dynamic>> _getActivityTrends(String familyId, DateTime startDate, DateTime endDate) async {
    try {
      // Aggregate activity across different content types
      final dailyActivity = <String, int>{};
      final weeklyActivity = <String, int>{};

      // This would aggregate activity from tasks, messages, events, photos
      // For now, return placeholder data

      return {
        'dailyActivity': dailyActivity,
        'weeklyActivity': weeklyActivity,
      };
    } catch (e) {
      Logger.warning('Error getting activity trends', error: e, tag: 'AnalyticsService');
      return {
        'dailyActivity': <String, int>{},
        'weeklyActivity': <String, int>{},
      };
    }
  }

  /// Get quick insights (lighter weight analytics)
  Future<Map<String, dynamic>> getQuickInsights(String familyId) async {
    try {
      final analytics = await getFamilyAnalytics(familyId: familyId, days: 7);

      return {
        'activeTasks': analytics.activeTasks,
        'completedThisWeek': analytics.completedTasks,
        'upcomingEvents': analytics.upcomingEvents,
        'photosThisWeek': analytics.totalPhotos,
        'completionRate': analytics.taskCompletionRate,
        'mostActiveMember': _findMostActiveMember(analytics),
      };
    } catch (e) {
      Logger.warning('Error getting quick insights', error: e, tag: 'AnalyticsService');
      return {};
    }
  }

  /// Find the most active member across different metrics
  String _findMostActiveMember(FamilyAnalytics analytics) {
    final memberScores = <String, int>{};

    // Score based on tasks completed
    analytics.tasksByMember.forEach((member, count) {
      memberScores[member] = (memberScores[member] ?? 0) + count;
    });

    // Score based on messages sent
    analytics.messagesByMember.forEach((member, count) {
      memberScores[member] = (memberScores[member] ?? 0) + (count ~/ 10); // Weight messages less
    });

    // Score based on photos uploaded
    analytics.photosByMember.forEach((member, count) {
      memberScores[member] = (memberScores[member] ?? 0) + count;
    });

    if (memberScores.isEmpty) return 'No activity yet';

    return memberScores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
