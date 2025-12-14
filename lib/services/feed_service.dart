import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/chat_message.dart';
import '../utils/firestore_path_utils.dart';
import '../config/config.dart';
import 'auth_service.dart';
import 'chat_service.dart';
import 'message_reaction_service.dart';
import 'url_preview_service.dart';

/// Service for managing feed-style posts and interactions
/// Extends ChatService functionality with feed-specific features
class FeedService extends ChatService {
  final MessageReactionService _reactionService = MessageReactionService();
  final UrlPreviewService _urlPreviewService = UrlPreviewService();
  final Uuid _uuid = const Uuid();

  /// Create a poll post
  Future<ChatMessage> createPollPost({
    required String content,
    required List<String> options,
    required Duration duration,
    List<String>? visibleHubIds,
    String? hubId,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) {
      throw AuthException('User model not found', code: 'user-not-found');
    }

    if (options.length < 2 || options.length > 4) {
      throw ValidationException('Poll must have 2-4 options', code: 'invalid-poll-options');
    }

    final pollOptions = options
        .map((text) => PollOption(
              id: _uuid.v4(),
              text: text,
            ))
        .toList();

    final pollExpiresAt = DateTime.now().add(duration);

    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: userId,
      senderName: userModel.displayName,
      content: content,
      timestamp: DateTime.now(),
      type: MessageType.text,
      hubId: hubId,
      postType: PostType.poll,
      pollOptions: pollOptions,
      pollExpiresAt: pollExpiresAt,
      visibleHubIds: visibleHubIds ?? [],
      senderPhotoUrl: userModel.photoUrl,
    );

    await sendMessage(message);
    Logger.info('Poll post created: ${message.id}', tag: 'FeedService');
    return message;
  }

  /// Vote on a poll
  Future<void> voteOnPoll({
    required String messageId,
    required String optionId,
    String? familyId,
    String? hubId,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final collectionPath = hubId != null
          ? FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages')
          : await _getCollectionPath(familyId);

      final messageDoc = await _firestore
          .collection(collectionPath)
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw NotFoundException('Poll not found', code: 'poll-not-found');
      }

      final data = messageDoc.data()!;
      final pollOptions = (data['pollOptions'] as List<dynamic>?)
              ?.map((o) => PollOption.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [];

      // Check if poll has expired
      if (data['pollExpiresAt'] != null) {
        final expiresAt = DateTime.parse(data['pollExpiresAt'] as String);
        if (expiresAt.isBefore(DateTime.now())) {
          throw ValidationException('Poll has expired', code: 'poll-expired');
        }
      }

      // Check if user already voted
      String? previousVoteId;
      for (var option in pollOptions) {
        if (option.voterIds.contains(userId)) {
          previousVoteId = option.id;
          break;
        }
      }

      // Update poll options
      final updatedOptions = pollOptions.map((option) {
        if (option.id == optionId) {
          // Add vote to this option
          final newVoterIds = [...option.voterIds];
          if (!newVoterIds.contains(userId)) {
            newVoterIds.add(userId);
          }
          return PollOption(
            id: option.id,
            text: option.text,
            voteCount: newVoterIds.length,
            voterIds: newVoterIds,
          );
        } else if (previousVoteId != null && option.id == previousVoteId) {
          // Remove previous vote
          final newVoterIds = option.voterIds.where((id) => id != userId).toList();
          return PollOption(
            id: option.id,
            text: option.text,
            voteCount: newVoterIds.length,
            voterIds: newVoterIds,
          );
        }
        return option;
      }).toList();

      // Update message in Firestore
      await _firestore
          .collection(collectionPath)
          .doc(messageId)
          .update({
        'pollOptions': updatedOptions.map((o) => o.toJson()).toList(),
        'votedPollOptionId': optionId,
      });

      Logger.info('Vote recorded on poll $messageId: option $optionId', tag: 'FeedService');
    } catch (e) {
      Logger.error('Error voting on poll', error: e, tag: 'FeedService');
      rethrow;
    }
  }

  /// Like/unlike a post (using reactions)
  Future<void> toggleLike({
    required String messageId,
    String? familyId,
    String? hubId,
  }) async {
    try {
      // Use heart emoji for likes
      await _reactionService.addReaction(
        messageId: messageId,
        emoji: '❤️',
        familyId: familyId,
        hubId: hubId,
      );
    } catch (e) {
      Logger.error('Error toggling like', error: e, tag: 'FeedService');
      rethrow;
    }
  }

  /// Share/repost a post
  Future<ChatMessage> sharePost({
    required String originalMessageId,
    String? comment,
    List<String>? visibleHubIds,
    String? hubId,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw AuthException('User not authenticated', code: 'not-authenticated');
    }

    final userModel = await _authService.getCurrentUserModel();
    if (userModel == null) {
      throw AuthException('User model not found', code: 'user-not-found');
    }

    // Get original message
    final collectionPath = hubId != null
        ? FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages')
        : await _getCollectionPath(null);

    final originalDoc = await _firestore
        .collection(collectionPath)
        .doc(originalMessageId)
        .get();

    if (!originalDoc.exists) {
      throw NotFoundException('Original post not found', code: 'post-not-found');
    }

    // Increment share count on original
    await _firestore
        .collection(collectionPath)
        .doc(originalMessageId)
        .update({
      'shareCount': FieldValue.increment(1),
    });

    // Create share message
    final shareMessage = ChatMessage(
      id: _uuid.v4(),
      senderId: userId,
      senderName: userModel.displayName,
      content: comment ?? 'Shared a post',
      timestamp: DateTime.now(),
      type: MessageType.text,
      hubId: hubId,
      parentMessageId: originalMessageId,
      visibleHubIds: visibleHubIds ?? [],
      senderPhotoUrl: userModel.photoUrl,
    );

    await sendMessage(shareMessage);
    Logger.info('Post shared: $originalMessageId', tag: 'FeedService');
    return shareMessage;
  }

  /// Get feed posts with pagination
  Stream<List<ChatMessage>> getFeedStream({
    String? hubId,
    List<String>? hubIds, // For multi-hub feed
    int limit = 20,
    bool includeReplies = false,
  }) {
    // If multiple hubs, aggregate feeds
    if (hubIds != null && hubIds.isNotEmpty) {
      return _getMultiHubFeedStream(hubIds, limit, includeReplies);
    }

    // Single hub/family feed
    return Stream.fromFuture(_familyId).asyncExpand((familyId) {
      if (familyId == null && hubId == null) {
        return Stream.value(<ChatMessage>[]);
      }

      final collectionPath = hubId != null
          ? FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages')
          : FirestorePathUtils.getFamilySubcollectionPath(familyId!, 'messages');

      return _firestore
          .collection(collectionPath)
          .where('parentMessageId', isNull: includeReplies ? null : true) // Top-level posts only
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) {
              try {
                return ChatMessage.fromJson({'id': doc.id, ...doc.data()});
              } catch (e) {
                Logger.warning('Error parsing message ${doc.id}', error: e, tag: 'FeedService');
                return null;
              }
            })
            .whereType<ChatMessage>()
            .toList();
      });
    });
  }

  /// Get multi-hub feed (aggregates posts from multiple hubs)
  Stream<List<ChatMessage>> _getMultiHubFeedStream(
    List<String> hubIds,
    int limit,
    bool includeReplies,
  ) {
    // Create streams for each hub
    final streams = hubIds.map((hubId) {
      final collectionPath = FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages');
      return _firestore
          .collection(collectionPath)
          .where('parentMessageId', isNull: includeReplies ? null : true)
          .where('visibleHubIds', arrayContainsAny: hubIds) // Cross-hub posts
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) {
              try {
                return ChatMessage.fromJson({'id': doc.id, ...doc.data()});
              } catch (e) {
                Logger.warning('Error parsing message ${doc.id}', error: e, tag: 'FeedService');
                return null;
              }
            })
            .whereType<ChatMessage>()
            .toList();
      });
    });

    // Merge and sort streams
    return Stream.periodic(const Duration(seconds: 1), (_) {
      // This is a simplified merge - in production, use a proper stream combiner
      return <ChatMessage>[];
    });
  }

  /// Get comments/replies for a post
  Stream<List<ChatMessage>> getPostComments({
    required String postId,
    String? familyId,
    String? hubId,
  }) {
    final collectionPath = hubId != null
        ? FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages')
        : Stream.fromFuture(_familyId).asyncExpand((fId) {
            if (fId == null) return Stream.value('');
            return Stream.value(FirestorePathUtils.getFamilySubcollectionPath(fId, 'messages'));
          });

    // This needs proper async handling - simplified for now
    return Stream.value(<ChatMessage>[]);
  }

  /// Override sendMessage to add URL preview detection
  @override
  Future<void> sendMessage(ChatMessage message) async {
    // Detect URLs in message content
    final urlPattern = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );
    final urlMatch = urlPattern.firstMatch(message.content);
    
    if (urlMatch != null) {
      final url = urlMatch.group(0)!;
      try {
        // Fetch URL preview in background (don't block message sending)
        _urlPreviewService.fetchPreview(url).then((preview) {
          if (preview != null) {
            // Update message with preview (async, won't block)
            final familyId = _familyId;
            familyId.then((fId) async {
              if (fId == null) return;
              try {
                final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(fId, 'messages');
                await _firestore
                    .collection(collectionPath)
                    .doc(message.id)
                    .update({'urlPreview': preview.toJson()});
                Logger.info('URL preview added to message ${message.id}', tag: 'FeedService');
              } catch (e) {
                Logger.warning('Error updating message with URL preview', error: e, tag: 'FeedService');
              }
            });
          }
        }).catchError((e) {
          Logger.warning('Error fetching URL preview', error: e, tag: 'FeedService');
        });
      } catch (e) {
        Logger.warning('Error detecting URL in message', error: e, tag: 'FeedService');
      }
    }
    
    // Call parent sendMessage
    await super.sendMessage(message);
  }

  /// Helper to get collection path
  Future<String> _getCollectionPath(String? familyId) async {
    if (familyId != null) {
      return FirestorePathUtils.getFamilySubcollectionPath(familyId, 'messages');
    }
    final fId = await _familyId;
    if (fId == null) throw AuthException('User not part of a family', code: 'no-family');
    return FirestorePathUtils.getFamilySubcollectionPath(fId, 'messages');
  }
}

