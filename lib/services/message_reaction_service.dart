import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../models/message_reaction.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'package:uuid/uuid.dart';

class MessageReactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  /// Add a reaction to a message
  /// chatId can be a hubId (for hub messages) or a private chat ID
  Future<void> addReaction(String messageId, String emoji, String familyId, {String? chatId}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Determine if this is a hub message
      // Hub IDs are typically UUIDs without underscores, private chat IDs have format like "userId1_userId2"
      final isHubMessage = chatId != null && !chatId.contains('_') && chatId.length > 20;
      
      String collectionPath;
      String docPath;
      String reactionsPath;
      String reactionDocId;

      if (isHubMessage) {
        // Hub message: hubs/{hubId}/messages/{messageId}/reactions/{userId}_{emoji}
        collectionPath = FirestorePathUtils.getHubSubcollectionPath(chatId!, 'messages');
        docPath = messageId;
        reactionsPath = 'reactions';
        reactionDocId = '${userId}_$emoji';
      } else if (chatId != null) {
        // Private message: families/{familyId}/privateMessages/{chatId}/messages/{messageId}/reactions
        collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'privateMessages');
        docPath = chatId;
        reactionsPath = 'messages';
        reactionDocId = messageId;
        // For private messages, reactions are stored differently
        final privateMsgPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'privateMessages/$chatId/messages');
        final existingReaction = await _firestore
            .collection(privateMsgPath)
            .doc(messageId)
            .collection('reactions')
            .doc('${userId}_$emoji')
            .get();
        
        if (existingReaction.exists) {
          await existingReaction.reference.delete();
          
          // Update likeCount on the message document
          if (emoji == '❤️') {
            await _firestore
                .collection(privateMsgPath)
                .doc(messageId)
                .update({
              'likeCount': FieldValue.increment(-1),
            });
          }
          
          Logger.info('Reaction removed: $emoji', tag: 'MessageReactionService');
          return;
        }
        
        final reaction = MessageReaction(
          id: '${userId}_$emoji',
          messageId: messageId,
          emoji: emoji,
          userId: userId,
          createdAt: DateTime.now(),
        );
        
        await _firestore
            .collection(privateMsgPath)
            .doc(messageId)
            .collection('reactions')
            .doc('${userId}_$emoji')
            .set(reaction.toJson());
        
        // Update likeCount on the message document
        if (emoji == '❤️') {
          await _firestore
              .collection(privateMsgPath)
              .doc(messageId)
              .update({
            'likeCount': FieldValue.increment(1),
          });
        }
        
        Logger.info('Reaction added: $emoji', tag: 'MessageReactionService');
        return;
      } else {
        // Family message: families/{familyId}/messages/{messageId}/reactions/{userId}_{emoji}
        collectionPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'messages');
        docPath = messageId;
        reactionsPath = 'reactions';
        reactionDocId = '${userId}_$emoji';
      }

      // Check if user already reacted with this emoji
      final existingReaction = await _firestore
          .collection(collectionPath)
          .doc(docPath)
          .collection(reactionsPath)
          .doc(reactionDocId)
          .get();

      if (existingReaction.exists) {
        // Remove existing reaction (toggle off)
        await existingReaction.reference.delete();
        
        // Update likeCount on the message document
        if (emoji == '❤️') {
          await _firestore
              .collection(collectionPath)
              .doc(docPath)
              .update({
            'likeCount': FieldValue.increment(-1),
          });
        }
        
        Logger.info('Reaction removed: $emoji', tag: 'MessageReactionService');
        return;
      }

      // Add new reaction
      final reaction = MessageReaction(
        id: reactionDocId,
        messageId: messageId,
        emoji: emoji,
        userId: userId,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(collectionPath)
          .doc(docPath)
          .collection(reactionsPath)
          .doc(reactionDocId)
          .set(reaction.toJson());

      // Update likeCount on the message document
      if (emoji == '❤️') {
        await _firestore
            .collection(collectionPath)
            .doc(docPath)
            .update({
          'likeCount': FieldValue.increment(1),
        });
      }

      Logger.info('Reaction added: $emoji', tag: 'MessageReactionService');
    } catch (e, st) {
      Logger.error('Error adding reaction', error: e, stackTrace: st, tag: 'MessageReactionService');
      rethrow;
    }
  }

  /// Remove a reaction
  Future<void> removeReaction(String messageId, String emoji, String familyId, {String? chatId}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection(chatId != null ? 'privateMessages' : 'messages')
          .doc(chatId ?? messageId)
          .collection(chatId != null ? 'messages' : 'reactions')
          .doc(chatId != null ? messageId : '${userId}_$emoji')
          .delete();

      Logger.info('Reaction removed: $emoji', tag: 'MessageReactionService');
    } catch (e, st) {
      Logger.error('Error removing reaction', error: e, stackTrace: st, tag: 'MessageReactionService');
      rethrow;
    }
  }

  /// Get reactions for a message
  Stream<List<MessageReaction>> watchReactions(String messageId, String familyId, {String? chatId}) {
    return _firestore
        .collection(FirestorePathUtils.getFamiliesCollection())
        .doc(familyId)
        .collection(chatId != null ? 'privateMessages' : 'messages')
        .doc(chatId ?? messageId)
        .collection(chatId != null ? 'messages' : 'reactions')
        .where('messageId', isEqualTo: messageId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageReaction.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    });
  }

  /// Get reaction count by emoji
  Future<Map<String, int>> getReactionCounts(String messageId, String familyId, {String? chatId}) async {
    try {
      final reactions = await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection(chatId != null ? 'privateMessages' : 'messages')
          .doc(chatId ?? messageId)
          .collection(chatId != null ? 'messages' : 'reactions')
          .where('messageId', isEqualTo: messageId)
          .get();

      final counts = <String, int>{};
      for (var doc in reactions.docs) {
        final emoji = doc.data()['emoji'] as String;
        counts[emoji] = (counts[emoji] ?? 0) + 1;
      }

      return counts;
    } catch (e, st) {
      Logger.error('Error getting reaction counts', error: e, stackTrace: st, tag: 'MessageReactionService');
      return {};
    }
  }
}

