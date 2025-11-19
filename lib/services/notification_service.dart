import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

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
      debugPrint('User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional notification permission');
    } else {
      debugPrint('User declined or has not accepted notification permission');
    }

    // Get FCM token and save it to user document
    String? token = await _messaging.getToken();
    if (token != null) {
      await _saveTokenToUser(token);
      debugPrint('FCM Token: $token');
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _saveTokenToUser(newToken);
      debugPrint('FCM Token refreshed: $newToken');
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');
      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
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
      debugPrint('FCM token saved to user document');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
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
        debugPrint('Job not found for notification: $jobId');
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
        debugPrint('Creator has no FCM token');
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

      debugPrint('Notification created for job claim: $jobId');
    } catch (e) {
      debugPrint('Error sending job claim notification: $e');
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
        debugPrint('Job not found for notification: $jobId');
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
        debugPrint('Creator has no FCM token');
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

      debugPrint('Notification created for job completion: $jobId');
    } catch (e) {
      debugPrint('Error sending job completion notification: $e');
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
        debugPrint('Job not found for refund notification: $jobId');
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

      debugPrint('Notification created for job refund: $jobId');
    } catch (e) {
      debugPrint('Error sending job refund notification: $e');
    }
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
  debugPrint('Message data: ${message.data}');
}

