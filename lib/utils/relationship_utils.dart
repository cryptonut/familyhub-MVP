import '../models/user_model.dart';

/// Utility class for calculating family relationships
class RelationshipUtils {
  /// Get the relationship from a specific user's perspective
  /// 
  /// [viewer] - The user viewing the relationship
  /// [target] - The user whose relationship is being viewed
  /// [creator] - The family creator (relationships are stored from their perspective)
  /// [allMembers] - All family members (needed to calculate sibling relationships)
  static String? getRelationshipFromPerspective({
    required UserModel viewer,
    required UserModel target,
    required UserModel? creator,
    required List<UserModel> allMembers,
  }) {
    // If no creator, return null
    if (creator == null) {
      return null;
    }
    
    // If viewer is the creator, return the stored relationship (if target has one)
    if (viewer.uid == creator.uid) {
      return target.relationship;
    }
    
    // If viewing self, return null (no relationship to self)
    if (viewer.uid == target.uid) {
      return null;
    }
    
    // Special case: if target is the creator, calculate reciprocal from viewer's relationship
    if (target.uid == creator.uid) {
      final viewerRelationship = viewer.relationship;
      if (viewerRelationship == null) {
        return null;
      }
      
      // Calculate what the viewer sees the creator as, based on viewer's relationship
      // If viewer is "wife" (from creator's perspective), they see creator as "husband"
      // If viewer is "husband" (from creator's perspective), they see creator as "wife"
      // If viewer is "son", they see creator as "father" or "mother" (need creator's relationship)
      // If viewer is "daughter", they see creator as "father" or "mother" (need creator's relationship)
      switch (viewerRelationship.toLowerCase()) {
        case 'wife':
          return 'husband';
        case 'husband':
          return 'wife';
        case 'son':
        case 'daughter':
          // Need to know creator's relationship to determine if they're father or mother
          final creatorRelationship = creator.relationship;
          if (creatorRelationship == 'father') {
            return 'father';
          } else if (creatorRelationship == 'mother') {
            return 'mother';
          }
          // If creator's relationship is unknown, infer from family structure
          // Check if there's a "wife" in the family (creator is likely "husband"/"father")
          // or a "husband" in the family (creator is likely "wife"/"mother")
          final hasWife = allMembers.any((m) => 
            m.uid != creator.uid && 
            m.relationship?.toLowerCase() == 'wife'
          );
          final hasHusband = allMembers.any((m) => 
            m.uid != creator.uid && 
            m.relationship?.toLowerCase() == 'husband'
          );
          
          if (hasWife) {
            // Creator is likely "husband" (father)
            return 'father';
          } else if (hasHusband) {
            // Creator is likely "wife" (mother)
            return 'mother';
          }
          // Fallback: if we can't infer, return null
          return null;
        default:
          // For other relationships, we can't determine the reciprocal without more context
          return null;
      }
    }
    
    // If target has no relationship defined, return null
    if (target.relationship == null) {
      return null;
    }
    
    final creatorRelationship = creator.relationship;
    final targetRelationship = target.relationship;
    final viewerRelationship = viewer.relationship;
    
    // If viewer has no relationship defined, we can't calculate
    if (viewerRelationship == null) {
      return null;
    }
    
    // If creator has no relationship set, infer it from family structure
    if (creatorRelationship == null || creatorRelationship.isEmpty) {
      return _calculateWhenCreatorHasNoRelationship(
        viewerRelationship: viewerRelationship,
        targetRelationship: targetRelationship,
        viewer: viewer,
        target: target,
        allMembers: allMembers,
      );
    }
    
    // Calculate relationship based on creator's perspective
    // Creator is "father"
    if (creatorRelationship == 'father') {
      return _calculateFromFatherPerspective(
        viewerRelationship: viewerRelationship,
        targetRelationship: targetRelationship,
        viewer: viewer,
        target: target,
        allMembers: allMembers,
      );
    }
    
    // Creator is "mother"
    if (creatorRelationship == 'mother') {
      return _calculateFromMotherPerspective(
        viewerRelationship: viewerRelationship,
        targetRelationship: targetRelationship,
        viewer: viewer,
        target: target,
        allMembers: allMembers,
      );
    }
    
    // For other creator relationships, we can extend this logic
    // For now, return the stored relationship as fallback
    return targetRelationship;
  }
  
  /// Calculate relationship when creator has no relationship set
  /// Infers relationships based on viewer and target relationships
  static String? _calculateWhenCreatorHasNoRelationship({
    required String viewerRelationship,
    required String? targetRelationship,
    required UserModel viewer,
    required UserModel target,
    required List<UserModel> allMembers,
  }) {
    if (targetRelationship == null) return null;
    
    final viewerRel = viewerRelationship.toLowerCase();
    final targetRel = targetRelationship.toLowerCase();
    
    // If viewer is "wife" (mother), calculate from mother's perspective
    if (viewerRel == 'wife') {
      switch (targetRel) {
        case 'husband':
          return 'husband'; // Wife sees husband as husband (but this is the creator, handled above)
        case 'daughter':
          return 'daughter'; // Wife (mother) sees daughter as daughter
        case 'son':
          return 'son'; // Wife (mother) sees son as son
        case 'wife':
          // Another wife? Could be polygamy or error, but return as-is
          return targetRel;
        default:
          return targetRel;
      }
    }
    
    // If viewer is "husband" (father), calculate from father's perspective
    if (viewerRel == 'husband') {
      switch (targetRel) {
        case 'wife':
          return 'wife'; // Husband sees wife as wife (but this is the creator, handled above)
        case 'daughter':
          return 'daughter'; // Husband (father) sees daughter as daughter
        case 'son':
          return 'son'; // Husband (father) sees son as son
        case 'husband':
          // Another husband? Could be polygamy or error, but return as-is
          return targetRel;
        default:
          return targetRel;
      }
    }
    
    // If viewer is "daughter", calculate from daughter's perspective
    if (viewerRel == 'daughter') {
      switch (targetRel) {
        case 'wife':
          return 'mother'; // Daughter sees wife (mother) as mother
        case 'husband':
          return 'father'; // Daughter sees husband (father) as father
        case 'daughter':
          // Check if same person
          if (viewer.uid == target.uid) return null;
          // Otherwise, it's a sister
          return 'sister';
        case 'son':
          return 'brother'; // Daughter sees son (brother) as brother
        default:
          return targetRel;
      }
    }
    
    // If viewer is "son", calculate from son's perspective
    if (viewerRel == 'son') {
      switch (targetRel) {
        case 'wife':
          return 'mother'; // Son sees wife (mother) as mother
        case 'husband':
          return 'father'; // Son sees husband (father) as father
        case 'daughter':
          return 'sister'; // Son sees daughter (sister) as sister
        case 'son':
          // Check if same person
          if (viewer.uid == target.uid) return null;
          // Otherwise, it's a brother
          return 'brother';
        default:
          return targetRel;
      }
    }
    
    // For other relationships, return the stored relationship as fallback
    return targetRelationship;
  }
  
  /// Calculate relationship when creator is "father"
  static String? _calculateFromFatherPerspective({
    required String viewerRelationship,
    required String? targetRelationship,
    required UserModel viewer,
    required UserModel target,
    required List<UserModel> allMembers,
  }) {
    if (targetRelationship == null) return null;
    
    // If viewer is the creator (father), return stored relationship
    if (viewerRelationship == 'father') {
      return targetRelationship;
    }
    
    // If viewer is mother
    if (viewerRelationship == 'mother') {
      switch (targetRelationship) {
        case 'father':
          return 'husband';
        case 'mother':
          return null; // Self
        case 'daughter':
        case 'son':
          return targetRelationship; // Daughter/son to mother
        default:
          return targetRelationship;
      }
    }
    
    // If viewer is daughter
    if (viewerRelationship == 'daughter') {
      switch (targetRelationship) {
        case 'father':
          return 'father';
        case 'mother':
          return 'mother';
        case 'daughter':
          // Check if same person
          if (viewer.uid == target.uid) return null;
          // Otherwise, it's a sister
          return 'sister';
        case 'son':
          return 'brother';
        default:
          return targetRelationship;
      }
    }
    
    // If viewer is son
    if (viewerRelationship == 'son') {
      switch (targetRelationship) {
        case 'father':
          return 'father';
        case 'mother':
          return 'mother';
        case 'daughter':
          return 'sister';
        case 'son':
          // Check if same person
          if (viewer.uid == target.uid) return null;
          // Otherwise, it's a brother
          return 'brother';
        default:
          return targetRelationship;
      }
    }
    
    return targetRelationship;
  }
  
  /// Calculate relationship when creator is "mother"
  static String? _calculateFromMotherPerspective({
    required String viewerRelationship,
    required String? targetRelationship,
    required UserModel viewer,
    required UserModel target,
    required List<UserModel> allMembers,
  }) {
    if (targetRelationship == null) return null;
    
    // If viewer is the creator (mother), return stored relationship
    if (viewerRelationship == 'mother') {
      return targetRelationship;
    }
    
    // If viewer is father
    if (viewerRelationship == 'father') {
      switch (targetRelationship) {
        case 'mother':
          return 'wife';
        case 'father':
          return null; // Self
        case 'daughter':
        case 'son':
          return targetRelationship; // Daughter/son to father
        default:
          return targetRelationship;
      }
    }
    
    // If viewer is daughter
    if (viewerRelationship == 'daughter') {
      switch (targetRelationship) {
        case 'father':
          return 'father';
        case 'mother':
          return 'mother';
        case 'daughter':
          // Check if same person
          if (viewer.uid == target.uid) return null;
          // Otherwise, it's a sister
          return 'sister';
        case 'son':
          return 'brother';
        default:
          return targetRelationship;
      }
    }
    
    // If viewer is son
    if (viewerRelationship == 'son') {
      switch (targetRelationship) {
        case 'father':
          return 'father';
        case 'mother':
          return 'mother';
        case 'daughter':
          return 'sister';
        case 'son':
          // Check if same person
          if (viewer.uid == target.uid) return null;
          // Otherwise, it's a brother
          return 'brother';
        default:
          return targetRelationship;
      }
    }
    
    return targetRelationship;
  }
  
  /// Get a human-readable label for a relationship
  static String getRelationshipLabel(String? relationship) {
    if (relationship == null) return '';
    
    switch (relationship.toLowerCase()) {
      case 'father':
        return 'Father';
      case 'mother':
        return 'Mother';
      case 'daughter':
        return 'Daughter';
      case 'son':
        return 'Son';
      case 'husband':
        return 'Husband';
      case 'wife':
        return 'Wife';
      case 'sister':
        return 'Sister';
      case 'brother':
        return 'Brother';
      default:
        return relationship;
    }
  }
  
  /// Get available relationship options (from creator's perspective)
  static List<String> getAvailableRelationships() {
    return [
      'father',
      'mother',
      'daughter',
      'son',
      'husband',
      'wife',
      'brother',
      'sister',
      'grandfather',
      'grandmother',
      'granddaughter',
      'grandson',
      'uncle',
      'aunt',
      'cousin',
      'other',
    ];
  }

  /// Get the reciprocal relationship that should be stored on the other person's record.
  /// 
  /// When setting a relationship from person A to person B, this returns what
  /// relationship should be stored on person A's record (from creator's perspective)
  /// so that person B will see the correct reciprocal when viewing person A.
  /// 
  /// For example:
  /// - If creator sets person B as "wife", person B's relationship is "wife".
  ///   When person B views creator, they see "husband" (calculated).
  ///   So no reciprocal needs to be stored on creator (creator has no relationship field).
  /// 
  /// - If person A (non-creator with relationship "husband") sets person B as "wife",
  ///   person B's relationship is "wife" (from creator's perspective).
  ///   When person B views person A, they should see "husband".
  ///   This is already calculated correctly by getRelationshipFromPerspective.
  /// 
  /// However, for symmetric relationships like siblings, we can set both sides.
  /// 
  /// Returns null if no reciprocal needs to be stored (it's calculated on-the-fly).
  static String? getReciprocalRelationshipToStore({
    required String relationshipBeingSet, // Relationship being set (from creator's perspective)
    required String? setterRelationship, // Person setting it (from creator's perspective)
    required bool isCreator, // Whether the setter is the creator
  }) {
    if (relationshipBeingSet.isEmpty) return null;
    
    final rel = relationshipBeingSet.toLowerCase();
    
    // For symmetric relationships, we can set both sides
    if (rel == 'brother' || rel == 'sister') {
      // If setting someone as brother/sister, and we're not the creator,
      // we could set ourselves as their sibling too, but this is already
      // calculated correctly by getRelationshipFromPerspective.
      // Actually, siblings are symmetric, so if A is B's brother, B is A's brother/sister.
      // But this is already handled by the calculation system.
      return null; // Already handled by calculation
    }
    
    // For wife/husband: these are already handled by getRelationshipFromPerspective
    // The calculation system already handles the reciprocal correctly.
    return null;
  }
  
  /// Get the relationship that person A should have (from creator's perspective)
  /// so that when person B views person A, they see the reciprocal of the relationship
  /// being set from person A to person B.
  /// 
  /// This is a helper for automatic reciprocal relationship setting.
  /// 
  /// Example: If I (creator) set Kate as "wife", Kate's relationship is "wife".
  /// When Kate views me, she sees "husband" (calculated). No need to store anything on me.
  /// 
  /// Example: If I (non-creator, relationship "husband") set Kate as "wife",
  /// Kate's relationship is "wife". When Kate views me, she sees "husband" (calculated).
  /// No need to store anything on me because my relationship "husband" already makes this work.
  /// 
  /// This method helps determine if we need to update the setter's relationship
  /// to make the reciprocal work correctly.
  static String? getRequiredSetterRelationship({
    required String relationshipBeingSet, // What we're setting (from creator's perspective)
    required String? currentSetterRelationship, // Setter's current relationship
    required bool isCreator, // Whether setter is creator
  }) {
    if (relationshipBeingSet.isEmpty) return null;
    if (isCreator) return null; // Creator has no relationship field
    
    final rel = relationshipBeingSet.toLowerCase();
    
    // For wife/husband relationships:
    // If setting someone as "wife", the setter should be "husband" (from creator's perspective)
    // If setting someone as "husband", the setter should be "wife" (from creator's perspective)
    if (rel == 'wife') {
      return 'husband';
    }
    if (rel == 'husband') {
      return 'wife';
    }
    
    // For parent/child: if setting someone as "son", setter should be "father" or "mother"
    // But we can't determine which without more context, so we don't auto-set this.
    
    return null; // No auto-setting needed
  }
}

