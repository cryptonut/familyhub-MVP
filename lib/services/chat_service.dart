import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/chat_message.dart';
import 'auth_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  
  String? _cachedFamilyId;
  
  Future<String?> get _familyId async {
    if (_cachedFamilyId != null) return _cachedFamilyId;
    
    final userModel = await _authService.getCurrentUserModel();
    _cachedFamilyId = userModel?.familyId;
    return _cachedFamilyId;
  }

  Future<String> get _collectionPath async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    return 'families/$familyId/messages';
  }

  Stream<List<ChatMessage>> getMessagesStream() {
    return Stream.fromFuture(_familyId).asyncExpand((familyId) {
      if (familyId == null) {
        return Stream.value(<ChatMessage>[]);
      }
      
      return _firestore
          .collection('families/$familyId/messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .asyncMap((snapshot) async {
            // Process messages and ensure senderName is populated
            final messages = <ChatMessage>[];
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
                    final userDoc = await _firestore.collection('users').doc(senderId).get();
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
          });
    });
  }

  Future<List<ChatMessage>> getMessages() async {
    final familyId = await _familyId;
    if (familyId == null) return [];
    
    final snapshot = await _firestore
        .collection('families/$familyId/messages')
        .orderBy('timestamp', descending: false)
        .get();
    
    // Process messages and ensure senderName is populated
    final messages = <ChatMessage>[];
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
            final userDoc = await _firestore.collection('users').doc(senderId).get();
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
  }

  Future<void> sendMessage(ChatMessage message) async {
    final familyId = await _familyId;
    if (familyId == null) throw AuthException('User not part of a family', code: 'no-family');
    
    try {
      await _firestore.collection('families/$familyId/messages').add(message.toJson());
    } catch (e) {
      Logger.error('sendMessage error', error: e, tag: 'ChatService');
      Logger.debug('Family ID: $familyId', tag: 'ChatService');
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
          .collection('families/$familyId/privateMessages')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .asyncMap((snapshot) async {
            final messages = <ChatMessage>[];
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
                    final userDoc = await _firestore.collection('users').doc(senderId).get();
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
          });
    });
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
      // Create message with recipientId
      final privateMessage = ChatMessage(
        id: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        content: message.content,
        timestamp: message.timestamp,
        type: message.type,
        recipientId: recipientId,
        audioUrl: message.audioUrl,
      );
      
      await _firestore
          .collection('families/$familyId/privateMessages')
          .doc(chatId)
          .collection('messages')
          .add(privateMessage.toJson());
    } catch (e) {
      Logger.error('sendPrivateMessage error', error: e, tag: 'ChatService');
      Logger.debug('Family ID: $familyId, Chat ID: $chatId', tag: 'ChatService');
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
          .collection('families/$familyId/privateMessages')
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
          .collection('families/$familyId/privateMessages')
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
          .collection('families/$familyId/privateMessages')
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
          .collection('families/$familyId/privateMessages')
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
