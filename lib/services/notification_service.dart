import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import 'auth_service.dart';
import '../core/di/service_locator.dart';
import '../games/chess/services/chess_service.dart';
import '../games/chess/screens/chess_game_screen.dart';
import '../games/chess/models/chess_game.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  
  // Global navigator key for deep linking (set from main.dart)
  static GlobalKey<NavigatorState>? navigatorKey;

  // Initialize notifications
  Future<void> initialize() async {
    // Request permission for notifications
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      Logger.info('User granted notification permission', tag: 'NotificationService');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      Logger.info('User granted provisional notification permission', tag: 'NotificationService');
    } else {
      Logger.warning('User declined or has not accepted notification permission', tag: 'NotificationService');
    }

    // Get FCM token and save it to user document
    String? token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToUser(token);
      Logger.debug('FCM Token obtained', tag: 'NotificationService');
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToUser(newToken);
      Logger.info('FCM Token refreshed', tag: 'NotificationService');
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Logger.info('Got a message whilst in the foreground!', tag: 'NotificationService');
      Logger.debug('Message data: ${message.data}', tag: 'NotificationService');
      
      // Handle chess invite messages
      _handleChessInviteMessage(message);
      
      if (message.notification != null) {
        Logger.debug('Message also contained a notification: ${message.notification}', tag: 'NotificationService');
      }
    });

    // Handle background messages (when app is terminated)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Save FCM token to user document
  Future<void> _saveTokenToUser(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
      });
      Logger.debug('FCM token saved to user document', tag: 'NotificationService');
    } catch (e, st) {
      Logger.warning('Error saving FCM token', error: e, stackTrace: st, tag: 'NotificationService');
    }
  }

  // Send notification to job creator when claim is made
  Future<void> notifyJobClaimed(String jobId, String jobTitle, String claimerId) async {
    try {
      // Get the job to find the creator - use the same logic as TaskService
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      final userId = _auth.currentUser?.uid;
      if (familyId == null && userId == null) return;

      final newPath = familyId != null ? 'families/$familyId/tasks' : null;
      final oldPath = userId != null ? 'families/$userId/tasks' : null;
      
      DocumentSnapshot? jobDoc;
      if (newPath != null) {
        jobDoc = await _firestore.collection(newPath).doc(jobId).get();
      }
      if ((jobDoc == null || !jobDoc.exists) && oldPath != null && oldPath != newPath) {
        jobDoc = await _firestore.collection(oldPath).doc(jobId).get();
      }

      if (jobDoc == null || !jobDoc.exists) {
        Logger.warning('Job not found for notification: $jobId', tag: 'NotificationService');
        return;
      }

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      final creatorId = jobData?['createdBy'] as String?;
      if (creatorId == null) return;

      // Get creator's FCM token
      final creatorDoc = await _firestore.collection('users').doc(creatorId).get();
      if (!creatorDoc.exists) return;

      final creatorData = creatorDoc.data();
      final fcmToken = creatorData?['fcmToken'] as String?;
      if (fcmToken == null) {
        Logger.warning('Creator has no FCM token', tag: 'NotificationService');
        return;
      }

      // Get claimer's name
      final claimerDoc = await _firestore.collection('users').doc(claimerId).get();
      final claimerName = claimerDoc.data()?['displayName'] as String? ?? 'Someone';

      // Send notification via Firestore (we'll use Cloud Functions or a server to send actual push)
      // For now, we'll create a notification document that can be read by the app
      await _firestore.collection('notifications').add({
        'userId': creatorId,
        'type': 'job_claim',
        'jobId': jobId,
        'jobTitle': jobTitle,
        'claimerId': claimerId,
        'claimerName': claimerName,
        'message': '$claimerName wants to claim "$jobTitle"',
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      Logger.info('Notification created for job claim: $jobId', tag: 'NotificationService');
    } catch (e, st) {
      Logger.error('Error sending job claim notification', error: e, stackTrace: st, tag: 'NotificationService');
    }
  }

  // Send notification to job creator when job is completed and needs approval
  Future<void> notifyJobCompleted(String jobId, String jobTitle, String completerId) async {
    try {
      // Get the job to find the creator - use the same logic as TaskService
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      final userId = _auth.currentUser?.uid;
      if (familyId == null && userId == null) return;

      final newPath = familyId != null ? 'families/$familyId/tasks' : null;
      final oldPath = userId != null ? 'families/$userId/tasks' : null;
      
      DocumentSnapshot? jobDoc;
      if (newPath != null) {
        jobDoc = await _firestore.collection(newPath).doc(jobId).get();
      }
      if ((jobDoc == null || !jobDoc.exists) && oldPath != null && oldPath != newPath) {
        jobDoc = await _firestore.collection(oldPath).doc(jobId).get();
      }

      if (jobDoc == null || !jobDoc.exists) {
        Logger.warning('Job not found for notification: $jobId', tag: 'NotificationService');
        return;
      }

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      final creatorId = jobData?['createdBy'] as String?;
      final needsApproval = jobData?['needsApproval'] == true;
      
      if (creatorId == null || !needsApproval) return;

      // Get creator's FCM token
      final creatorDoc = await _firestore.collection('users').doc(creatorId).get();
      if (!creatorDoc.exists) return;

      final creatorData = creatorDoc.data();
      final fcmToken = creatorData?['fcmToken'] as String?;
      if (fcmToken == null) {
        Logger.warning('Creator has no FCM token', tag: 'NotificationService');
        return;
      }

      // Get completer's name
      final completerDoc = await _firestore.collection('users').doc(completerId).get();
      final completerName = completerDoc.data()?['displayName'] as String? ?? 'Someone';

      // Create notification document
      await _firestore.collection('notifications').add({
        'userId': creatorId,
        'type': 'job_completed',
        'jobId': jobId,
        'jobTitle': jobTitle,
        'completerId': completerId,
        'completerName': completerName,
        'message': '$completerName completed "$jobTitle" - approval needed',
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      Logger.info('Notification created for job completion: $jobId', tag: 'NotificationService');
    } catch (e, st) {
      Logger.error('Error sending job completion notification', error: e, stackTrace: st, tag: 'NotificationService');
    }
  }

  // Send notification to job creator when job is refunded
  Future<void> notifyJobRefunded(String jobId, String jobTitle, String reason, String? note) async {
    try {
      // Get the job to find the creator
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      final userId = _auth.currentUser?.uid;
      if (familyId == null && userId == null) return;

      final newPath = familyId != null ? 'families/$familyId/tasks' : null;
      final oldPath = userId != null ? 'families/$userId/tasks' : null;
      
      DocumentSnapshot? jobDoc;
      if (newPath != null) {
        jobDoc = await _firestore.collection(newPath).doc(jobId).get();
      }
      if ((jobDoc == null || !jobDoc.exists) && oldPath != null && oldPath != newPath) {
        jobDoc = await _firestore.collection(oldPath).doc(jobId).get();
      }

      if (jobDoc == null || !jobDoc.exists) {
        Logger.warning('Job not found for refund notification: $jobId', tag: 'NotificationService');
        return;
      }

      final jobData = jobDoc.data() as Map<String, dynamic>?;
      final creatorId = jobData?['createdBy'] as String?;
      if (creatorId == null) return;

      // Get refunder's name
      final refunderId = _auth.currentUser?.uid;
      final refunderDoc = refunderId != null 
          ? await _firestore.collection('users').doc(refunderId).get()
          : null;
      final refunderName = refunderDoc?.data()?['displayName'] as String? ?? 'Someone';

      // Create notification document
      final notificationData = {
        'userId': creatorId,
        'type': 'job_refunded',
        'jobId': jobId,
        'jobTitle': jobTitle,
        'refunderId': refunderId,
        'refunderName': refunderName,
        'reason': reason,
        'note': note,
        'message': 'Funds have been returned to your wallet for "$jobTitle"',
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _firestore.collection('notifications').add(notificationData);

      Logger.info('Notification created for job refund: $jobId', tag: 'NotificationService');
    } catch (e, st) {
      Logger.error('Error sending job refund notification', error: e, stackTrace: st, tag: 'NotificationService');
    }
  }

  /// Send birthday reminder notification to family members
  /// This should be called by a Cloud Function scheduled to run daily
  /// For now, we'll create a notification document that can trigger push notifications
  Future<void> notifyBirthdayReminder(String birthdayUserId, String birthdayUserName, int ageTurning, DateTime birthdayDate) async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      final familyId = userModel?.familyId;
      if (familyId == null) return;

      // Get all family members except the birthday person
      final familyMembers = await _authService.getFamilyMembers();
      final recipients = familyMembers.where((member) => 
        member.uid != birthdayUserId && 
        member.birthdayNotificationsEnabled
      ).toList();

      // Create notification for each family member
      final batch = _firestore.batch();
      for (var recipient in recipients) {
        final notificationRef = _firestore.collection('notifications').doc();
        batch.set(notificationRef, {
          'userId': recipient.uid,
          'type': 'birthday_reminder',
          'birthdayUserId': birthdayUserId,
          'birthdayUserName': birthdayUserName,
          'ageTurning': ageTurning,
          'birthdayDate': birthdayDate.toIso8601String(),
          'message': '$birthdayUserName is turning $ageTurning tomorrow!',
          'read': false,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }

      await batch.commit();
      Logger.info('Birthday reminder notifications created for ${recipients.length} family members', tag: 'NotificationService');
    } catch (e, st) {
      Logger.error('Error sending birthday reminder notifications', error: e, stackTrace: st, tag: 'NotificationService');
    }
  }

  /// Send push notification to trigger calendar sync when another family member creates/edits event
  /// This is called by Cloud Functions or when events are created/updated
  Future<void> notifyCalendarSyncTrigger(String familyId) async {
    try {
      // Get all family members
      final familyMembers = await _authService.getFamilyMembers();
      
      // Send quiet push to all members with calendar sync enabled
      final batch = _firestore.batch();
      for (var member in familyMembers) {
        if (member.calendarSyncEnabled && member.localCalendarId != null) {
          final notificationRef = _firestore.collection('notifications').doc();
          batch.set(notificationRef, {
            'userId': member.uid,
            'type': 'calendar_sync_trigger',
            'message': 'New calendar event - syncing...',
            'read': false,
            'createdAt': DateTime.now().toIso8601String(),
            'data': {
              'action': 'sync_calendar',
            },
          });
        }
      }
      
      await batch.commit();
      Logger.info('Calendar sync trigger notifications created', tag: 'NotificationService');
    } catch (e, st) {
      Logger.error('Error sending calendar sync trigger', error: e, stackTrace: st, tag: 'NotificationService');
    }
  }

  /// Send a generic notification to a user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
      Logger.info('Notification sent to user $userId', tag: 'NotificationService');
    } catch (e, st) {
      Logger.error('Error sending notification', error: e, stackTrace: st, tag: 'NotificationService');
    }
  }

  /// Send notification when a chess game challenge is created
  Future<void> notifyChessChallenge({
    required String invitedPlayerId,
    required String challengerName,
    required String gameId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': invitedPlayerId,
        'type': 'chess_challenge',
        'gameId': gameId,
        'challengerName': challengerName,
        'title': 'Chess Challenge',
        'body': '$challengerName challenged you to a game of chess!',
        'message': '$challengerName challenged you to a game of chess!',
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
        'data': {
          'action': 'open_chess_game',
          'gameId': gameId,
        },
      });
      Logger.info('Chess challenge notification sent to $invitedPlayerId', tag: 'NotificationService');
    } catch (e, st) {
      Logger.error('Error sending chess challenge notification', error: e, stackTrace: st, tag: 'NotificationService');
    }
  }

  /// Handle chess invite FCM messages (foreground and background)
  /// Shows snackbar/dialog with Accept/Decline buttons and deep-link navigation
  Future<void> _handleChessInviteMessage(RemoteMessage message) async {
    try {
      final data = message.data;
      final action = data['action'] as String?;
      
      if (action == 'chess_invite') {
        final targetUser = data['targetUser'] as String?;
        final currentUser = _auth.currentUser;
        
        // Only handle if message is for current user
        if (targetUser == null || currentUser == null || targetUser != currentUser.uid) {
          return;
        }
        
        final roomId = data['roomId'] as String?;
        final sender = data['sender'] as String?;
        
        if (roomId == null || sender == null) {
          Logger.warning('Invalid chess invite message data', tag: 'NotificationService');
          return;
        }
        
        // Get sender name
        final senderModel = await _authService.getUserModel(sender);
        final senderName = senderModel?.displayName ?? 'Someone';
        
        // Show invite dialog/snackbar
        if (navigatorKey?.currentContext != null) {
          final context = navigatorKey!.currentContext!;
          _showChessInviteDialog(context, roomId, senderName);
        }
      } else if (action == 'chess_start') {
        final roomId = data['roomId'] as String?;
        final players = data['players'] as List?;
        final currentUser = _auth.currentUser;
        
        // Check if current user is a player
        if (roomId == null || players == null || currentUser == null) {
          return;
        }
        
        if (!players.contains(currentUser.uid)) {
          return;
        }
        
        // Vibrate once
        if (await Vibration.hasVibrator() ?? false) {
          await Vibration.vibrate(duration: 100);
        }
        
        // Navigate to game room
        if (navigatorKey?.currentContext != null) {
          final context = navigatorKey!.currentContext!;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChessGameScreen(gameId: roomId, mode: GameMode.family),
            ),
          );
        }
      }
    } catch (e, st) {
      Logger.error('Error handling chess invite message', error: e, stackTrace: st, tag: 'NotificationService');
    }
  }
  
  /// Show chess invite dialog with Accept/Decline buttons
  void _showChessInviteDialog(BuildContext context, String roomId, String senderName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chess Challenge'),
        content: Text('$senderName challenged you to a game of chess!'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final chessService = getIt<ChessService>();
                await chessService.declineInvite(roomId);
              } catch (e) {
                Logger.error('Error declining invite', error: e, tag: 'NotificationService');
              }
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final chessService = getIt<ChessService>();
                await chessService.acceptInvite(roomId);
                // Navigate to game room
                if (navigatorKey?.currentContext != null) {
                  Navigator.push(
                    navigatorKey!.currentContext!,
                    MaterialPageRoute(
                      builder: (_) => ChessGameScreen(gameId: roomId, mode: GameMode.family),
                    ),
                  );
                }
              } catch (e) {
                Logger.error('Error accepting invite', error: e, tag: 'NotificationService');
                if (navigatorKey?.currentContext != null) {
                  ScaffoldMessenger.of(navigatorKey!.currentContext!).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Logger.info('Handling a background message: ${message.messageId}', tag: 'NotificationService');
  Logger.debug('Message data: ${message.data}', tag: 'NotificationService');
}

