import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/errors/app_exceptions.dart';
import '../models/family_member.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  
  // Rate limiting: track last request time per user pair
  final Map<String, DateTime> _lastRequestTime = {};

  Future<String?> get _familyId async {
    final userModel = await _authService.getCurrentUserModel();
    return userModel?.familyId;
  }

  Future<String> get _collectionPath async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    return 'families/$familyId/members';
  }

  Future<List<FamilyMember>> getFamilyMembers() async {
    final familyId = await _familyId;
    if (familyId == null) return [];
    
    // Get family members from users collection
    final familyMembers = await _authService.getFamilyMembers();
    
    // Also get location data from members collection
    final collectionPath = await _collectionPath;
    final snapshot = await _firestore.collection(collectionPath).get();
    final locationMap = <String, Map<String, dynamic>>{};
    
    for (var doc in snapshot.docs) {
      locationMap[doc.id] = doc.data();
    }
    
    return familyMembers.map((user) {
      final locationData = locationMap[user.uid];
      return FamilyMember(
        id: user.uid,
        name: user.displayName,
        email: user.email,
        latitude: locationData?['latitude'] as double?,
        longitude: locationData?['longitude'] as double?,
        lastSeen: locationData?['lastSeen'] != null
            ? DateTime.parse(locationData!['lastSeen'] as String)
            : null,
      );
    }).toList();
  }

  Stream<List<FamilyMember>> getFamilyMembersStream() async* {
    final familyId = await _familyId;
    if (familyId == null) {
      yield [];
      return;
    }
    
    final collectionPath = await _collectionPath;
    yield* _firestore
        .collection(collectionPath)
        .snapshots()
        .asyncMap((snapshot) async {
      final familyMembers = await _authService.getFamilyMembers();
      final locationMap = <String, Map<String, dynamic>>{};
      
      for (var doc in snapshot.docs) {
        locationMap[doc.id] = doc.data();
      }
      
      return familyMembers.map((user) {
        final locationData = locationMap[user.uid];
        return FamilyMember(
          id: user.uid,
          name: user.displayName,
          email: user.email,
          latitude: locationData?['latitude'] as double?,
          longitude: locationData?['longitude'] as double?,
          lastSeen: locationData?['lastSeen'] != null
              ? DateTime.parse(locationData!['lastSeen'] as String)
              : null,
        );
      }).toList();
    });
  }

  Future<void> updateMemberLocation(
    String memberId,
    double latitude,
    double longitude,
  ) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    final collectionPath = await _collectionPath;
    await _firestore.collection(collectionPath).doc(memberId).set({
      'latitude': latitude,
      'longitude': longitude,
      'lastSeen': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> addMember(FamilyMember member) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    final collectionPath = await _collectionPath;
    await _firestore.collection(collectionPath).doc(member.id).set({
      'latitude': member.latitude,
      'longitude': member.longitude,
      'lastSeen': member.lastSeen?.toIso8601String(),
    });
  }

  /// Request a location update from a family member
  /// Creates a push notification for the target user
  /// Rate limited to 1 request per hour per person
  Future<void> requestLocationUpdate(String targetUserId) async {
    final currentUser = await _authService.getCurrentUserModel();
    if (currentUser == null) throw AuthException('User not authenticated', code: 'not-authenticated');
    
    // Rate limiting: Check if we've requested from this user in the last hour
    final rateLimitKey = '${currentUser.uid}_$targetUserId';
    final lastRequest = _lastRequestTime[rateLimitKey];
    if (lastRequest != null) {
      final timeSinceLastRequest = DateTime.now().difference(lastRequest);
      if (timeSinceLastRequest.inHours < 1) {
        final targetName = await _getTargetUserName(targetUserId);
        throw Exception(
          'You can only request location from $targetName once per hour. '
          'Please wait ${60 - timeSinceLastRequest.inMinutes} more minutes.',
        );
      }
    }
    
    // Update rate limit tracking
    _lastRequestTime[rateLimitKey] = DateTime.now();
    
    // Send push notification via NotificationService
    await _notificationService.sendNotification(
      userId: targetUserId,
      title: 'Location Request',
      body: '${currentUser.displayName} is requesting your location',
      data: {
        'type': 'location_request',
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName,
        'action': 'open_location_screen',
      },
    );
    
    // Also create a notification document for tracking
    await _firestore.collection('notifications').add({
      'userId': targetUserId,
      'type': 'location_request',
      'title': 'Location Request',
      'body': '${currentUser.displayName} is requesting your location',
      'senderId': currentUser.uid,
      'senderName': currentUser.displayName,
      'createdAt': DateTime.now().toIso8601String(),
      'read': false,
      'status': 'pending', // pending, accepted, declined
    });
  }
  
  /// Helper method to get target user's name (for error messages)
  Future<String> _getTargetUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['displayName'] as String? ?? 'this person';
      }
    } catch (e) {
      // Ignore errors
    }
    return 'this person';
  }
}
