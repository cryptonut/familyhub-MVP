import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/extended_family_relationship.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';

/// Privacy settings for extended family hubs
class ExtendedFamilyPrivacySettings {
  final String hubId;
  final String userId;
  final PrivacyLevel calendarVisibility;
  final PrivacyLevel photoVisibility;
  final PrivacyLevel messageVisibility;
  final PrivacyLevel locationVisibility;
  final bool showBirthday;
  final bool showPhoneNumber;
  final bool showEmail;
  final DateTime updatedAt;

  ExtendedFamilyPrivacySettings({
    required this.hubId,
    required this.userId,
    this.calendarVisibility = PrivacyLevel.moderate,
    this.photoVisibility = PrivacyLevel.moderate,
    this.messageVisibility = PrivacyLevel.open,
    this.locationVisibility = PrivacyLevel.strict,
    this.showBirthday = true,
    this.showPhoneNumber = false,
    this.showEmail = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'hubId': hubId,
        'userId': userId,
        'calendarVisibility': calendarVisibility.name,
        'photoVisibility': photoVisibility.name,
        'messageVisibility': messageVisibility.name,
        'locationVisibility': locationVisibility.name,
        'showBirthday': showBirthday,
        'showPhoneNumber': showPhoneNumber,
        'showEmail': showEmail,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ExtendedFamilyPrivacySettings.fromJson(Map<String, dynamic> json) =>
      ExtendedFamilyPrivacySettings(
        hubId: json['hubId'] as String,
        userId: json['userId'] as String,
        calendarVisibility: PrivacyLevel.values.firstWhere(
          (e) => e.name == json['calendarVisibility'],
          orElse: () => PrivacyLevel.moderate,
        ),
        photoVisibility: PrivacyLevel.values.firstWhere(
          (e) => e.name == json['photoVisibility'],
          orElse: () => PrivacyLevel.moderate,
        ),
        messageVisibility: PrivacyLevel.values.firstWhere(
          (e) => e.name == json['messageVisibility'],
          orElse: () => PrivacyLevel.open,
        ),
        locationVisibility: PrivacyLevel.values.firstWhere(
          (e) => e.name == json['locationVisibility'],
          orElse: () => PrivacyLevel.strict,
        ),
        showBirthday: json['showBirthday'] as bool? ?? true,
        showPhoneNumber: json['showPhoneNumber'] as bool? ?? false,
        showEmail: json['showEmail'] as bool? ?? false,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

enum PrivacyLevel {
  strict,   // Only core family
  moderate, // Core family + selected extended family
  open,     // All extended family members
}

extension PrivacyLevelExtension on PrivacyLevel {
  String get displayName {
    switch (this) {
      case PrivacyLevel.strict:
        return 'Strict (Core Family Only)';
      case PrivacyLevel.moderate:
        return 'Moderate (Selected Extended Family)';
      case PrivacyLevel.open:
        return 'Open (All Extended Family)';
    }
  }
}

/// Service for managing privacy settings for extended family hubs
class ExtendedFamilyPrivacyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Get privacy settings for a user in a hub
  Future<ExtendedFamilyPrivacySettings?> getPrivacySettings({
    required String hubId,
    String? userId,
  }) async {
    final targetUserId = userId ?? currentUserId;
    if (targetUserId == null) return null;

    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('extended_family_privacy'))
          .where('hubId', isEqualTo: hubId)
          .where('userId', isEqualTo: targetUserId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Return default settings
        return ExtendedFamilyPrivacySettings(
          hubId: hubId,
          userId: targetUserId,
          updatedAt: DateTime.now(),
        );
      }

      return ExtendedFamilyPrivacySettings.fromJson(snapshot.docs.first.data());
    } catch (e) {
      Logger.error('Error getting privacy settings', error: e, tag: 'ExtendedFamilyPrivacyService');
      return null;
    }
  }

  /// Update privacy settings
  Future<void> updatePrivacySettings(ExtendedFamilyPrivacySettings settings) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    // Users can only update their own privacy settings
    if (settings.userId != currentUserId) {
      throw PermissionException(
        'Can only update your own privacy settings',
        code: 'insufficient-permissions',
      );
    }

    try {
      // Find existing settings document
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('extended_family_privacy'))
          .where('hubId', isEqualTo: settings.hubId)
          .where('userId', isEqualTo: settings.userId)
          .limit(1)
          .get();

      final data = settings.toJson();
      data['updatedAt'] = DateTime.now().toIso8601String();

      if (snapshot.docs.isEmpty) {
        // Create new settings
        await _firestore
            .collection(FirestorePathUtils.getCollectionPath('extended_family_privacy'))
            .add(data);
      } else {
        // Update existing settings
        await snapshot.docs.first.reference.update(data);
      }

      Logger.info('Privacy settings updated for user ${settings.userId} in hub ${settings.hubId}', tag: 'ExtendedFamilyPrivacyService');
    } catch (e) {
      Logger.error('Error updating privacy settings', error: e, tag: 'ExtendedFamilyPrivacyService');
      rethrow;
    }
  }

  /// Check if user can view specific content based on privacy settings
  Future<bool> canViewContent({
    required String hubId,
    required String contentOwnerId,
    required PrivacyLevel requiredLevel,
    String? viewerId,
  }) async {
    final targetViewerId = viewerId ?? currentUserId;
    if (targetViewerId == null) return false;

    // Owner can always view their own content
    if (contentOwnerId == targetViewerId) return true;

    // Get content owner's privacy settings
    final settings = await getPrivacySettings(hubId: hubId, userId: contentOwnerId);
    if (settings == null) return false;

    // Check if viewer's permission level meets requirement
    final viewerPermission = _getViewerPermissionLevel(hubId, targetViewerId, settings);
    return _permissionMeetsRequirement(viewerPermission, requiredLevel);
  }

  /// Get viewer's effective permission level
  PrivacyLevel _getViewerPermissionLevel(
    String hubId,
    String viewerId,
    ExtendedFamilyPrivacySettings settings,
  ) {
    // TODO: Check if viewer is core family member
    // For now, assume extended family member
    // Core family would have 'open' access regardless of settings
    return PrivacyLevel.moderate; // Placeholder
  }

  /// Check if permission level meets requirement
  bool _permissionMeetsRequirement(PrivacyLevel viewerLevel, PrivacyLevel requiredLevel) {
    // open >= moderate >= strict
    switch (requiredLevel) {
      case PrivacyLevel.open:
        return viewerLevel == PrivacyLevel.open;
      case PrivacyLevel.moderate:
        return viewerLevel == PrivacyLevel.open || viewerLevel == PrivacyLevel.moderate;
      case PrivacyLevel.strict:
        return true; // Everyone can see strict (core family only)
    }
  }
}


