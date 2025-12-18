import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/chat_message.dart';
import '../utils/firestore_path_utils.dart';
import '../config/config.dart';
import 'auth_service.dart';
import 'query_cache_service.dart';
import 'encrypted_chat_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  EncryptedChatService? _encryptedChatService;
  
  String? _cachedFamilyId;
  Stream<List<ChatMessage>>? _cachedMessagesStream;
  
  ChatService({EncryptedChatService? encryptedChatService})
      : _encryptedChatService = encryptedChatService;
  
  Future<String?> get _familyId async {
    if (_cachedFamilyId != null) return _cachedFamilyId;
    
    final userModel = await _authService.getCurrentUserModel();
    _cachedFamilyId = userModel?.familyId;
    return _cachedFamilyId;
  }

  Future<String> get _collectionPath async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    return FirestorePathUtils.getFamilySubcollectionPath(familyId, 'messages');
  }

  /// Invalidate chat messages cache when messages are modified
  Future<void> _invalidateChatMessagesCache(String familyId) async {
    final queryCache = QueryCacheService();
    await queryCache.invalidateCache(prefix: 'chat_messages', queryId: familyId);
  }

  Stream<List<ChatMessage>> getMessagesStream() {
    // Return cached stream if available to ensure all listeners share the same stream
    if (_cachedMessagesStream != null) {
      return _cachedMessagesStream!;
    }
    
    // Create stream that waits for familyId, then streams from Firestore
    _cachedMessagesStream = Stream.fromFuture(_familyId).asyncExpand((familyId) {
      if (familyId == null) {
        return Stream.value(<ChatMessage>[]);
      }
      
      // Query both prefixed and unprefixed collections for backward compatibility
      final prefixedPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'messages');
      final unprefixedPath = 'families/$familyId/messages';
      final prefix = Config.current.firestorePrefix;
      
      // Create streams for both collections
      final prefixedStream = _firestore
          .collection(prefixedPath)
          .orderBy('timestamp', descending: false)
          .snapshots();
      
      // Only query unprefixed if we're using a prefix (for migration)
      Stream<QuerySnapshot>? unprefixedStream;
      if (prefix.isNotEmpty) {
        unprefixedStream = _firestore
            .collection(unprefixedPath)
            .orderBy('timestamp', descending: false)
            .snapshots();
      }
      
      // Combine streams: if unprefixed exists, merge both; otherwise just use prefixed
      if (unprefixedStream != null) {
        // Use StreamController to merge both streams
        final controller = StreamController<List<ChatMessage>>();
        final prefixedMessages = <String, ChatMessage>{};
        final unprefixedMessages = <String, ChatMessage>{};
        var prefixedReady = false;
        var unprefixedReady = false;
        
        void emitCombined() {
          // Only emit if we have data from at least one stream
          if (!prefixedReady && !unprefixedReady) return;
          
          final allMessages = <ChatMessage>[];
          final seenIds = <String>{};
          
          // Add unprefixed messages first (older data)
          for (var message in unprefixedMessages.values) {
            if (!seenIds.contains(message.id)) {
              seenIds.add(message.id);
              allMessages.add(message);
            }
          }
          
          // Add prefixed messages (newer data)
          for (var message in prefixedMessages.values) {
            if (!seenIds.contains(message.id)) {
              seenIds.add(message.id);
              allMessages.add(message);
            }
          }
          
          // Sort by timestamp
          allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          if (!controller.isClosed) {
            controller.add(allMessages);
          }
        }
        
        // Listen to prefixed stream
        final prefixedSubscription = prefixedStream.listen((snapshot) async {
          try {
            final messages = await _processMessageSnapshot(snapshot, familyId);
            prefixedMessages.clear();
            for (var msg in messages) {
              prefixedMessages[msg.id] = msg;
            }
            prefixedReady = true;
            emitCombined();
          } catch (e) {
            Logger.error('Error processing prefixed messages', error: e, tag: 'ChatService');
          }
        }, onError: (error) {
          Logger.error('Error in prefixed messages stream', error: error, tag: 'ChatService');
          prefixedReady = true; // Mark as ready even on error to allow emission
          emitCombined();
        }, onDone: () {
          if (unprefixedReady && !controller.isClosed) {
            controller.close();
          }
        });
        
        // Listen to unprefixed stream
        final unprefixedSubscription = unprefixedStream.listen((snapshot) async {
          try {
            final messages = await _processMessageSnapshot(snapshot, familyId);
            unprefixedMessages.clear();
            for (var msg in messages) {
              unprefixedMessages[msg.id] = msg;
            }
            unprefixedReady = true;
            emitCombined();
          } catch (e) {
            Logger.error('Error processing unprefixed messages', error: e, tag: 'ChatService');
          }
        }, onError: (error) {
          Logger.error('Error in unprefixed messages stream', error: error, tag: 'ChatService');
          unprefixedReady = true; // Mark as ready even on error to allow emission
          emitCombined();
        }, onDone: () {
          if (prefixedReady && !controller.isClosed) {
            controller.close();
          }
        });
        
        // Clean up when stream is cancelled
        controller.onCancel = () {
          prefixedSubscription.cancel();
          unprefixedSubscription.cancel();
          if (!controller.isClosed) {
            controller.close();
          }
        };
        
        return controller.stream;
      } else {
        return prefixedStream.asyncMap((snapshot) => _processMessageSnapshot(snapshot, familyId));
      }
    }).asBroadcastStream();
    
    return _cachedMessagesStream!;
  }
  
  Future<List<ChatMessage>> _combineMessageSnapshots(List<QuerySnapshot> snapshots, String familyId) async {
    final allMessages = <ChatMessage>[];
    final seenIds = <String>{};
    
    // Process all snapshots
    for (var snapshot in snapshots) {
      for (var doc in snapshot.docs) {
        // Skip duplicates
        if (seenIds.contains(doc.id)) continue;
        seenIds.add(doc.id);
        
      final data = doc.data() as Map<String, dynamic>? ?? {};
      var messageData = {
        'id': doc.id,
        ...data,
      } as Map<String, dynamic>;
      
      // CRITICAL: Filter out private messages (those with recipientId) from family chat
      // Private messages belong in privateMessages/{chatId}/messages, not here
      if (messageData['recipientId'] != null) {
        Logger.warning(
          'Skipping private message in family chat collection: ${doc.id}',
          tag: 'ChatService',
        );
        continue; // Skip this message - it's a private message, not a family chat message
      }
        
        // If senderName is missing, try to get it from user document
        if (messageData['senderName'] == null || 
            (messageData['senderName'] as String).isEmpty) {
          final senderId = messageData['senderId'] as String?;
          if (senderId != null) {
            try {
              // Try prefixed collection first, then unprefixed
              var userDoc = await _firestore.collection(FirestorePathUtils.getUsersCollection()).doc(senderId).get();
              if (!userDoc.exists) {
                userDoc = await _firestore.collection('users').doc(senderId).get();
              }
              
              if (userDoc.exists) {
                final userData = userDoc.data();
                messageData['senderName'] = userData?['displayName'] as String? ?? 
                                             userData?['email'] as String? ?? 
                                             'Unknown User';
              } else {
                messageData['senderName'] = 'Unknown User';
              }
            } catch (e) {
              Logger.warning('Error fetching sender name', error: e, tag: 'ChatService');
              messageData['senderName'] = 'Unknown User';
            }
          } else {
            messageData['senderName'] = 'Unknown User';
          }
        }
        
        allMessages.add(ChatMessage.fromJson(messageData));
      }
    }
    
    // Sort by timestamp
    allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allMessages;
  }
  
  Future<List<ChatMessage>> _processMessageSnapshot(QuerySnapshot snapshot, String familyId) async {
    final messages = <ChatMessage>[];
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      var messageData = {
        'id': doc.id,
        ...data,
      } as Map<String, dynamic>;
      
      // CRITICAL: Filter out private messages (those with recipientId) from family chat
      // Private messages belong in privateMessages/{chatId}/messages, not here
      if (messageData['recipientId'] != null) {
        Logger.warning(
          'Skipping private message in family chat collection: ${doc.id}',
          tag: 'ChatService',
        );
        continue; // Skip this message - it's a private message, not a family chat message
      }
      
      // If senderName or senderPhotoUrl is missing, try to get it from user document
      final senderId = messageData['senderId'] as String?;
      if (senderId != null) {
        try {
          // Try prefixed collection first, then unprefixed
          var userDoc = await _firestore.collection(FirestorePathUtils.getUsersCollection()).doc(senderId).get();
          if (!userDoc.exists) {
            userDoc = await _firestore.collection('users').doc(senderId).get();
          }
          
          if (userDoc.exists) {
            final userData = userDoc.data();
            // Populate senderName if missing
            if (messageData['senderName'] == null || 
                (messageData['senderName'] as String).isEmpty) {
              messageData['senderName'] = userData?['displayName'] as String? ?? 
                                           userData?['email'] as String? ?? 
                                           'Unknown User';
            }
            // Populate senderPhotoUrl if missing (for avatar consistency)
            if (messageData['senderPhotoUrl'] == null || 
                (messageData['senderPhotoUrl'] as String).isEmpty) {
              final photoUrl = userData?['photoUrl'] as String?;
              if (photoUrl != null && photoUrl.isNotEmpty) {
                messageData['senderPhotoUrl'] = photoUrl;
              }
            }
          } else {
            if (messageData['senderName'] == null || 
                (messageData['senderName'] as String).isEmpty) {
              messageData['senderName'] = 'Unknown User';
            }
          }
        } catch (e) {
          Logger.warning('Error fetching sender info', error: e, tag: 'ChatService');
          if (messageData['senderName'] == null || 
              (messageData['senderName'] as String).isEmpty) {
            messageData['senderName'] = 'Unknown User';
          }
        }
      } else {
        if (messageData['senderName'] == null || 
            (messageData['senderName'] as String).isEmpty) {
          messageData['senderName'] = 'Unknown User';
        }
      }
      
      final message = ChatMessage.fromJson(messageData);
      
      // Decrypt message if encrypted
      if (message.isEncrypted && message.encryptedContent != null) {
        if (_encryptedChatService == null) {
          _encryptedChatService = EncryptedChatService();
        }
        try {
          final decryptedContent = await _encryptedChatService!.decryptMessage(message);
          // Create decrypted message copy
          final decryptedMessage = ChatMessage(
            id: message.id,
            senderId: message.senderId,
            senderName: message.senderName,
            content: decryptedContent,
            timestamp: message.timestamp,
            type: message.type,
            recipientId: message.recipientId,
            hubId: message.hubId,
            audioUrl: message.audioUrl,
            reactions: message.reactions,
            threadId: message.threadId,
            parentMessageId: message.parentMessageId,
            replyCount: message.replyCount,
            postType: message.postType,
            pollOptions: message.pollOptions,
            pollExpiresAt: message.pollExpiresAt,
            votedPollOptionId: message.votedPollOptionId,
            likeCount: message.likeCount,
            shareCount: message.shareCount,
            commentCount: message.commentCount,
            visibleHubIds: message.visibleHubIds,
            urlPreview: message.urlPreview,
            senderPhotoUrl: message.senderPhotoUrl,
            isEncrypted: true, // Keep flag for UI indicators
            expiresAt: message.expiresAt,
            encryptedContent: message.encryptedContent,
          );
          messages.add(decryptedMessage);
        } catch (e) {
          Logger.warning('Error decrypting message ${message.id}', error: e, tag: 'ChatService');
          // Add original message with encrypted placeholder
          messages.add(message);
        }
      } else {
        messages.add(message);
      }
    }
    return messages;
  }

  Future<List<ChatMessage>> getMessages({int limit = 50, bool forceRefresh = false}) async {
    final familyId = await _familyId;
    if (familyId == null) {
      Logger.warning('getMessages: User not part of a family', tag: 'ChatService');
      return [];
    }

    // Check cache first (unless force refresh)
    if (!forceRefresh) {
      final queryCache = QueryCacheService();
      // QueryCacheService handles List<Map<String, dynamic>> specially and doesn't use fromJson
      final cachedData = await queryCache.getCachedQueryResult<List<Map<String, dynamic>>>(
        prefix: 'chat_messages',
        queryId: familyId,
        fromJson: (_) => <Map<String, dynamic>>[], // Not used for List<Map> type
      );

      if (cachedData != null && cachedData.isNotEmpty) {
        // Convert cached JSON maps back to ChatMessage objects
        final cachedMessages = cachedData.map((json) {
          try {
            return ChatMessage.fromJson(json);
          } catch (e) {
            Logger.warning('Error parsing cached message', error: e, tag: 'ChatService');
            return null;
          }
        }).whereType<ChatMessage>().toList();

        if (cachedMessages.isNotEmpty) {
          Logger.debug('getMessages: Cache hit for family $familyId - ${cachedMessages.length} messages', tag: 'ChatService');
          return cachedMessages;
        }
      }
    }

    try {
      Logger.debug('getMessages: Loading messages from Firestore for family $familyId', tag: 'ChatService');

      final pageSize = limit.clamp(1, 500);
      final prefix = Config.current.firestorePrefix;
      final prefixedPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'messages');
      final unprefixedPath = 'families/$familyId/messages';
      
      // Query both collections if using prefix
      final allMessages = <ChatMessage>[];
      final seenIds = <String>{};
      
      // Query prefixed collection
      try {
        final prefixedSnapshot = await _firestore
            .collection(prefixedPath)
            .orderBy('timestamp', descending: false)
            .limit(pageSize)
            .get();
        
        final prefixedMessages = await _processMessageSnapshot(prefixedSnapshot, familyId);
        for (var msg in prefixedMessages) {
          if (!seenIds.contains(msg.id)) {
            seenIds.add(msg.id);
            allMessages.add(msg);
          }
        }
      } catch (e) {
        Logger.warning('getMessages: Error querying prefixed collection', error: e, tag: 'ChatService');
      }
      
      // Query unprefixed collection if using prefix (for backward compatibility)
      if (prefix.isNotEmpty) {
        try {
          final unprefixedSnapshot = await _firestore
              .collection(unprefixedPath)
              .orderBy('timestamp', descending: false)
              .limit(pageSize)
              .get();
          
          final unprefixedMessages = await _processMessageSnapshot(unprefixedSnapshot, familyId);
          for (var msg in unprefixedMessages) {
            if (!seenIds.contains(msg.id)) {
              seenIds.add(msg.id);
              allMessages.add(msg);
            }
          }
        } catch (e) {
          // Unprefixed collection might not exist or have index, that's OK
          Logger.debug('getMessages: Could not query unprefixed collection (may not exist)', tag: 'ChatService');
        }
      }
      
      // Sort by timestamp
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Limit to requested page size
      final limitedMessages = allMessages.take(pageSize).toList();

      Logger.debug('getMessages: Successfully loaded ${limitedMessages.length} messages', tag: 'ChatService');

      // Cache the results
      if (!forceRefresh) {
        final queryCache = QueryCacheService();
        // Serialize messages to JSON maps for caching
        final messagesJson = limitedMessages.map((message) {
          final json = message.toJson();
          json['id'] = message.id; // Ensure ID is included
          return json;
        }).toList();

        await queryCache.cacheQueryResult<List<Map<String, dynamic>>>(
          prefix: 'chat_messages',
          queryId: familyId,
          data: messagesJson,
          dataType: DataType.messages,
        );
      }

      return limitedMessages;
    } catch (e, st) {
      Logger.error('getMessages error', error: e, stackTrace: st, tag: 'ChatService');
      return [];
    }
  }

  Future<void> sendMessage(ChatMessage message) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');

    // CRITICAL: Family chat messages must NOT have recipientId (that's for private messages)
    if (message.recipientId != null) {
      throw ValidationException(
        'Family chat messages cannot have recipientId. Use sendPrivateMessage() for private messages.',
        code: 'invalid-message-type',
      );
    }

    try {
      // Use FirestorePathUtils to get the correct prefixed path
      final collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'messages');
      await _firestore.collection(collectionPath).doc(message.id).set(message.toJson());

      // Invalidate cache after successful send
      await _invalidateChatMessagesCache(familyId);
    } catch (e) {
      Logger.error('sendMessage error', error: e, tag: 'ChatService');
      rethrow;
    }
  }

  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentUserName => _auth.currentUser?.displayName;
  
  /// Generate a consistent chat ID from two user IDs (sorted to ensure consistency)
  String _getChatId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
  
  /// Get private messages stream between current user and another user
  Stream<List<ChatMessage>> getPrivateMessagesStream(String otherUserId) {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      return Stream.value(<ChatMessage>[]);
    }
    
    return Stream.fromFuture(_familyId).asyncExpand((familyId) {
      if (familyId == null) {
        return Stream.value(<ChatMessage>[]);
      }
      
      final chatId = _getChatId(currentUserId, otherUserId);
      
      return _firestore
          .collection(FirestorePathUtils.getFamilySubcollectionPath(familyId, 'privateMessages'))
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .asyncMap((snapshot) async {
            final messages = <ChatMessage>[];
            for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      var messageData = {
        'id': doc.id,
        ...data,
      } as Map<String, dynamic>;
              
              // If senderName is missing, try to get it from user document
              if (messageData['senderName'] == null || 
                  (messageData['senderName'] as String).isEmpty) {
                final senderId = messageData['senderId'] as String?;
                if (senderId != null) {
                  try {
                    final userDoc = await _firestore.collection(FirestorePathUtils.getUsersCollection()).doc(senderId).get();
                    if (userDoc.exists) {
                      final userData = userDoc.data();
                      messageData['senderName'] = userData?['displayName'] as String? ?? 
                                                   userData?['email'] as String? ?? 
                                                   'Unknown User';
                    } else {
                      messageData['senderName'] = 'Unknown User';
                    }
                  } catch (e) {
                    Logger.warning('Error fetching sender name', error: e, tag: 'ChatService');
                    messageData['senderName'] = 'Unknown User';
                  }
                } else {
                  messageData['senderName'] = 'Unknown User';
                }
              }
              
              final message = ChatMessage.fromJson(messageData);
              
              // Decrypt message if encrypted
              if (message.isEncrypted && message.encryptedContent != null) {
                if (_encryptedChatService == null) {
                  _encryptedChatService = EncryptedChatService();
                }
                try {
                  final decryptedContent = await _encryptedChatService!.decryptMessage(message);
                  // Create decrypted message copy
                  final decryptedMessage = ChatMessage(
                    id: message.id,
                    senderId: message.senderId,
                    senderName: message.senderName,
                    content: decryptedContent,
                    timestamp: message.timestamp,
                    type: message.type,
                    recipientId: message.recipientId,
                    hubId: message.hubId,
                    audioUrl: message.audioUrl,
                    reactions: message.reactions,
                    threadId: message.threadId,
                    parentMessageId: message.parentMessageId,
                    replyCount: message.replyCount,
                    postType: message.postType,
                    pollOptions: message.pollOptions,
                    pollExpiresAt: message.pollExpiresAt,
                    votedPollOptionId: message.votedPollOptionId,
                    likeCount: message.likeCount,
                    shareCount: message.shareCount,
                    commentCount: message.commentCount,
                    visibleHubIds: message.visibleHubIds,
                    urlPreview: message.urlPreview,
                    senderPhotoUrl: message.senderPhotoUrl,
                    isEncrypted: true, // Keep flag for UI indicators
                    expiresAt: message.expiresAt,
                    encryptedContent: message.encryptedContent,
                  );
                  messages.add(decryptedMessage);
                } catch (e) {
                  Logger.warning('Error decrypting private message', error: e, tag: 'ChatService');
                  // Add message with encrypted placeholder
                  final errorMessage = ChatMessage(
                    id: message.id,
                    senderId: message.senderId,
                    senderName: message.senderName,
                    content: '[Unable to decrypt message]',
                    timestamp: message.timestamp,
                    type: message.type,
                    recipientId: message.recipientId,
                    hubId: message.hubId,
                    isEncrypted: true,
                    encryptedContent: message.encryptedContent,
                  );
                  messages.add(errorMessage);
                }
              } else {
                messages.add(message);
              }
            }
            return messages;
          });
    }).asBroadcastStream();
  }
  
  /// Send a private message to another user
  Future<void> sendPrivateMessage(ChatMessage message, String recipientId) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) {
      throw AuthException('User not logged in', code: 'not-authenticated');
    }
    
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    final chatId = _getChatId(currentUserId, recipientId);
    
    try {
      // Create message with recipientId, preserving ALL fields from original message
      final privateMessage = ChatMessage(
        id: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        content: message.content,
        timestamp: message.timestamp,
        type: message.type,
        recipientId: recipientId,
        hubId: message.hubId,
        audioUrl: message.audioUrl,
        reactions: message.reactions,
        threadId: message.threadId,
        parentMessageId: message.parentMessageId,
        replyCount: message.replyCount,
        postType: message.postType,
        pollOptions: message.pollOptions,
        pollExpiresAt: message.pollExpiresAt,
        votedPollOptionId: message.votedPollOptionId,
        likeCount: message.likeCount,
        shareCount: message.shareCount,
        commentCount: message.commentCount,
        visibleHubIds: message.visibleHubIds,
        urlPreview: message.urlPreview,
        senderPhotoUrl: message.senderPhotoUrl,
        isEncrypted: message.isEncrypted,
        expiresAt: message.expiresAt,
        encryptedContent: message.encryptedContent,
      );
      
      await _firestore
          .collection(FirestorePathUtils.getFamilySubcollectionPath(familyId, 'privateMessages'))
          .doc(chatId)
          .collection('messages')
          .doc(privateMessage.id)
          .set(privateMessage.toJson());
    } catch (e) {
      Logger.error('sendPrivateMessage error', error: e, tag: 'ChatService');
      rethrow;
    }
  }
  
  /// Get the latest message timestamp from a private chat with another user
  /// Returns null if no messages exist
  Future<DateTime?> getLatestMessageTimestamp(String otherUserId) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) return null;
    
    final familyId = await _familyId;
    if (familyId == null) return null;
    
    final chatId = _getChatId(currentUserId, otherUserId);
    
    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getFamilySubcollectionPath(familyId, 'privateMessages'))
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final data = snapshot.docs.first.data();
      final timestampStr = data['timestamp'] as String?;
      if (timestampStr == null) return null;
      
      return DateTime.parse(timestampStr);
    } catch (e) {
      Logger.warning('Error getting latest message timestamp', error: e, tag: 'ChatService');
      return null;
    }
  }
  
  /// Get hub messages stream
  Stream<List<ChatMessage>> getHubMessagesStream(String hubId) {
    return _firestore
        .collection(FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages'))
        .orderBy('timestamp', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
          final messages = <ChatMessage>[];
          for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      var messageData = {
        'id': doc.id,
        ...data,
      } as Map<String, dynamic>;
            
            // If senderName is missing, try to get it from user document
            if (messageData['senderName'] == null || 
                (messageData['senderName'] as String).isEmpty) {
              final senderId = messageData['senderId'] as String?;
              if (senderId != null) {
                try {
                  final userDoc = await _firestore.collection(FirestorePathUtils.getUsersCollection()).doc(senderId).get();
                  if (userDoc.exists) {
                    final userData = userDoc.data();
                    messageData['senderName'] = userData?['displayName'] as String? ?? 
                                                 userData?['email'] as String? ?? 
                                                 'Unknown User';
                  } else {
                    messageData['senderName'] = 'Unknown User';
                  }
                } catch (e) {
                  Logger.warning('Error fetching sender name', error: e, tag: 'ChatService');
                  messageData['senderName'] = 'Unknown User';
                }
              } else {
                messageData['senderName'] = 'Unknown User';
              }
            }
            
            messages.add(ChatMessage.fromJson(messageData));
          }
          return messages;
        }).asBroadcastStream();
  }

  /// Load more messages with pagination
  Future<List<ChatMessage>> loadMoreMessages({
    required DocumentSnapshot lastDoc,
    int limit = 50,
  }) async {
    final familyId = await _familyId;
    if (familyId == null) return [];

    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getFamilySubcollectionPath(familyId, 'messages'))
          .orderBy('timestamp', descending: false)
          .startAfterDocument(lastDoc)
          .limit(limit)
          .get();

      final messages = <ChatMessage>[];
      for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      var messageData = {
        'id': doc.id,
        ...data,
      } as Map<String, dynamic>;

      // CRITICAL: Filter out private messages (those with recipientId) from family chat
      // Private messages belong in privateMessages/{chatId}/messages, not here
      if (messageData['recipientId'] != null) {
        Logger.warning(
          'Skipping private message in family chat collection: ${doc.id}',
          tag: 'ChatService',
        );
        continue; // Skip this message - it's a private message, not a family chat message
      }

        // If senderName is missing, try to get it from user document
        if (messageData['senderName'] == null ||
            (messageData['senderName'] as String).isEmpty) {
          final senderId = messageData['senderId'] as String?;
          if (senderId != null) {
            try {
              final userDoc = await _firestore.collection(FirestorePathUtils.getUsersCollection()).doc(senderId).get();
              if (userDoc.exists) {
                final userData = userDoc.data();
                messageData['senderName'] = userData?['displayName'] as String? ??
                                             userData?['email'] as String? ??
                                             'Unknown User';
              } else {
                messageData['senderName'] = 'Unknown User';
              }
            } catch (e) {
              Logger.warning('Error fetching sender name', error: e, tag: 'ChatService');
              messageData['senderName'] = 'Unknown User';
            }
          } else {
            messageData['senderName'] = 'Unknown User';
          }
        }

        messages.add(ChatMessage.fromJson(messageData));
      }

      return messages;
    } catch (e) {
      Logger.error('loadMoreMessages error', error: e, tag: 'ChatService');
      return [];
    }
  }

  /// Send a message to a hub
  Future<void> sendHubMessage(String hubId, ChatMessage message) async {
    try {
      // Use getHubSubcollectionPath to match Firestore rules and other services
      final collectionPath = FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages');
      // Use doc().set() with message.id to preserve the ID (like FeedService does)
      await _firestore.collection(collectionPath).doc(message.id).set(message.toJson());
    } catch (e) {
      Logger.error('sendHubMessage error', error: e, tag: 'ChatService');
      rethrow;
    }
  }

  /// Check if there are unread messages from another user
  /// This is a simple check - we consider messages unread if they exist
  /// and were sent by the other user (not by current user)
  Future<bool> hasUnreadMessages(String otherUserId) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) return false;
    
    final familyId = await _familyId;
    if (familyId == null) return false;
    
    final chatId = _getChatId(currentUserId, otherUserId);
    
    try {
      // Get the latest message
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getFamilySubcollectionPath(familyId, 'privateMessages'))
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return false;
      
      final data = snapshot.docs.first.data();
      final senderId = data['senderId'] as String?;
      
      // Message is unread if it's from the other user (not from current user)
      // But we need to check if it's been read
      if (senderId == otherUserId) {
        final timestampStr = data['timestamp'] as String?;
        if (timestampStr != null) {
          final messageTime = DateTime.parse(timestampStr);
          
          // Get the last read timestamp
          final lastRead = await getLastReadTimestamp(otherUserId);
          
          // If no read timestamp exists, or message is newer than last read, it's unread
          if (lastRead == null || messageTime.isAfter(lastRead)) {
            return true;
          }
        } else {
          // If timestamp is missing, assume unread if from other user
          return true;
        }
      }
      
      return false;
    } catch (e) {
      Logger.warning('Error checking unread messages', error: e, tag: 'ChatService');
      return false;
    }
  }
  
  /// Mark messages as read for a chat with another user
  /// This updates the last read timestamp for the current user
  Future<void> markMessagesAsRead(String otherUserId) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) return;
    
    final familyId = await _familyId;
    if (familyId == null) return;
    
    final chatId = _getChatId(currentUserId, otherUserId);
    final now = DateTime.now().toIso8601String();
    
    try {
      // Store the last read timestamp for this user in this chat
      await _firestore
          .collection(FirestorePathUtils.getFamilySubcollectionPath(familyId, 'privateMessages'))
          .doc(chatId)
          .collection('readStatus')
          .doc(currentUserId)
          .set({
        'lastReadAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
      
      Logger.debug('Marked messages as read for chat $chatId by user $currentUserId', tag: 'ChatService');
    } catch (e) {
      Logger.error('Error marking messages as read', error: e, tag: 'ChatService');
    }
  }
  
  /// Get the last read timestamp for a chat with another user
  Future<DateTime?> getLastReadTimestamp(String otherUserId) async {
    final currentUserId = this.currentUserId;
    if (currentUserId == null) return null;
    
    final familyId = await _familyId;
    if (familyId == null) return null;
    
    final chatId = _getChatId(currentUserId, otherUserId);
    
    try {
      final doc = await _firestore
          .collection(FirestorePathUtils.getFamilySubcollectionPath(familyId, 'privateMessages'))
          .doc(chatId)
          .collection('readStatus')
          .doc(currentUserId)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data();
      final lastReadStr = data?['lastReadAt'] as String?;
      if (lastReadStr == null) return null;
      
      return DateTime.parse(lastReadStr);
    } catch (e) {
      Logger.warning('Error getting last read timestamp', error: e, tag: 'ChatService');
      return null;
    }
  }
}
