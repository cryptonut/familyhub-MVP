import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum SubscriptionTier {
  free,
  premium, // Individual premium
  familyPlus, // Family plan (some premium hubs)
  familyPremium // All access
}

enum SubscriptionStatus {
  active,
  expired,
  cancelled,
  trial,
  none
}

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
  
  // Freemium / Subscription Fields
  final SubscriptionTier subscriptionTier;
  final SubscriptionStatus subscriptionStatus;
  final DateTime? subscriptionExpiresAt;
  final List<String> premiumHubTypes; // List of hub types the user has unlocked (e.g., 'extended_family')
  final DateTime? subscriptionPurchaseDate;
  final String? subscriptionPlatform; // 'google', 'apple', etc.

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
    this.subscriptionTier = SubscriptionTier.free,
    this.subscriptionStatus = SubscriptionStatus.none,
    this.subscriptionExpiresAt,
    this.premiumHubTypes = const [],
    this.subscriptionPurchaseDate,
    this.subscriptionPlatform,
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
        'subscriptionTier': subscriptionTier.toString().split('.').last,
        'subscriptionStatus': subscriptionStatus.toString().split('.').last,
        if (subscriptionExpiresAt != null) 'subscriptionExpiresAt': subscriptionExpiresAt!.toIso8601String(),
        'premiumHubTypes': premiumHubTypes,
        if (subscriptionPurchaseDate != null) 'subscriptionPurchaseDate': subscriptionPurchaseDate!.toIso8601String(),
        if (subscriptionPlatform != null) 'subscriptionPlatform': subscriptionPlatform,
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
      return DateTime.now();
    }
    
    // Handle optional DateTimes
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          debugPrint('UserModel.fromJson: Error parsing DateTime string "$value": $e');
          return null;
        }
      }
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
      birthday: parseDateTime(json['birthday']),
      birthdayNotificationsEnabled: json['birthdayNotificationsEnabled'] as bool? ?? true,
      calendarSyncEnabled: json['calendarSyncEnabled'] as bool? ?? false,
      localCalendarId: json['localCalendarId'] as String?,
      googleCalendarId: json['googleCalendarId'] as String?,
      lastSyncedAt: parseDateTime(json['lastSyncedAt']),
      locationPermissionGranted: json['locationPermissionGranted'] as bool? ?? false,
      subscriptionTier: SubscriptionTier.values.firstWhere(
        (e) => e.toString().split('.').last == json['subscriptionTier'],
        orElse: () => SubscriptionTier.free,
      ),
      subscriptionStatus: SubscriptionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['subscriptionStatus'],
        orElse: () => SubscriptionStatus.none,
      ),
      subscriptionExpiresAt: parseDateTime(json['subscriptionExpiresAt']),
      premiumHubTypes: List<String>.from(json['premiumHubTypes'] as List? ?? []),
      subscriptionPurchaseDate: parseDateTime(json['subscriptionPurchaseDate']),
      subscriptionPlatform: json['subscriptionPlatform'] as String?,
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
    SubscriptionTier? subscriptionTier,
    SubscriptionStatus? subscriptionStatus,
    DateTime? subscriptionExpiresAt,
    List<String>? premiumHubTypes,
    DateTime? subscriptionPurchaseDate,
    String? subscriptionPlatform,
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
        subscriptionTier: subscriptionTier ?? this.subscriptionTier,
        subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
        subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
        premiumHubTypes: premiumHubTypes ?? this.premiumHubTypes,
        subscriptionPurchaseDate: subscriptionPurchaseDate ?? this.subscriptionPurchaseDate,
        subscriptionPlatform: subscriptionPlatform ?? this.subscriptionPlatform,
      );
  
  // Helper methods for role checking
  bool hasRole(String role) => roles.contains(role.toLowerCase());
  bool isAdmin() => hasRole('admin');
  bool isBanker() => hasRole('banker');
  bool isApprover() => hasRole('approver');
  
  // Helper methods for subscription checking
  bool get isPremium => subscriptionTier != SubscriptionTier.free && subscriptionStatus == SubscriptionStatus.active;
  bool hasHubAccess(String hubType) => premiumHubTypes.contains(hubType) || subscriptionTier == SubscriptionTier.familyPremium;
}
