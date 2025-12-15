import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/extended_family_relationship.dart';
import '../models/hub.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'hub_service.dart';
import 'subscription_service.dart';

/// Service for managing extended family hub features
class ExtendedFamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final HubService _hubService = HubService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final Uuid _uuid = const Uuid();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Add extended family member with relationship
  Future<void> addExtendedFamilyMember({
    required String hubId,
    required String userId,
    required ExtendedFamilyRelationship relationship,
    String? customRelationshipName,
    ExtendedFamilyPermission permission = ExtendedFamilyPermission.viewOnly,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    // Verify hub is extended family type
    final hub = await _hubService.getHub(hubId);
    if (hub == null) {
      throw NotFoundException('Hub not found', code: 'hub-not-found');
    }

    if (hub.hubType != HubType.extendedFamily) {
      throw ValidationException('Hub must be extended family type', code: 'invalid-hub-type');
    }

    // Verify user has premium access
    final hasAccess = await _subscriptionService.hasPremiumHubAccess('extended_family');
    if (!hasAccess) {
      throw PermissionException(
        'Premium subscription required for extended family hubs',
        code: 'premium-required',
      );
    }

    try {
      // Add member to hub
      await _hubService.addMember(hubId, userId);

      // Store relationship data
      final relationshipData = ExtendedFamilyMember(
        userId: userId,
        hubId: hubId,
        relationship: relationship,
        customRelationshipName: customRelationshipName,
        permission: permission,
        addedAt: DateTime.now(),
        addedBy: currentUserId,
      );

      await _firestore
          .collection(FirestorePathUtils.getCollectionPath('extended_family_relationships'))
          .add(relationshipData.toJson());

      Logger.info('Extended family member added: $userId to hub $hubId', tag: 'ExtendedFamilyService');
    } catch (e) {
      Logger.error('Error adding extended family member', error: e, tag: 'ExtendedFamilyService');
      rethrow;
    }
  }

  /// Get relationship for a member in a hub
  Future<ExtendedFamilyMember?> getRelationship({
    required String hubId,
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('extended_family_relationships'))
          .where('hubId', isEqualTo: hubId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return ExtendedFamilyMember.fromJson({
        'id': snapshot.docs.first.id,
        ...snapshot.docs.first.data(),
      });
    } catch (e) {
      Logger.error('Error getting relationship', error: e, tag: 'ExtendedFamilyService');
      return null;
    }
  }

  /// Get all relationships for a hub
  Future<List<ExtendedFamilyMember>> getHubRelationships(String hubId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('extended_family_relationships'))
          .where('hubId', isEqualTo: hubId)
          .get();

      return snapshot.docs
          .map((doc) => ExtendedFamilyMember.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      Logger.error('Error getting hub relationships', error: e, tag: 'ExtendedFamilyService');
      return [];
    }
  }

  /// Update relationship
  Future<void> updateRelationship({
    required String relationshipId,
    ExtendedFamilyRelationship? relationship,
    String? customRelationshipName,
    ExtendedFamilyPermission? permission,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final updates = <String, dynamic>{};
      if (relationship != null) {
        updates['relationship'] = relationship.value;
      }
      if (customRelationshipName != null) {
        updates['customRelationshipName'] = customRelationshipName;
      }
      if (permission != null) {
        updates['permission'] = permission.name;
      }

      await _firestore
          .collection(FirestorePathUtils.getCollectionPath('extended_family_relationships'))
          .doc(relationshipId)
          .update(updates);

      Logger.info('Relationship updated: $relationshipId', tag: 'ExtendedFamilyService');
    } catch (e) {
      Logger.error('Error updating relationship', error: e, tag: 'ExtendedFamilyService');
      rethrow;
    }
  }

  /// Remove extended family member
  Future<void> removeExtendedFamilyMember({
    required String hubId,
    required String userId,
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      // Remove from hub
      await _hubService.removeMember(hubId, userId);

      // Remove relationship data
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('extended_family_relationships'))
          .where('hubId', isEqualTo: hubId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      Logger.info('Extended family member removed: $userId from hub $hubId', tag: 'ExtendedFamilyService');
    } catch (e) {
      Logger.error('Error removing extended family member', error: e, tag: 'ExtendedFamilyService');
      rethrow;
    }
  }
}


