/// Relationship types for extended family members
enum ExtendedFamilyRelationship {
  grandparent,
  grandparentInLaw,
  aunt,
  uncle,
  auntInLaw,
  uncleInLaw,
  cousin,
  cousinInLaw,
  nephew,
  niece,
  siblingInLaw,
  other,
}

extension ExtendedFamilyRelationshipExtension on ExtendedFamilyRelationship {
  String get displayName {
    switch (this) {
      case ExtendedFamilyRelationship.grandparent:
        return 'Grandparent';
      case ExtendedFamilyRelationship.grandparentInLaw:
        return 'Grandparent (In-Law)';
      case ExtendedFamilyRelationship.aunt:
        return 'Aunt';
      case ExtendedFamilyRelationship.uncle:
        return 'Uncle';
      case ExtendedFamilyRelationship.auntInLaw:
        return 'Aunt (In-Law)';
      case ExtendedFamilyRelationship.uncleInLaw:
        return 'Uncle (In-Law)';
      case ExtendedFamilyRelationship.cousin:
        return 'Cousin';
      case ExtendedFamilyRelationship.cousinInLaw:
        return 'Cousin (In-Law)';
      case ExtendedFamilyRelationship.nephew:
        return 'Nephew';
      case ExtendedFamilyRelationship.niece:
        return 'Niece';
      case ExtendedFamilyRelationship.siblingInLaw:
        return 'Sibling (In-Law)';
      case ExtendedFamilyRelationship.other:
        return 'Other';
    }
  }

  String get value {
    switch (this) {
      case ExtendedFamilyRelationship.grandparent:
        return 'grandparent';
      case ExtendedFamilyRelationship.grandparentInLaw:
        return 'grandparent_in_law';
      case ExtendedFamilyRelationship.aunt:
        return 'aunt';
      case ExtendedFamilyRelationship.uncle:
        return 'uncle';
      case ExtendedFamilyRelationship.auntInLaw:
        return 'aunt_in_law';
      case ExtendedFamilyRelationship.uncleInLaw:
        return 'uncle_in_law';
      case ExtendedFamilyRelationship.cousin:
        return 'cousin';
      case ExtendedFamilyRelationship.cousinInLaw:
        return 'cousin_in_law';
      case ExtendedFamilyRelationship.nephew:
        return 'nephew';
      case ExtendedFamilyRelationship.niece:
        return 'niece';
      case ExtendedFamilyRelationship.siblingInLaw:
        return 'sibling_in_law';
      case ExtendedFamilyRelationship.other:
        return 'other';
    }
  }

  static ExtendedFamilyRelationship fromString(String value) {
    switch (value) {
      case 'grandparent':
        return ExtendedFamilyRelationship.grandparent;
      case 'grandparent_in_law':
        return ExtendedFamilyRelationship.grandparentInLaw;
      case 'aunt':
        return ExtendedFamilyRelationship.aunt;
      case 'uncle':
        return ExtendedFamilyRelationship.uncle;
      case 'aunt_in_law':
        return ExtendedFamilyRelationship.auntInLaw;
      case 'uncle_in_law':
        return ExtendedFamilyRelationship.uncleInLaw;
      case 'cousin':
        return ExtendedFamilyRelationship.cousin;
      case 'cousin_in_law':
        return ExtendedFamilyRelationship.cousinInLaw;
      case 'nephew':
        return ExtendedFamilyRelationship.nephew;
      case 'niece':
        return ExtendedFamilyRelationship.niece;
      case 'sibling_in_law':
        return ExtendedFamilyRelationship.siblingInLaw;
      default:
        return ExtendedFamilyRelationship.other;
    }
  }
}

/// Extended family member relationship data
class ExtendedFamilyMember {
  final String userId;
  final String hubId;
  final ExtendedFamilyRelationship relationship;
  final String? customRelationshipName; // For "other" relationship
  final ExtendedFamilyPermission permission;
  final DateTime addedAt;
  final String addedBy;

  ExtendedFamilyMember({
    required this.userId,
    required this.hubId,
    required this.relationship,
    this.customRelationshipName,
    required this.permission,
    required this.addedAt,
    required this.addedBy,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'hubId': hubId,
        'relationship': relationship.value,
        if (customRelationshipName != null) 'customRelationshipName': customRelationshipName,
        'permission': permission.name,
        'addedAt': addedAt.toIso8601String(),
        'addedBy': addedBy,
      };

  factory ExtendedFamilyMember.fromJson(Map<String, dynamic> json) => ExtendedFamilyMember(
        userId: json['userId'] as String,
        hubId: json['hubId'] as String,
        relationship: ExtendedFamilyRelationshipExtension.fromString(json['relationship'] as String),
        customRelationshipName: json['customRelationshipName'] as String?,
        permission: ExtendedFamilyPermission.values.firstWhere(
          (e) => e.name == json['permission'],
          orElse: () => ExtendedFamilyPermission.viewOnly,
        ),
        addedAt: DateTime.parse(json['addedAt'] as String),
        addedBy: json['addedBy'] as String,
      );
}

/// Permission levels for extended family members
enum ExtendedFamilyPermission {
  viewOnly,      // Can only view (read-only)
  limitedEdit,   // Can view and edit some things (events, photos)
  fullAccess,    // Can view and edit most things (except admin functions)
}

extension ExtendedFamilyPermissionExtension on ExtendedFamilyPermission {
  String get displayName {
    switch (this) {
      case ExtendedFamilyPermission.viewOnly:
        return 'View Only';
      case ExtendedFamilyPermission.limitedEdit:
        return 'Limited Edit';
      case ExtendedFamilyPermission.fullAccess:
        return 'Full Access';
    }
  }

  String get description {
    switch (this) {
      case ExtendedFamilyPermission.viewOnly:
        return 'Can view events, photos, and messages only';
      case ExtendedFamilyPermission.limitedEdit:
        return 'Can view and add events, photos, and messages';
      case ExtendedFamilyPermission.fullAccess:
        return 'Can view and edit most content (except admin functions)';
    }
  }
}


