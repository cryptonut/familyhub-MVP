import 'package:cloud_firestore/cloud_firestore.dart';

/// Relationship types for extended family members
enum RelationshipType {
  grandparent,
  aunt,
  uncle,
  cousin,
  sibling, // For extended family context
  other,
}

extension RelationshipTypeExtension on RelationshipType {
  String get value {
    switch (this) {
      case RelationshipType.grandparent:
        return 'grandparent';
      case RelationshipType.aunt:
        return 'aunt';
      case RelationshipType.uncle:
        return 'uncle';
      case RelationshipType.cousin:
        return 'cousin';
      case RelationshipType.sibling:
        return 'sibling';
      case RelationshipType.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case RelationshipType.grandparent:
        return 'Grandparent';
      case RelationshipType.aunt:
        return 'Aunt';
      case RelationshipType.uncle:
        return 'Uncle';
      case RelationshipType.cousin:
        return 'Cousin';
      case RelationshipType.sibling:
        return 'Sibling';
      case RelationshipType.other:
        return 'Other';
    }
  }

  static RelationshipType fromString(String value) {
    switch (value) {
      case 'grandparent':
        return RelationshipType.grandparent;
      case 'aunt':
        return RelationshipType.aunt;
      case 'uncle':
        return RelationshipType.uncle;
      case 'cousin':
        return RelationshipType.cousin;
      case 'sibling':
        return RelationshipType.sibling;
      case 'other':
        return RelationshipType.other;
      default:
        return RelationshipType.other;
    }
  }
}

/// Privacy levels for extended family members
enum PrivacyLevel {
  minimal,    // Only basic info (name, birthday)
  standard,   // Events and photos (opt-in)
  full,       // Full access (like core family)
}

extension PrivacyLevelExtension on PrivacyLevel {
  String get value {
    switch (this) {
      case PrivacyLevel.minimal:
        return 'minimal';
      case PrivacyLevel.standard:
        return 'standard';
      case PrivacyLevel.full:
        return 'full';
    }
  }

  String get displayName {
    switch (this) {
      case PrivacyLevel.minimal:
        return 'Minimal';
      case PrivacyLevel.standard:
        return 'Standard';
      case PrivacyLevel.full:
        return 'Full';
    }
  }

  String get description {
    switch (this) {
      case PrivacyLevel.minimal:
        return 'Only basic information (name, birthday)';
      case PrivacyLevel.standard:
        return 'Events and photos (opt-in sharing)';
      case PrivacyLevel.full:
        return 'Full access (like core family)';
    }
  }

  static PrivacyLevel fromString(String value) {
    switch (value) {
      case 'minimal':
        return PrivacyLevel.minimal;
      case 'standard':
        return PrivacyLevel.standard;
      case 'full':
        return PrivacyLevel.full;
      default:
        return PrivacyLevel.minimal;
    }
  }
}

/// Roles for extended family members
enum ExtendedFamilyRole {
  viewer,      // View-only access
  contributor, // Can add events, photos
  admin,       // Full management
}

extension ExtendedFamilyRoleExtension on ExtendedFamilyRole {
  String get value {
    switch (this) {
      case ExtendedFamilyRole.viewer:
        return 'viewer';
      case ExtendedFamilyRole.contributor:
        return 'contributor';
      case ExtendedFamilyRole.admin:
        return 'admin';
    }
  }

  String get displayName {
    switch (this) {
      case ExtendedFamilyRole.viewer:
        return 'Viewer';
      case ExtendedFamilyRole.contributor:
        return 'Contributor';
      case ExtendedFamilyRole.admin:
        return 'Admin';
    }
  }

  String get description {
    switch (this) {
      case ExtendedFamilyRole.viewer:
        return 'View-only access to hub content';
      case ExtendedFamilyRole.contributor:
        return 'Can add events, photos, and messages';
      case ExtendedFamilyRole.admin:
        return 'Full management access';
    }
  }

  static ExtendedFamilyRole fromString(String value) {
    switch (value) {
      case 'viewer':
        return ExtendedFamilyRole.viewer;
      case 'contributor':
        return ExtendedFamilyRole.contributor;
      case 'admin':
        return ExtendedFamilyRole.admin;
      default:
        return ExtendedFamilyRole.viewer;
    }
  }
}

/// Extended family hub-specific data
class ExtendedFamilyHubData {
  final Map<String, String> relationships; // userId -> relationshipType
  final Map<String, String> privacySettings; // userId -> privacyLevel
  final Map<String, String> memberRoles; // userId -> role
  final List<String> invitedMemberIds; // Pending invitations
  final String? customRelationshipNote; // Optional note about relationships

  ExtendedFamilyHubData({
    Map<String, String>? relationships,
    Map<String, String>? privacySettings,
    Map<String, String>? memberRoles,
    List<String>? invitedMemberIds,
    this.customRelationshipNote,
  })  : relationships = relationships ?? {},
        privacySettings = privacySettings ?? {},
        memberRoles = memberRoles ?? {},
        invitedMemberIds = invitedMemberIds ?? [];

  Map<String, dynamic> toJson() {
    return {
      'relationships': relationships,
      'privacySettings': privacySettings,
      'memberRoles': memberRoles,
      'invitedMemberIds': invitedMemberIds,
      'customRelationshipNote': customRelationshipNote,
    };
  }

  factory ExtendedFamilyHubData.fromJson(Map<String, dynamic> json) {
    return ExtendedFamilyHubData(
      relationships: json['relationships'] != null
          ? Map<String, String>.from(json['relationships'] as Map)
          : null,
      privacySettings: json['privacySettings'] != null
          ? Map<String, String>.from(json['privacySettings'] as Map)
          : null,
      memberRoles: json['memberRoles'] != null
          ? Map<String, String>.from(json['memberRoles'] as Map)
          : null,
      invitedMemberIds: json['invitedMemberIds'] != null
          ? List<String>.from(json['invitedMemberIds'] as List)
          : null,
      customRelationshipNote: json['customRelationshipNote'] as String?,
    );
  }

  ExtendedFamilyHubData copyWith({
    Map<String, String>? relationships,
    Map<String, String>? privacySettings,
    Map<String, String>? memberRoles,
    List<String>? invitedMemberIds,
    String? customRelationshipNote,
  }) {
    return ExtendedFamilyHubData(
      relationships: relationships ?? this.relationships,
      privacySettings: privacySettings ?? this.privacySettings,
      memberRoles: memberRoles ?? this.memberRoles,
      invitedMemberIds: invitedMemberIds ?? this.invitedMemberIds,
      customRelationshipNote: customRelationshipNote ?? this.customRelationshipNote,
    );
  }

  /// Get relationship for a user
  RelationshipType? getRelationship(String userId) {
    final rel = relationships[userId];
    return rel != null ? RelationshipTypeExtension.fromString(rel) : null;
  }

  /// Get privacy level for a user
  PrivacyLevel getPrivacyLevel(String userId) {
    final privacy = privacySettings[userId];
    return privacy != null
        ? PrivacyLevelExtension.fromString(privacy)
        : PrivacyLevel.minimal; // Default to minimal
  }

  /// Get role for a user
  ExtendedFamilyRole getRole(String userId) {
    final role = memberRoles[userId];
    return role != null
        ? ExtendedFamilyRoleExtension.fromString(role)
        : ExtendedFamilyRole.viewer; // Default to viewer
  }
}

