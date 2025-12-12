import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/hub.dart';
import '../models/extended_family_hub_data.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'hub_service.dart';

/// Service for managing extended family hub-specific features
class ExtendedFamilyHubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HubService _hubService = HubService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Get extended family hub data for a hub
  Future<ExtendedFamilyHubData?> getExtendedFamilyData(String hubId) async {
    try {
      final hub = await _hubService.getHub(hubId);
      if (hub == null || !hub.isExtendedFamilyHub) {
        return null;
      }

      final typeData = hub.typeSpecificData;
      if (typeData == null) {
        // Return default data if none exists
        return ExtendedFamilyHubData();
      }

      return ExtendedFamilyHubData.fromJson(typeData);
    } catch (e, st) {
      Logger.error('Error getting extended family data', error: e, stackTrace: st, tag: 'ExtendedFamilyHubService');
      return null;
    }
  }

  /// Update extended family hub data
  Future<void> updateExtendedFamilyData(
    String hubId,
    ExtendedFamilyHubData data,
  ) async {
    final userId = currentUserId;
    if (userId == null) {
      throw AuthException('User not logged in', code: 'not-authenticated');
    }

    final hub = await _hubService.getHub(hubId);
    if (hub == null) {
      throw FirestoreException('Hub not found', code: 'not-found');
    }

    if (!hub.isExtendedFamilyHub) {
      throw ValidationException('Hub is not an extended family hub', code: 'invalid-hub-type');
    }

    if (hub.creatorId != userId) {
      throw PermissionException('Only the hub creator can update extended family data', code: 'insufficient-permissions');
    }

    try {
      await _hubService.updateHub(hubId, {
        'typeSpecificData': data.toJson(),
      });
    } catch (e, st) {
      Logger.error('Error updating extended family data', error: e, stackTrace: st, tag: 'ExtendedFamilyHubService');
      rethrow;
    }
  }

  /// Set relationship for an extended family member
  Future<void> setRelationship(
    String hubId,
    String memberId,
    RelationshipType relationship,
  ) async {
    final data = await getExtendedFamilyData(hubId) ?? ExtendedFamilyHubData();
    final updatedRelationships = Map<String, String>.from(data.relationships);
    updatedRelationships[memberId] = relationship.value;

    await updateExtendedFamilyData(
      hubId,
      data.copyWith(relationships: updatedRelationships),
    );
  }

  /// Set privacy level for an extended family member
  Future<void> setPrivacyLevel(
    String hubId,
    String memberId,
    PrivacyLevel privacyLevel,
  ) async {
    final data = await getExtendedFamilyData(hubId) ?? ExtendedFamilyHubData();
    final updatedPrivacy = Map<String, String>.from(data.privacySettings);
    updatedPrivacy[memberId] = privacyLevel.value;

    await updateExtendedFamilyData(
      hubId,
      data.copyWith(privacySettings: updatedPrivacy),
    );
  }

  /// Set role for an extended family member
  Future<void> setMemberRole(
    String hubId,
    String memberId,
    ExtendedFamilyRole role,
  ) async {
    final userId = currentUserId;
    if (userId == null) {
      throw AuthException('User not logged in', code: 'not-authenticated');
    }

    final hub = await _hubService.getHub(hubId);
    if (hub == null) {
      throw FirestoreException('Hub not found', code: 'not-found');
    }

    // Only creator or admin can set roles
    if (hub.creatorId != userId) {
      final data = await getExtendedFamilyData(hubId);
      final currentRole = data?.getRole(userId) ?? ExtendedFamilyRole.viewer;
      if (currentRole != ExtendedFamilyRole.admin) {
        throw PermissionException('Only admins can set member roles', code: 'insufficient-permissions');
      }
    }

    final data = await getExtendedFamilyData(hubId) ?? ExtendedFamilyHubData();
    final updatedRoles = Map<String, String>.from(data.memberRoles);
    updatedRoles[memberId] = role.value;

    await updateExtendedFamilyData(
      hubId,
      data.copyWith(memberRoles: updatedRoles),
    );
  }

  /// Invite an extended family member
  Future<void> inviteExtendedFamilyMember({
    required String hubId,
    required String email,
    RelationshipType? relationship,
    PrivacyLevel privacyLevel = PrivacyLevel.minimal,
    ExtendedFamilyRole role = ExtendedFamilyRole.viewer,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw AuthException('User not logged in', code: 'not-authenticated');
    }

    final hub = await _hubService.getHub(hubId);
    if (hub == null || !hub.isExtendedFamilyHub) {
      throw ValidationException('Hub is not an extended family hub', code: 'invalid-hub-type');
    }

    // Create hub invite
    final invite = await _hubService.createInvite(
      hubId: hubId,
      email: email,
    );

    // Add to invited members list
    final data = await getExtendedFamilyData(hubId) ?? ExtendedFamilyHubData();
    final updatedInvites = List<String>.from(data.invitedMemberIds);
    if (!updatedInvites.contains(invite.id)) {
      updatedInvites.add(invite.id);
    }

    // Store invite-specific data (will be applied when invite is accepted)
    // For now, we'll store it in a separate collection or in the invite itself
    await _firestore
        .collection(FirestorePathUtils.getCollectionPath('hubInvites'))
        .doc(invite.id)
        .update({
      'extendedFamilyData': {
        'relationship': relationship?.value,
        'privacyLevel': privacyLevel.value,
        'role': role.value,
      },
    });

    await updateExtendedFamilyData(
      hubId,
      data.copyWith(invitedMemberIds: updatedInvites),
    );
  }

  /// Get all extended family hubs for current user
  Future<List<Hub>> getExtendedFamilyHubs() async {
    final hubs = await _hubService.getUserHubs();
    return hubs.where((hub) => hub.isExtendedFamilyHub).toList();
  }

  /// Check if user has permission to view content in extended family hub
  Future<bool> canViewContent(String hubId, String contentType) async {
    final userId = currentUserId;
    if (userId == null) return false;

    final hub = await _hubService.getHub(hubId);
    if (hub == null || !hub.isExtendedFamilyHub) return false;

    // Creator always has access
    if (hub.creatorId == userId) return true;

    // Check if user is a member
    if (!hub.memberIds.contains(userId)) return false;

    final data = await getExtendedFamilyData(hubId);
    if (data == null) return false;

    final privacyLevel = data.getPrivacyLevel(userId);

    switch (contentType) {
      case 'events':
      case 'photos':
        return privacyLevel == PrivacyLevel.standard || privacyLevel == PrivacyLevel.full;
      case 'tasks':
      case 'messages':
        return privacyLevel == PrivacyLevel.full;
      default:
        return privacyLevel != PrivacyLevel.minimal;
    }
  }
}

