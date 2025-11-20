import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:uuid/uuid.dart';
import '../models/hub.dart';
import 'auth_service.dart';
import 'notification_service.dart';

/// Service for managing video calls using Agora
class VideoCallService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final Uuid _uuid = const Uuid();

  // Agora configuration - these should be set from environment variables or config
  // For production, use Cloud Functions to generate tokens securely
  static const String appId = 'YOUR_AGORA_APP_ID'; // TODO: Replace with actual App ID
  static const String appCertificate = 'YOUR_AGORA_APP_CERTIFICATE'; // TODO: Replace with actual certificate

  RtcEngine? _engine;
  bool _isInitialized = false;

  /// Initialize Agora engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Enable video
      await _engine!.enableVideo();
      await _engine!.startPreview();

      _isInitialized = true;
      debugPrint('VideoCallService: Agora engine initialized');
    } catch (e) {
      debugPrint('Error initializing Agora engine: $e');
      rethrow;
    }
  }

  /// Create or join a video call in a hub
  Future<String> createCall(String hubId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await initialize();

    final channelName = _uuid.v4();
    final callId = _uuid.v4();

    // Create call document
    await _firestore.collection('calls').doc(hubId).set({
      'active_call': {
        'channelName': channelName,
        'initiatorId': user.uid,
        'startTime': DateTime.now().toIso8601String(),
        'callId': callId,
        'participants': [user.uid],
      },
    });

    // Notify hub members
    await _notifyCallStart(hubId, channelName);

    return channelName;
  }

  /// Join an existing call
  Future<void> joinCall(String hubId, String channelName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await initialize();

    // Update call document with new participant
    final callDoc = await _firestore.collection('calls').doc(hubId).get();
    if (callDoc.exists) {
      final data = callDoc.data();
      final activeCall = data?['active_call'] as Map<String, dynamic>?;
      if (activeCall != null) {
        final participants = List<String>.from(activeCall['participants'] as List? ?? []);
        if (!participants.contains(user.uid)) {
          participants.add(user.uid);
          await _firestore.collection('calls').doc(hubId).update({
            'active_call.participants': participants,
          });
        }
      }
    }
  }

  /// Leave a call
  Future<void> leaveCall(String hubId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Remove participant from call
    final callDoc = await _firestore.collection('calls').doc(hubId).get();
    if (callDoc.exists) {
      final data = callDoc.data();
      final activeCall = data?['active_call'] as Map<String, dynamic>?;
      if (activeCall != null) {
        final participants = List<String>.from(activeCall['participants'] as List? ?? []);
        participants.remove(user.uid);

        if (participants.isEmpty) {
          // Delete call if no participants
          await _firestore.collection('calls').doc(hubId).delete();
        } else {
          // Update participants list
          await _firestore.collection('calls').doc(hubId).update({
            'active_call.participants': participants,
          });
        }
      }
    }
  }

  /// Get active call for a hub
  Future<Map<String, dynamic>?> getActiveCall(String hubId) async {
    try {
      final doc = await _firestore.collection('calls').doc(hubId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      return data?['active_call'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting active call: $e');
      return null;
    }
  }

  /// Stream active calls for a hub
  Stream<Map<String, dynamic>?> getActiveCallStream(String hubId) {
    return _firestore
        .collection('calls')
        .doc(hubId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      return data?['active_call'] as Map<String, dynamic>?;
    });
  }

  /// Generate Agora token (should be done server-side in production)
  /// For now, returns a placeholder - implement with Cloud Functions
  Future<String> generateToken(String channelName, int uid) async {
    // TODO: Implement token generation via Cloud Function
    // For development, you can use temporary tokens from Agora Console
    throw UnimplementedError('Token generation must be implemented server-side');
  }

  /// Notify hub members of incoming call
  Future<void> _notifyCallStart(String hubId, String channelName) async {
    try {
      final hubDoc = await _firestore.collection('hubs').doc(hubId).get();
      if (!hubDoc.exists) return;

      final hubData = hubDoc.data();
      final memberIds = List<String>.from(hubData?['memberIds'] as List? ?? []);
      final initiatorId = _auth.currentUser?.uid;

      for (var memberId in memberIds) {
        if (memberId != initiatorId) {
          await _notificationService.sendNotification(
            userId: memberId,
            title: 'Incoming Video Call',
            body: 'Tap to join the call',
            data: {
              'type': 'video_call',
              'hubId': hubId,
              'channelName': channelName,
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Error notifying call start: $e');
    }
  }

  /// Dispose engine
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    _isInitialized = false;
  }

  /// Get RtcEngine instance
  RtcEngine? get engine => _engine;
}

