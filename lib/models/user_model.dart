import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final String? familyId;
  final List<String> roles; // e.g., ['admin', 'banker', 'approver']
  final String? relationship; // Relationship from family creator's perspective (e.g., 'father', 'mother', 'daughter', 'son')
  final DateTime? birthday; // User's birthday
  final bool birthdayNotificationsEnabled; // Whether to send birthday reminder notifications
  // Calendar Sync Settings
  final bool calendarSyncEnabled; // Whether calendar sync is enabled
  final String? localCalendarId; // device_calendar plugin ID
  final String? googleCalendarId; // Optional if using Google API directly
  final DateTime? lastSyncedAt; // Last successful sync timestamp
  final bool locationPermissionGranted; // Whether location sharing is enabled

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.familyId,
    List<String>? roles,
    this.relationship,
    this.birthday,
    bool? birthdayNotificationsEnabled,
    bool? calendarSyncEnabled,
    this.localCalendarId,
    this.googleCalendarId,
    this.lastSyncedAt,
    bool? locationPermissionGranted,
  }) : roles = roles ?? [],
       birthdayNotificationsEnabled = birthdayNotificationsEnabled ?? true,
       calendarSyncEnabled = calendarSyncEnabled ?? false,
       locationPermissionGranted = locationPermissionGranted ?? false;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'createdAt': createdAt.toIso8601String(),
        'familyId': familyId,
        'roles': roles,
        if (relationship != null) 'relationship': relationship,
        if (birthday != null) 'birthday': birthday!.toIso8601String(),
        'birthdayNotificationsEnabled': birthdayNotificationsEnabled,
        'calendarSyncEnabled': calendarSyncEnabled,
        if (localCalendarId != null) 'localCalendarId': localCalendarId,
        if (googleCalendarId != null) 'googleCalendarId': googleCalendarId,
        if (lastSyncedAt != null) 'lastSyncedAt': lastSyncedAt!.toIso8601String(),
        'locationPermissionGranted': locationPermissionGranted,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle roles - could be List or missing
    List<String> roles = [];
    if (json['roles'] != null) {
      if (json['roles'] is List) {
        roles = (json['roles'] as List).map((e) => e.toString()).toList();
      }
    }
    
    // Handle createdAt - can be Timestamp, String, or DateTime
    // This fixes the Android login issue where FieldValue.serverTimestamp() creates Timestamp objects
    DateTime parseCreatedAt(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          debugPrint('UserModel.fromJson: Error parsing createdAt string "$value": $e');
          return DateTime.now();
        }
      }
      debugPrint('UserModel.fromJson: Unexpected createdAt type: ${value.runtimeType}, value: $value');
      return DateTime.now();
    }
    
    // Handle birthday - can be Timestamp, String, or DateTime
    DateTime? parseBirthday(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          debugPrint('UserModel.fromJson: Error parsing birthday string "$value": $e');
          return null;
        }
      }
      debugPrint('UserModel.fromJson: Unexpected birthday type: ${value.runtimeType}, value: $value');
      return null;
    }
    
    // Handle lastSyncedAt - can be Timestamp, String, or DateTime
    DateTime? parseLastSyncedAt(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          debugPrint('UserModel.fromJson: Error parsing lastSyncedAt string "$value": $e');
          return null;
        }
      }
      debugPrint('UserModel.fromJson: Unexpected lastSyncedAt type: ${value.runtimeType}, value: $value');
      return null;
    }
    
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      createdAt: parseCreatedAt(json['createdAt']),
      familyId: json['familyId'] as String?,
      roles: roles,
      relationship: json['relationship'] as String?,
      birthday: parseBirthday(json['birthday']),
      birthdayNotificationsEnabled: json['birthdayNotificationsEnabled'] as bool? ?? true,
      calendarSyncEnabled: json['calendarSyncEnabled'] as bool? ?? false,
      localCalendarId: json['localCalendarId'] as String?,
      googleCalendarId: json['googleCalendarId'] as String?,
      lastSyncedAt: parseLastSyncedAt(json['lastSyncedAt']),
      locationPermissionGranted: json['locationPermissionGranted'] as bool? ?? false,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    String? familyId,
    List<String>? roles,
    String? relationship,
    DateTime? birthday,
    bool? birthdayNotificationsEnabled,
    bool? calendarSyncEnabled,
    String? localCalendarId,
    String? googleCalendarId,
    DateTime? lastSyncedAt,
    bool? locationPermissionGranted,
  }) =>
      UserModel(
        uid: uid ?? this.uid,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt ?? this.createdAt,
        familyId: familyId ?? this.familyId,
        roles: roles ?? this.roles,
        relationship: relationship ?? this.relationship,
        birthday: birthday ?? this.birthday,
        birthdayNotificationsEnabled: birthdayNotificationsEnabled ?? this.birthdayNotificationsEnabled,
        calendarSyncEnabled: calendarSyncEnabled ?? this.calendarSyncEnabled,
        localCalendarId: localCalendarId ?? this.localCalendarId,
        googleCalendarId: googleCalendarId ?? this.googleCalendarId,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        locationPermissionGranted: locationPermissionGranted ?? this.locationPermissionGranted,
      );
  
  // Helper methods for role checking
  bool hasRole(String role) => roles.contains(role.toLowerCase());
  bool isAdmin() => hasRole('admin');
  bool isBanker() => hasRole('banker');
  bool isApprover() => hasRole('approver');
  bool isShopper() => hasRole('shopper');
  
  /// Check if user can perform shopping actions (mark items as got/unavailable)
  /// By default, all adults (admins, bankers, approvers) can shop, plus anyone with shopper role
  bool canShop() => isAdmin() || isBanker() || isApprover() || isShopper();
}

