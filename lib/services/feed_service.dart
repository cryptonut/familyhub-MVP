import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_exceptions.dart';
import '../core/services/logger_service.dart';
import '../models/chat_message.dart';
import '../utils/firestore_path_utils.dart';
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

  // Re-declare parent private members for access (since they're private)
  final FirebaseFirestore _feedFirestore = FirebaseFirestore.instance;
  final FirebaseAuth _feedAuth = FirebaseAuth.instance;
  final AuthService _feedAuthService = AuthService();

  Future<String?> get _feedFamilyId async {
    final userModel = await _feedAuthService.getCurrentUserModel();
    return userModel?.familyId;
  }

  // Expose parent class getters
  @override
  String? get currentUserId => _feedAuth.currentUser?.uid;

  @override
  String? get currentUserName {
    // Return email as fallback - actual displayName requires async call
    return _feedAuth.currentUser?.displayName ?? _feedAuth.currentUser?.email;
  }

  /// Create a poll post
  Future<ChatMessage> createPollPost({
    required String content,
    required List<String> options,
    required Duration duration,
    List<String>? visibleHubIds,
    String? hubId,
  }) async {
    final userId = _feedAuth.currentUser?.uid;
    if (userId == null) {
      throw const AuthException('User not authenticated', code: 'not-authenticated');
    }

    final userModel = await _feedAuthService.getCurrentUserModel();
    if (userModel == null) {
      throw const AuthException('User model not found', code: 'user-not-found');
    }

    if (options.length < 2 || options.length > 4) {
      throw const ValidationException('Poll must have 2-4 options', code: 'invalid-poll-options');
    }

    final pollOptions = options
        .map((text) => PollOption(
              id: _uuid.v4(),
              text: text,
            ),)
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
      visibleHubIds: visibleHubIds ?? const [],
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
    final userId = _feedAuth.currentUser?.uid;
    if (userId == null) {
      throw const AuthException('User not authenticated', code: 'not-authenticated');
    }

    try {
      final collectionPath = hubId != null
          ? FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages')
          : await _getCollectionPath(familyId);

      final messageDoc = await _feedFirestore
          .collection(collectionPath)
          .doc(messageId)
          .get();

      if (!messageDoc.exists) {
        throw const NotFoundException('Poll not found', code: 'poll-not-found');
      }

      final data = messageDoc.data()!;
      final pollOptions = (data['pollOptions'] as List<dynamic>?)
              ?.map((o) => PollOption.fromJson(o as Map<String, dynamic>))
              .toList() ??
          <PollOption>[];

      // Check if poll has expired
      if (data['pollExpiresAt'] != null) {
        final expiresAt = DateTime.parse(data['pollExpiresAt'] as String);
        if (expiresAt.isBefore(DateTime.now())) {
          throw const ValidationException('Poll has expired', code: 'poll-expired');
        }
      }

      // Check if user already voted
      String? previousVoteId;
      for (final option in pollOptions) {
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
      await _feedFirestore
          .collection(collectionPath)
          .doc(messageId)
          .update({
        'pollOptions': updatedOptions.map((o) => o.toJson()).toList(),
        'votedPollOptionId': optionId,
      });

      Logger.info('Vote recorded on poll $messageId: option $optionId', tag: 'FeedService');
    } on AppException {
      rethrow;
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
      // Get familyId if not provided
      final fId = familyId ?? await _feedFamilyId;
      if (fId == null) {
        throw const AuthException('User not part of a family', code: 'no-family');
      }

      // Add reaction (works for both family and hub messages)
      await _reactionService.addReaction(messageId, '❤️', fId, chatId: hubId);
    } on AppException {
      rethrow;
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
    final userId = _feedAuth.currentUser?.uid;
    if (userId == null) {
      throw const AuthException('User not authenticated', code: 'not-authenticated');
    }

    final userModel = await _feedAuthService.getCurrentUserModel();
    if (userModel == null) {
      throw const AuthException('User model not found', code: 'user-not-found');
    }

    // Get original message
    final collectionPath = hubId != null
        ? FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages')
        : await _getCollectionPath(null);

    final originalDoc = await _feedFirestore
        .collection(collectionPath)
        .doc(originalMessageId)
        .get();

    if (!originalDoc.exists) {
      throw const NotFoundException('Original post not found', code: 'post-not-found');
    }

    // Increment share count on original
    await _feedFirestore
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
      visibleHubIds: visibleHubIds ?? const [],
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
    return Stream.fromFuture(_feedFamilyId).asyncExpand((familyId) {
      if (familyId == null && hubId == null) {
        return Stream.value(<ChatMessage>[]);
      }

      final collectionPath = hubId != null
          ? FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages')
          : FirestorePathUtils.getFamilySubcollectionPath(familyId!, 'messages');

      return _feedFirestore
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
              } on Exception catch (e) {
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
  ) async* {
    // Create streams for each hub
    final streams = hubIds.map((hubId) {
      final collectionPath = FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages');
      final query = _feedFirestore
          .collection(collectionPath)
          .where('parentMessageId', isNull: includeReplies ? null : true)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      // If cross-hub posts exist, also query for them
      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                final message = ChatMessage.fromJson({'id': doc.id, ...data});

                // Include if:
                // 1. It's from this hub (hubId matches)
                // 2. OR it's a cross-hub post visible to this hub
                final visibleHubIds = message.visibleHubIds;
                final isFromThisHub = message.hubId == hubId;
                final isCrossHubVisible = visibleHubIds.isNotEmpty &&
                    (visibleHubIds.contains(hubId) || visibleHubIds.any((id) => hubIds.contains(id)));

                if (isFromThisHub || isCrossHubVisible) {
                  return message;
                }
                return null;
              } on Exception catch (e) {
                Logger.warning('Error parsing message ${doc.id}', error: e, tag: 'FeedService');
                return null;
              }
            })
            .whereType<ChatMessage>()
            .toList();
      });
    }).toList();

    // Merge streams using CombineLatestStream or similar
    // For now, use a simpler approach: combine all streams and merge results
    yield* Stream.periodic(const Duration(seconds: 2), (_) async {
      final allPosts = <ChatMessage>[];

      // Get latest from each stream
      for (final stream in streams) {
        try {
          final posts = await stream.first.timeout(const Duration(seconds: 1));
          allPosts.addAll(posts);
        } on Exception catch (e) {
          Logger.warning('Error fetching hub feed', error: e, tag: 'FeedService');
        }
      }

      // Remove duplicates (same message ID)
      final uniquePosts = <String, ChatMessage>{};
      for (final post in allPosts) {
        if (!uniquePosts.containsKey(post.id)) {
          uniquePosts[post.id] = post;
        }
      }

      // Sort by timestamp and limit
      final sorted = uniquePosts.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return sorted.take(limit).toList();
    }).asyncMap((future) => future);
  }

  /// Get comments/replies for a post (with threading support)
  Stream<List<ChatMessage>> getPostComments({
    required String postId,
    String? familyId,
    String? hubId,
    int maxDepth = 3, // Maximum nesting depth
  }) async* {
    final collectionPath = hubId != null
        ? FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages')
        : await _getCollectionPath(familyId);

    // Get all comments for this post (top-level and nested)
    yield* _feedFirestore
        .collection(collectionPath)
        .where('parentMessageId', isEqualTo: postId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
      final comments = <ChatMessage>[];

      for (final doc in snapshot.docs) {
        try {
          final comment = ChatMessage.fromJson({'id': doc.id, ...doc.data()});
          comments.add(comment);

          // Recursively load nested replies (up to maxDepth)
          if (maxDepth > 1) {
            final replies = await _getNestedReplies(
              commentId: comment.id,
              collectionPath: collectionPath,
              currentDepth: 1,
              maxDepth: maxDepth,
            );
            comments.addAll(replies);
          }
        } on Exception catch (e) {
          Logger.warning('Error parsing comment ${doc.id}', error: e, tag: 'FeedService');
        }
      }

      return comments;
    });
  }

  /// Get nested replies recursively
  Future<List<ChatMessage>> _getNestedReplies({
    required String commentId,
    required String collectionPath,
    required int currentDepth,
    required int maxDepth,
  }) async {
    if (currentDepth >= maxDepth) return <ChatMessage>[];

    final snapshot = await _feedFirestore
        .collection(collectionPath)
        .where('parentMessageId', isEqualTo: commentId)
        .orderBy('timestamp', descending: false)
        .get();

    final replies = <ChatMessage>[];
    for (final doc in snapshot.docs) {
      try {
        final reply = ChatMessage.fromJson({'id': doc.id, ...doc.data()});
        replies.add(reply);

        // Recursively get deeper replies
        if (currentDepth + 1 < maxDepth) {
          final nestedReplies = await _getNestedReplies(
            commentId: reply.id,
            collectionPath: collectionPath,
            currentDepth: currentDepth + 1,
            maxDepth: maxDepth,
          );
          replies.addAll(nestedReplies);
        }
      } on Exception catch (e) {
        Logger.warning('Error parsing nested reply ${doc.id}', error: e, tag: 'FeedService');
      }
    }

    return replies;
  }

  /// Reply to a post or comment
  Future<ChatMessage> replyToPost({
    required String parentMessageId,
    required String content,
    String? familyId,
    String? hubId,
    String? threadId,
  }) async {
    final userId = _feedAuth.currentUser?.uid;
    if (userId == null) {
      throw const AuthException('User not authenticated', code: 'not-authenticated');
    }

    final userModel = await _feedAuthService.getCurrentUserModel();
    if (userModel == null) {
      throw const AuthException('User model not found', code: 'user-not-found');
    }

    // Get parent message to determine thread
    final collectionPath = hubId != null
        ? FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages')
        : await _getCollectionPath(familyId);

    final parentDoc = await _feedFirestore
        .collection(collectionPath)
        .doc(parentMessageId)
        .get();

    if (!parentDoc.exists) {
      throw const NotFoundException('Parent message not found', code: 'parent-not-found');
    }

    final parentData = parentDoc.data()!;
    final parentThreadId = parentData['threadId'] as String? ?? parentMessageId;

    // Create reply
    final reply = ChatMessage(
      id: _uuid.v4(),
      senderId: userId,
      senderName: userModel.displayName,
      content: content,
      timestamp: DateTime.now(),
      type: MessageType.text,
      hubId: hubId,
      parentMessageId: parentMessageId,
      threadId: threadId ?? parentThreadId,
      senderPhotoUrl: userModel.photoUrl,
    );

    await sendMessage(reply);

    // Increment comment count on parent
    await _feedFirestore
        .collection(collectionPath)
        .doc(parentMessageId)
        .update({
      'commentCount': FieldValue.increment(1),
    });

    Logger.info('Reply posted: ${reply.id} to $parentMessageId', tag: 'FeedService');
    return reply;
  }

  /// Override sendMessage to add URL preview detection and handle hub messages
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
        unawaited(_urlPreviewService.fetchPreview(url).then((preview) {
          if (preview != null) {
            // Update message with preview (async, won't block)
            final collectionPath = message.hubId != null
                ? FirestorePathUtils.getHubSubcollectionPath(message.hubId!, 'messages')
                : _feedFamilyId.then((fId) {
                    if (fId == null) return null;
                    return FirestorePathUtils.getFamilySubcollectionPath(fId, 'messages');
                  });
            
            if (message.hubId != null) {
              _feedFirestore
                  .collection(FirestorePathUtils.getHubSubcollectionPath(message.hubId!, 'messages'))
                  .doc(message.id)
                  .update({'urlPreview': preview.toJson()})
                  .then((_) {
                    Logger.info('URL preview added to message ${message.id}', tag: 'FeedService');
                  })
                  .catchError((e) {
                    Logger.warning('Error updating message with URL preview', error: e, tag: 'FeedService');
                  });
            } else {
              _feedFamilyId.then((fId) async {
                if (fId == null) return;
                try {
                  final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(fId, 'messages');
                  await _feedFirestore
                      .collection(collectionPath)
                      .doc(message.id)
                      .update({'urlPreview': preview.toJson()});
                  Logger.info('URL preview added to message ${message.id}', tag: 'FeedService');
                } on Exception catch (e) {
                  Logger.warning('Error updating message with URL preview', error: e, tag: 'FeedService');
                }
              });
            }
          }
        }).catchError((e) {
          Logger.warning('Error fetching URL preview', error: e, tag: 'FeedService');
        },),);
      } on Exception catch (e) {
        Logger.warning('Error detecting URL in message', error: e, tag: 'FeedService');
      }
    }

    // Handle hub messages vs family messages
    if (message.hubId != null) {
      // Send to hub messages collection
      try {
        final collectionPath = FirestorePathUtils.getHubSubcollectionPath(message.hubId!, 'messages');
        await _feedFirestore.collection(collectionPath).doc(message.id).set(message.toJson());
        Logger.info('Hub message sent: ${message.id}', tag: 'FeedService');
      } catch (e) {
        Logger.error('Error sending hub message', error: e, tag: 'FeedService');
        rethrow;
      }
    } else {
      // Send to family messages collection using message.id (not .add which generates new ID)
      try {
        final familyId = await _feedFamilyId;
        if (familyId == null) {
          throw const AuthException('User not part of a family', code: 'no-family');
        }
        final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'messages');
        await _feedFirestore.collection(collectionPath).doc(message.id).set(message.toJson());
        Logger.info('Family message sent: ${message.id}', tag: 'FeedService');
      } catch (e) {
        Logger.error('Error sending family message', error: e, tag: 'FeedService');
        rethrow;
      }
    }
  }

  /// Helper to get collection path
  Future<String> _getCollectionPath(String? familyId) async {
    if (familyId != null) {
      return FirestorePathUtils.getFamilySubcollectionPath(familyId, 'messages');
    }
    final fId = await _feedFamilyId;
    if (fId == null) throw const AuthException('User not part of a family', code: 'no-family');
    return FirestorePathUtils.getFamilySubcollectionPath(fId, 'messages');
  }
}
