import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'subscription_tier.dart';

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
  
  // Subscription & Premium Features
  final SubscriptionTier? subscriptionTier; // Current subscription tier (null = free)
  final SubscriptionStatus? subscriptionStatus; // Current subscription status
  final DateTime? subscriptionExpiresAt; // When subscription expires (null = no expiration or lifetime)
  final DateTime? subscriptionPurchaseDate; // When subscription was purchased
  final SubscriptionPlatform? subscriptionPlatform; // Platform where subscription was purchased ('google' | 'apple' | null)
  final List<String> premiumHubTypes; // List of premium hub types user has access to (e.g., ['extended_family', 'homeschooling'])
  final String? subscriptionPurchaseToken; // Purchase token/receipt for verification (platform-specific)

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
    this.subscriptionTier,
    this.subscriptionStatus,
    this.subscriptionExpiresAt,
    this.subscriptionPurchaseDate,
    this.subscriptionPlatform,
    List<String>? premiumHubTypes,
    this.subscriptionPurchaseToken,
  }) : roles = roles ?? [],
       birthdayNotificationsEnabled = birthdayNotificationsEnabled ?? true,
       calendarSyncEnabled = calendarSyncEnabled ?? false,
       locationPermissionGranted = locationPermissionGranted ?? false,
       premiumHubTypes = premiumHubTypes ?? [];

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
        if (subscriptionTier != null) 'subscriptionTier': subscriptionTier!.name,
        if (subscriptionStatus != null) 'subscriptionStatus': subscriptionStatus!.name,
        if (subscriptionExpiresAt != null) 'subscriptionExpiresAt': subscriptionExpiresAt!.toIso8601String(),
        if (subscriptionPurchaseDate != null) 'subscriptionPurchaseDate': subscriptionPurchaseDate!.toIso8601String(),
        if (subscriptionPlatform != null) 'subscriptionPlatform': subscriptionPlatform!.name,
        if (premiumHubTypes.isNotEmpty) 'premiumHubTypes': premiumHubTypes,
        if (subscriptionPurchaseToken != null) 'subscriptionPurchaseToken': subscriptionPurchaseToken,
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
    
    // Helper to parse DateTime fields (subscription dates)
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
    
    // Parse subscription tier
    SubscriptionTier? parseSubscriptionTier(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return SubscriptionTier.values.firstWhere(
          (tier) => tier.name == value,
          orElse: () => SubscriptionTier.free,
        );
      }
      return null;
    }
    
    // Parse subscription status
    SubscriptionStatus? parseSubscriptionStatus(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return SubscriptionStatus.values.firstWhere(
          (status) => status.name == value,
          orElse: () => SubscriptionStatus.expired,
        );
      }
      return null;
    }
    
    // Parse subscription platform
    SubscriptionPlatform? parseSubscriptionPlatform(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return SubscriptionPlatform.values.firstWhere(
          (platform) => platform.name == value,
          orElse: () => SubscriptionPlatform.google,
        );
      }
      return null;
    }
    
    // Parse premium hub types
    List<String> parsePremiumHubTypes(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
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
      subscriptionTier: parseSubscriptionTier(json['subscriptionTier']),
      subscriptionStatus: parseSubscriptionStatus(json['subscriptionStatus']),
      subscriptionExpiresAt: parseDateTime(json['subscriptionExpiresAt']),
      subscriptionPurchaseDate: parseDateTime(json['subscriptionPurchaseDate']),
      subscriptionPlatform: parseSubscriptionPlatform(json['subscriptionPlatform']),
      premiumHubTypes: parsePremiumHubTypes(json['premiumHubTypes']),
      subscriptionPurchaseToken: json['subscriptionPurchaseToken'] as String?,
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
    DateTime? subscriptionPurchaseDate,
    SubscriptionPlatform? subscriptionPlatform,
    List<String>? premiumHubTypes,
    String? subscriptionPurchaseToken,
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
      subscriptionPurchaseDate: subscriptionPurchaseDate ?? this.subscriptionPurchaseDate,
      subscriptionPlatform: subscriptionPlatform ?? this.subscriptionPlatform,
      premiumHubTypes: premiumHubTypes ?? this.premiumHubTypes,
      subscriptionPurchaseToken: subscriptionPurchaseToken ?? this.subscriptionPurchaseToken,
      );
  
  // Helper methods for role checking
  bool hasRole(String role) => roles.contains(role.toLowerCase());
  bool isAdmin() => hasRole('admin');
  bool isBanker() => hasRole('banker');
  bool isApprover() => hasRole('approver');
  
  // Helper methods for subscription checking
  /// Check if user has an active premium subscription
  bool hasActivePremiumSubscription() {
    if (subscriptionTier != SubscriptionTier.premium) return false;
    if (subscriptionStatus == null) return false;
    if (!subscriptionStatus!.isActive) return false;
    
    // Check if subscription has expired
    if (subscriptionExpiresAt != null && subscriptionExpiresAt!.isBefore(DateTime.now())) {
      return false;
    }
    
    return true;
  }
  
  /// Check if user has access to a specific premium hub type
  bool hasPremiumHubAccess(String hubType) {
    if (!hasActivePremiumSubscription()) return false;
    return premiumHubTypes.contains(hubType);
  }
  
  /// Check if user has access to encrypted chat
  bool hasEncryptedChatAccess() {
    return hasActivePremiumSubscription() && 
           (subscriptionTier?.hasEncryptedChatAccess ?? false);
  }
  
  /// Get days until subscription expires (null if no expiration or already expired)
  int? getDaysUntilExpiration() {
    if (subscriptionExpiresAt == null) return null;
    final now = DateTime.now();
    if (subscriptionExpiresAt!.isBefore(now)) return null;
    return subscriptionExpiresAt!.difference(now).inDays;
  }
}

