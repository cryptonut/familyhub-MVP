import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/event_chat_message.dart';
import 'auth_service.dart';
import 'calendar_service.dart';

/// Service for managing event-specific chat messages
class EventChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Check if current user has access to event chat
  /// Access is granted to: event creator + invitedMemberIds
  Future<bool> _hasEventAccess(String eventId) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return false;

      // Get event document to check createdBy field
      final familyId = userModel.familyId;
      if (familyId == null) return false;

      final eventDoc = await _firestore
          .collection('families/$familyId/events')
          .doc(eventId)
          .get();

      if (!eventDoc.exists) return false;

      final eventData = eventDoc.data()!;
      final createdBy = eventData['createdBy'] as String?;
      final invitedMemberIds = List<String>.from(
        eventData['invitedMemberIds'] as List? ?? [],
      );

      // User has access if they're the creator or in invitedMemberIds
      // If createdBy is null (legacy event), allow if user is in invitedMemberIds or is a family member
      if (createdBy == null) {
        // Legacy event: allow if user is in invitedMemberIds or if no invites (all family members)
        return invitedMemberIds.isEmpty || invitedMemberIds.contains(userId);
      }
      return createdBy == userId || invitedMemberIds.contains(userId);
    } catch (e) {
      Logger.warning('Error checking event access', error: e, tag: 'EventChatService');
      return false;
    }
  }

  /// Get event chat messages stream
  Stream<List<EventChatMessage>> getEventChatMessagesStream(String eventId) {
    return Stream.fromFuture(_hasEventAccess(eventId)).asyncExpand((hasAccess) {
      if (!hasAccess) {
        return Stream.value(<EventChatMessage>[]);
      }

      final userId = _currentUserId;
      if (userId == null) {
        return Stream.value(<EventChatMessage>[]);
      }

      return Stream.fromFuture(_authService.getCurrentUserModel())
          .asyncExpand((userModel) {
        if (userModel?.familyId == null) {
          return Stream.value(<EventChatMessage>[]);
        }

        final familyId = userModel!.familyId!;

        return _firestore
            .collection('families/$familyId/events/$eventId/chats')
            .orderBy('timestamp', descending: false)
            .snapshots()
            .asyncMap((snapshot) async {
              final messages = <EventChatMessage>[];
              for (var doc in snapshot.docs) {
                final data = doc.data();
                var messageData = {
                  'id': doc.id,
                  ...data,
                };

                // If senderName is missing, try to get it from user document
                if (messageData['senderName'] == null ||
                    (messageData['senderName'] as String).isEmpty) {
                  final senderId = messageData['senderId'] as String?;
                  if (senderId != null) {
                    try {
                      final userDoc =
                          await _firestore.collection('users').doc(senderId).get();
                      if (userDoc.exists) {
                        final userData = userDoc.data();
                        messageData['senderName'] =
                            userData?['displayName'] as String? ??
                                userData?['email'] as String? ??
                                'Unknown User';
                      } else {
                        messageData['senderName'] = 'Unknown User';
                      }
                    } catch (e) {
                      Logger.warning('Error fetching sender name',
                          error: e, tag: 'EventChatService');
                      messageData['senderName'] = 'Unknown User';
                    }
                  } else {
                    messageData['senderName'] = 'Unknown User';
                  }
                }

                messages.add(EventChatMessage.fromJson(messageData));
              }
              return messages;
            });
      });
    });
  }

  /// Load more event chat messages with pagination
  Future<List<EventChatMessage>> loadMoreEventChatMessages({
    required String eventId,
    required DocumentSnapshot lastDoc,
    int limit = 50,
  }) async {
    if (!await _hasEventAccess(eventId)) {
      return [];
    }

    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel?.familyId == null) return [];

      final familyId = userModel!.familyId!;

      final snapshot = await _firestore
          .collection('families/$familyId/events/$eventId/chats')
          .orderBy('timestamp', descending: false)
          .startAfterDocument(lastDoc)
          .limit(limit)
          .get();

      final messages = <EventChatMessage>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        var messageData = {
          'id': doc.id,
          ...data,
        };

        // If senderName is missing, try to get it from user document
        if (messageData['senderName'] == null ||
            (messageData['senderName'] as String).isEmpty) {
          final senderId = messageData['senderId'] as String?;
          if (senderId != null) {
            try {
              final userDoc =
                  await _firestore.collection('users').doc(senderId).get();
              if (userDoc.exists) {
                final userData = userDoc.data();
                messageData['senderName'] =
                    userData?['displayName'] as String? ??
                        userData?['email'] as String? ??
                        'Unknown User';
              } else {
                messageData['senderName'] = 'Unknown User';
              }
            } catch (e) {
              Logger.warning('Error fetching sender name in loadMore', error: e, tag: 'EventChatService');
              messageData['senderName'] = 'Unknown User';
            }
          } else {
            messageData['senderName'] = 'Unknown User';
          }
        }

        messages.add(EventChatMessage.fromJson(messageData));
      }

      return messages;
    } catch (e) {
      Logger.error('Error loading more event chat messages', error: e, tag: 'EventChatService');
      return [];
    }
  }

  /// Send a message to event chat
  Future<void> sendMessage(EventChatMessage message) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final hasAccess = await _hasEventAccess(message.eventId);
    if (!hasAccess) {
      throw AuthException('Access denied to event chat', code: 'access-denied');
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel?.familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    final familyId = userModel!.familyId!;

    try {
      // Extract @mentions from content (await the async call)
      final mentionedUserIds = await _extractMentions(message.content, familyId);

      final messageData = message.toJson();
      messageData.remove('id');
      messageData['mentionedUserIds'] = mentionedUserIds;
      // Ensure eventId is in the message data
      messageData['eventId'] = message.eventId;

      await _firestore
          .collection('families/$familyId/events/${message.eventId}/chats')
          .add(messageData);
    } catch (e) {
      Logger.error('sendMessage error', error: e, tag: 'EventChatService');
      rethrow;
    }
  }

  /// Extract @mentions from message content
  /// Format: @username or @userId
  Future<List<String>> _extractMentions(String content, String familyId) async {
    final mentions = <String>[];
    final mentionPattern = RegExp(r'@(\w+)');

    for (var match in mentionPattern.allMatches(content)) {
      final mention = match.group(1)!;
      // Try to find user by displayName or email
      try {
        final usersSnapshot = await _firestore
            .collection('users')
            .where('familyId', isEqualTo: familyId)
            .get();

        for (var doc in usersSnapshot.docs) {
          final userData = doc.data();
          final displayName = userData['displayName'] as String? ?? '';
          final email = userData['email'] as String? ?? '';

          if (displayName.toLowerCase().contains(mention.toLowerCase()) ||
              email.toLowerCase().contains(mention.toLowerCase())) {
            mentions.add(doc.id);
            break;
          }
        }
      } catch (e) {
        Logger.warning('Error extracting mentions', error: e, tag: 'EventChatService');
      }
    }

    return mentions;
  }

  /// Edit a message (only by sender)
  Future<void> editMessage(String eventId, String messageId, String newContent) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final hasAccess = await _hasEventAccess(eventId);
    if (!hasAccess) {
      throw AuthException('Access denied to event chat', code: 'access-denied');
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel?.familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    final familyId = userModel!.familyId!;

    try {
      final messageRef = _firestore
          .collection('families/$familyId/events/$eventId/chats')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) {
        throw FirestoreException('Message not found', code: 'not-found');
      }

      final messageData = messageDoc.data()!;
      if (messageData['senderId'] != userId) {
        throw AuthException('Only message sender can edit', code: 'unauthorized');
      }

      // Extract new mentions
      final mentionedUserIds = await _extractMentions(newContent, familyId);

      await messageRef.update({
        'content': newContent,
        'editedAt': DateTime.now().toIso8601String(),
        'mentionedUserIds': mentionedUserIds,
      });
    } catch (e) {
      Logger.error('editMessage error', error: e, tag: 'EventChatService');
      rethrow;
    }
  }

  /// Delete a message (by sender or admin)
  Future<void> deleteMessage(String eventId, String messageId, {bool isAdmin = false}) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final hasAccess = await _hasEventAccess(eventId);
    if (!hasAccess) {
      throw AuthException('Access denied to event chat', code: 'access-denied');
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel?.familyId == null) {
      throw AuthException('User not part of a family', code: 'no-family');
    }

    final familyId = userModel!.familyId!;

    try {
      final messageRef = _firestore
          .collection('families/$familyId/events/$eventId/chats')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) {
        throw FirestoreException('Message not found', code: 'not-found');
      }

      final messageData = messageDoc.data()!;
      final senderId = messageData['senderId'] as String?;

      // Check if user is admin or sender
      if (!isAdmin && senderId != userId) {
        throw AuthException('Only message sender or admin can delete', code: 'unauthorized');
      }

      // Check if user is admin
      final isUserAdmin = userModel.roles.contains('Admin');

      if (isAdmin || isUserAdmin) {
        // Admin delete - mark as deleted
        await messageRef.update({
          'isDeleted': true,
          'deletedBy': userId,
          'content': '[Message deleted by admin]',
        });
      } else {
        // Sender delete - mark as deleted
        await messageRef.update({
          'isDeleted': true,
          'content': '[Message deleted]',
        });
      }
    } catch (e) {
      Logger.error('deleteMessage error', error: e, tag: 'EventChatService');
      rethrow;
    }
  }

  /// Get threaded replies for a message
  Stream<List<EventChatMessage>> getRepliesStream(String eventId, String parentMessageId) {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value(<EventChatMessage>[]);
    }

    return Stream.fromFuture(_authService.getCurrentUserModel())
        .asyncExpand((userModel) {
      if (userModel?.familyId == null) {
        return Stream.value(<EventChatMessage>[]);
      }

      final familyId = userModel!.familyId!;

      return _firestore
          .collection('families/$familyId/events/$eventId/chats')
          .where('parentMessageId', isEqualTo: parentMessageId)
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => EventChatMessage.fromJson({
                    'id': doc.id,
                    ...doc.data(),
                  }))
              .toList());
    });
  }
}

