import '../core/services/logger_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/privacy_activity.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Service for managing privacy settings and sharing controls
class PrivacyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  /// Get all active shares for the current user
  Future<List<Map<String, dynamic>>> getActiveShares() async {
    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) return [];

    final List<Map<String, dynamic>> shares = [];

    // Check location sharing
    if (userModel.locationPermissionGranted) {
      // Check if location document exists and hasn't expired
      final locationDoc = await _firestore
          .collection('family_locations')
          .doc(userModel.uid)
          .get();
      
      if (locationDoc.exists) {
        final data = locationDoc.data();
        final expiresAt = data?['expiresAt'] != null
            ? DateTime.parse(data!['expiresAt'] as String)
            : null;
        
        if (expiresAt == null || expiresAt.isAfter(DateTime.now())) {
          shares.add({
            'type': 'location',
            'name': 'Location Sharing',
            'description': 'Your location is being shared with family',
            'icon': Icons.location_on,
            'enabled': true,
          });
        }
      }
    }

    // Check calendar sync
    if (userModel.calendarSyncEnabled) {
      shares.add({
        'type': 'calendar',
        'name': 'Calendar Sync',
        'description': 'Syncing events with your device calendar',
        'icon': Icons.calendar_today,
        'enabled': true,
      });
    }

    // Check birthday visibility
    if (userModel.birthday != null && userModel.birthdayNotificationsEnabled) {
      shares.add({
        'type': 'birthday',
        'name': 'Birthday Visibility',
        'description': 'Family can see your birthday and receive reminders',
        'icon': Icons.cake,
        'enabled': true,
      });
    }

    // Check geofence alerts (if location is shared)
    if (userModel.locationPermissionGranted) {
      shares.add({
        'type': 'geofence',
        'name': 'Geofence Alerts',
        'description': 'Family receives alerts when you arrive home',
        'icon': Icons.home,
        'enabled': true,
      });
    }

    return shares;
  }

  /// Pause a specific share type
  Future<void> pauseShare(String shareType) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _logActivity('paused', shareType);
    
    switch (shareType) {
      case 'location':
        await _firestore.collection('users').doc(user.uid).update({
          'locationPermissionGranted': false,
        });
        break;
      case 'calendar':
        await _firestore.collection('users').doc(user.uid).update({
          'calendarSyncEnabled': false,
        });
        break;
      case 'birthday':
        await _firestore.collection('users').doc(user.uid).update({
          'birthdayNotificationsEnabled': false,
        });
        break;
      case 'geofence':
        // Geofence is tied to location, so pausing location pauses geofence
        await _firestore.collection('users').doc(user.uid).update({
          'locationPermissionGranted': false,
        });
        break;
    }
  }

  /// Stop all sharing
  Future<void> stopAllSharing() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _logActivity('stopped', 'all');
    
    await _firestore.collection('users').doc(user.uid).update({
      'locationPermissionGranted': false,
      'calendarSyncEnabled': false,
      'birthdayNotificationsEnabled': false,
    });

    // Delete location document
    await _firestore.collection('family_locations').doc(user.uid).delete();
  }

  /// Get recent privacy activity (last 8 actions)
  Future<List<PrivacyActivity>> getRecentActivity() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('privacy_activity')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(8)
          .get();

      return snapshot.docs
          .map((doc) => PrivacyActivity.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error loading privacy activity', error: e, tag: 'PrivacyService');
      return [];
    }
  }

  /// Log a privacy activity
  Future<void> _logActivity(String action, String shareType) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final activity = PrivacyActivity(
      id: _firestore.collection('privacy_activity').doc().id,
      userId: user.uid,
      action: action,
      shareType: shareType,
      timestamp: DateTime.now(),
    );

    await _firestore
        .collection('privacy_activity')
        .doc(activity.id)
        .set(activity.toJson());
  }
}

