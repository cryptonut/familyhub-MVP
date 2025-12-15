import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/hub.dart';
import '../models/hub_invite.dart';
import 'auth_service.dart';
import 'subscription_service.dart';
import '../utils/firestore_path_utils.dart';

class HubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final SubscriptionService _subscriptionService = SubscriptionService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Get all hubs for the current user
  /// Queries both prefixed and unprefixed collections to find all hubs (including old ones)
  Future<List<Hub>> getUserHubs() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final allHubs = <String, Hub>{};
      final prefixedPath = FirestorePathUtils.getCollectionPath('hubs');
      final unprefixedPath = 'hubs';
      
      // Query prefixed collection (new hubs)
      try {
        // Get hubs where user is creator
        final prefixedCreatedSnapshot = await _firestore
            .collection(prefixedPath)
            .where('creatorId', isEqualTo: userId)
            .get();

        for (var doc in prefixedCreatedSnapshot.docs) {
          try {
            final hub = Hub.fromJson({'id': doc.id, ...doc.data()});
            allHubs[hub.id] = hub;
          } catch (e) {
            Logger.warning('Error parsing prefixed hub ${doc.id}', error: e, tag: 'HubService');
          }
        }

        // Get hubs where user is a member
        final prefixedMemberSnapshot = await _firestore
            .collection(prefixedPath)
            .where('memberIds', arrayContains: userId)
            .get();

        for (var doc in prefixedMemberSnapshot.docs) {
          try {
            final hub = Hub.fromJson({'id': doc.id, ...doc.data()});
            allHubs[hub.id] = hub;
          } catch (e) {
            Logger.warning('Error parsing prefixed hub ${doc.id}', error: e, tag: 'HubService');
          }
        }
      } catch (e) {
        Logger.warning('Error querying prefixed hubs collection', error: e, tag: 'HubService');
      }

      // Query unprefixed collection (old hubs) - only if prefixed path is different
      if (prefixedPath != unprefixedPath) {
        try {
          // Get hubs where user is creator
          final unprefixedCreatedSnapshot = await _firestore
              .collection(unprefixedPath)
              .where('creatorId', isEqualTo: userId)
              .get();

          for (var doc in unprefixedCreatedSnapshot.docs) {
            try {
              final hub = Hub.fromJson({'id': doc.id, ...doc.data()});
              allHubs[hub.id] = hub; // Will overwrite if duplicate, but that's OK
            } catch (e) {
              Logger.warning('Error parsing unprefixed hub ${doc.id}', error: e, tag: 'HubService');
            }
          }

          // Get hubs where user is a member
          final unprefixedMemberSnapshot = await _firestore
              .collection(unprefixedPath)
              .where('memberIds', arrayContains: userId)
              .get();

          for (var doc in unprefixedMemberSnapshot.docs) {
            try {
              final hub = Hub.fromJson({'id': doc.id, ...doc.data()});
              allHubs[hub.id] = hub; // Will overwrite if duplicate, but that's OK
            } catch (e) {
              Logger.warning('Error parsing unprefixed hub ${doc.id}', error: e, tag: 'HubService');
            }
          }
        } catch (e) {
          Logger.warning('Error querying unprefixed hubs collection', error: e, tag: 'HubService');
        }
      }

      return allHubs.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      Logger.error('Error getting user hubs', error: e, tag: 'HubService');
      return [];
    }
  }

  /// Get a specific hub by ID
  /// Checks both prefixed and unprefixed collections to find the hub
  Future<Hub?> getHub(String hubId) async {
    try {
      final prefixedPath = FirestorePathUtils.getCollectionPath('hubs');
      
      // Try prefixed collection first
      var doc = await _firestore
          .collection(prefixedPath)
          .doc(hubId)
          .get();
      
      if (doc.exists) {
        return Hub.fromJson({'id': doc.id, ...doc.data()!});
      }
      
      // If not found and prefixed path is different, try unprefixed collection
      final unprefixedPath = 'hubs';
      if (prefixedPath != unprefixedPath) {
        doc = await _firestore
            .collection(unprefixedPath)
            .doc(hubId)
            .get();
        
        if (doc.exists) {
          return Hub.fromJson({'id': doc.id, ...doc.data()!});
        }
      }
      
      return null;
    } catch (e) {
      Logger.error('Error getting hub', error: e, tag: 'HubService');
      return null;
    }
  }

  /// Create a new hub
  /// 
  /// Validates premium hub access if hubType is premium (extended_family, homeschooling, coparenting)
  Future<Hub> createHub({
    required String name,
    required String description,
    String? icon,
    HubType hubType = HubType.family,
    Map<String, dynamic>? typeSpecificData,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw AuthException('User not logged in', code: 'not-authenticated');

    // Validate premium hub access
    if (hubType != HubType.family) {
      final hasAccess = await _subscriptionService.hasPremiumHubAccess(hubType.value);
      if (!hasAccess) {
        throw PermissionException(
          'Premium hub access required. Please upgrade your subscription.',
          code: 'premium-required',
        );
      }
    }

    final hub = Hub(
      id: const Uuid().v4(),
      name: name,
      description: description,
      creatorId: userId,
      memberIds: [userId], // Creator is automatically a member
      createdAt: DateTime.now(),
      icon: icon,
      hubType: hubType,
      typeSpecificData: typeSpecificData,
    );

    try {
      final data = hub.toJson();
      data.remove('id');
      await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubs'))
          .doc(hub.id)
          .set(data);
      return hub;
    } catch (e) {
      Logger.error('Error creating hub', error: e, tag: 'HubService');
      rethrow;
    }
  }

  /// Ensure "My Friends" hub exists for the current user
  Future<Hub> ensureMyFriendsHub() async {
    final userId = currentUserId;
    if (userId == null) throw AuthException('User not logged in', code: 'not-authenticated');

    // Check if "My Friends" hub already exists
    final existingHubs = await getUserHubs();
    final myFriendsHub = existingHubs.firstWhere(
      (hub) => hub.name == 'My Friends' && hub.creatorId == userId,
      orElse: () => Hub(
        id: '',
        name: '',
        description: '',
        creatorId: '',
        createdAt: DateTime.now(),
      ),
    );

    if (myFriendsHub.id.isNotEmpty) {
      return myFriendsHub;
    }

    // Create "My Friends" hub if it doesn't exist
    return await createHub(
      name: 'My Friends',
      description: 'Your personal friends hub',
      icon: 'people',
    );
  }

  /// Add a member to a hub
  Future<void> addMember(String hubId, String userId) async {
    try {
      final hub = await getHub(hubId);
      if (hub == null) throw FirestoreException('Hub not found', code: 'not-found');

      if (hub.memberIds.contains(userId)) {
        return; // Already a member
      }

      await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubs'))
          .doc(hubId)
          .update({
        'memberIds': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      Logger.error('Error adding member to hub', error: e, tag: 'HubService');
      rethrow;
    }
  }

  /// Remove a member from a hub
  Future<void> removeMember(String hubId, String userId) async {
    try {
      await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubs'))
          .doc(hubId)
          .update({
        'memberIds': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      Logger.error('Error removing member from hub', error: e, tag: 'HubService');
      rethrow;
    }
  }

  /// Update hub settings
  Future<void> updateHub(String hubId, Map<String, dynamic> updates) async {
    final userId = currentUserId;
    if (userId == null) throw AuthException('User not logged in', code: 'not-authenticated');

    final hub = await getHub(hubId);
    if (hub == null) throw FirestoreException('Hub not found', code: 'not-found');
    if (hub.creatorId != userId) {
      throw PermissionException('Only the hub creator can update the hub', code: 'insufficient-permissions');
    }

    try {
      await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubs'))
          .doc(hubId)
          .update(updates);
    } catch (e) {
      Logger.error('Error updating hub', error: e, tag: 'HubService');
      rethrow;
    }
  }

  /// Transfer hub ownership to another member
  Future<void> transferOwnership(String hubId, String newOwnerId) async {
    final userId = currentUserId;
    if (userId == null) throw AuthException('User not logged in', code: 'not-authenticated');

    final hub = await getHub(hubId);
    if (hub == null) throw FirestoreException('Hub not found', code: 'not-found');
    if (hub.creatorId != userId) {
      throw PermissionException('Only the hub creator can transfer ownership', code: 'insufficient-permissions');
    }
    if (!hub.memberIds.contains(newOwnerId)) {
      throw ValidationException('New owner must be a member of the hub', code: 'not-a-member');
    }
    if (newOwnerId == userId) {
      throw ValidationException('Cannot transfer ownership to yourself', code: 'invalid-owner');
    }

    try {
      // Update creatorId and ensure new owner is in memberIds (should already be)
      await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubs'))
          .doc(hubId)
          .update({
        'creatorId': newOwnerId,
      });
      
      Logger.info('Hub ownership transferred: $hubId -> $newOwnerId', tag: 'HubService');
    } catch (e) {
      Logger.error('Error transferring hub ownership', error: e, tag: 'HubService');
      rethrow;
    }
  }

  /// Leave a hub (remove current user from members)
  Future<void> leaveHub(String hubId) async {
    final userId = currentUserId;
    if (userId == null) throw AuthException('User not logged in', code: 'not-authenticated');

    final hub = await getHub(hubId);
    if (hub == null) throw FirestoreException('Hub not found', code: 'not-found');
    if (hub.creatorId == userId) {
      throw ValidationException('Hub creator cannot leave. Transfer ownership or delete the hub instead.', code: 'creator-cannot-leave');
    }
    if (!hub.memberIds.contains(userId)) {
      throw ValidationException('User is not a member of this hub', code: 'not-a-member');
    }

    try {
      // Remove user from memberIds
      final updatedMemberIds = List<String>.from(hub.memberIds)..remove(userId);
      await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubs'))
          .doc(hubId)
          .update({
        'memberIds': updatedMemberIds,
      });
      
      Logger.info('User left hub: $hubId', tag: 'HubService');
    } catch (e) {
      Logger.error('Error leaving hub', error: e, tag: 'HubService');
      rethrow;
    }
  }

  /// Delete a hub
  Future<void> deleteHub(String hubId) async {
    final userId = currentUserId;
    if (userId == null) throw AuthException('User not logged in', code: 'not-authenticated');

    final hub = await getHub(hubId);
    if (hub == null) throw FirestoreException('Hub not found', code: 'not-found');
    if (hub.creatorId != userId) {
      throw PermissionException('Only the hub creator can delete the hub', code: 'insufficient-permissions');
    }

    try {
      await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubs'))
          .doc(hubId)
          .delete();
      
      Logger.info('Hub deleted: $hubId', tag: 'HubService');
    } catch (e) {
      Logger.error('Error deleting hub', error: e, tag: 'HubService');
      rethrow;
    }
  }

  /// Create an invite for a hub (email or phone)
  Future<HubInvite> createInvite({
    required String hubId,
    String? email,
    String? phoneNumber,
    String? userId, // If inviting an existing user
  }) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) throw AuthException('User not logged in', code: 'not-authenticated');

    if (email == null && phoneNumber == null && userId == null) {
      throw ValidationException('Must provide email, phone number, or user ID', code: 'missing-identifier');
    }

    final hub = await getHub(hubId);
    if (hub == null) throw FirestoreException('Hub not found', code: 'not-found');
    if (hub.creatorId != currentUserId) {
      throw PermissionException('Only the hub creator can invite members', code: 'insufficient-permissions');
    }

    final currentUser = await _authService.getCurrentUserModel();
    final inviterName = currentUser?.displayName ?? 'Someone';

    final invite = HubInvite(
      id: const Uuid().v4(),
      hubId: hubId,
      hubName: hub.name,
      inviterId: currentUserId,
      inviterName: inviterName,
      email: email,
      phoneNumber: phoneNumber,
      userId: userId,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)), // Expires in 30 days
    );

    try {
      final data = invite.toJson();
      data.remove('id');
      await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubInvites'))
          .doc(invite.id)
          .set(data);
      return invite;
    } catch (e) {
      Logger.error('Error creating invite', error: e, tag: 'HubService');
      rethrow;
    }
  }

  /// Get invite by ID
  Future<HubInvite?> getInvite(String inviteId) async {
    try {
      final doc = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubInvites'))
          .doc(inviteId)
          .get();
      if (!doc.exists) return null;
      return HubInvite.fromJson({'id': doc.id, ...doc.data()!});
    } catch (e) {
      Logger.error('Error getting invite', error: e, tag: 'HubService');
      return null;
    }
  }

  /// Accept an invite (add user to hub)
  Future<void> acceptInvite(String inviteId) async {
    final userId = currentUserId;
    if (userId == null) throw AuthException('User not logged in', code: 'not-authenticated');

    final invite = await getInvite(inviteId);
    if (invite == null) throw FirestoreException('Invite not found', code: 'not-found');
    if (invite.status != 'pending') {
      throw ValidationException('Invite has already been ${invite.status}', code: 'invalid-status');
    }
    if (invite.isExpired) {
      throw ValidationException('Invite has expired', code: 'expired');
    }

    // If invite has a userId, verify it matches current user
    if (invite.userId != null && invite.userId != userId) {
      throw ValidationException('This invite is for a different user', code: 'invalid-user');
    }

    try {
      // Add user to hub
      await addMember(invite.hubId, userId);

      // Update invite status
      await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubInvites'))
          .doc(inviteId)
          .update({
        'status': 'accepted',
        'userId': userId, // Store the user who accepted
      });
    } catch (e) {
      Logger.error('Error accepting invite', error: e, tag: 'HubService');
      rethrow;
    }
  }

  /// Get pending invites for current user (by email or phone)
  Future<List<HubInvite>> getPendingInvitesForUser() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final currentUser = await _authService.getCurrentUserModel();
    if (currentUser == null) return [];

    try {
      // Get invites by email
      final emailSnapshot = currentUser.email.isNotEmpty
          ? await _firestore
              .collection(FirestorePathUtils.getCollectionPath('hubInvites'))
              .where('email', isEqualTo: currentUser.email)
              .where('status', isEqualTo: 'pending')
              .get()
          : null;

      // Get invites by userId (if any)
      final userIdSnapshot = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubInvites'))
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      final invites = <String, HubInvite>{};

      if (emailSnapshot != null) {
        for (var doc in emailSnapshot.docs) {
          final invite = HubInvite.fromJson({'id': doc.id, ...doc.data()});
          if (!invite.isExpired) {
            invites[invite.id] = invite;
          }
        }
      }

      for (var doc in userIdSnapshot.docs) {
        final invite = HubInvite.fromJson({'id': doc.id, ...doc.data()});
        if (!invite.isExpired) {
          invites[invite.id] = invite;
        }
      }

      return invites.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      Logger.error('Error getting pending invites', error: e, tag: 'HubService');
      return [];
    }
  }
}

