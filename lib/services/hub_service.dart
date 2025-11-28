import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/hub.dart';
import '../models/hub_invite.dart';
import 'auth_service.dart';

class HubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Get all hubs for the current user
  Future<List<Hub>> getUserHubs() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      // Get hubs where user is creator or member
      final snapshot = await _firestore
          .collection('hubs')
          .where('creatorId', isEqualTo: userId)
          .get();

      final createdHubs = snapshot.docs
          .map((doc) => Hub.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      // Also get hubs where user is a member
      final memberSnapshot = await _firestore
          .collection('hubs')
          .where('memberIds', arrayContains: userId)
          .get();

      final memberHubs = memberSnapshot.docs
          .map((doc) => Hub.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      // Combine and remove duplicates
      final allHubs = <String, Hub>{};
      for (var hub in createdHubs) {
        allHubs[hub.id] = hub;
      }
      for (var hub in memberHubs) {
        allHubs[hub.id] = hub;
      }

      return allHubs.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      Logger.error('Error getting user hubs', error: e, tag: 'HubService');
      return [];
    }
  }

  /// Get a specific hub by ID
  Future<Hub?> getHub(String hubId) async {
    try {
      final doc = await _firestore.collection('hubs').doc(hubId).get();
      if (!doc.exists) return null;
      return Hub.fromJson({'id': doc.id, ...doc.data()!});
    } catch (e) {
      Logger.error('Error getting hub', error: e, tag: 'HubService');
      return null;
    }
  }

  /// Create a new hub
  Future<Hub> createHub({
    required String name,
    required String description,
    String? icon,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw AuthException('User not logged in', code: 'not-authenticated');

    final hub = Hub(
      id: const Uuid().v4(),
      name: name,
      description: description,
      creatorId: userId,
      memberIds: [userId], // Creator is automatically a member
      createdAt: DateTime.now(),
      icon: icon,
    );

    try {
      final data = hub.toJson();
      data.remove('id');
      await _firestore.collection('hubs').doc(hub.id).set(data);
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

      await _firestore.collection('hubs').doc(hubId).update({
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
      await _firestore.collection('hubs').doc(hubId).update({
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
      await _firestore.collection('hubs').doc(hubId).update(updates);
    } catch (e) {
      Logger.error('Error updating hub', error: e, tag: 'HubService');
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
      await _firestore.collection('hubs').doc(hubId).delete();
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
      await _firestore.collection('hubInvites').doc(invite.id).set(data);
      return invite;
    } catch (e) {
      Logger.error('Error creating invite', error: e, tag: 'HubService');
      rethrow;
    }
  }

  /// Get invite by ID
  Future<HubInvite?> getInvite(String inviteId) async {
    try {
      final doc = await _firestore.collection('hubInvites').doc(inviteId).get();
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
      await _firestore.collection('hubInvites').doc(inviteId).update({
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
              .collection('hubInvites')
              .where('email', isEqualTo: currentUser.email)
              .where('status', isEqualTo: 'pending')
              .get()
          : null;

      // Get invites by userId (if any)
      final userIdSnapshot = await _firestore
          .collection('hubInvites')
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

