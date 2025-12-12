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
  Future<void> addReaction(String messageId, String emoji, String familyId, {String? chatId}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if user already reacted with this emoji
      final existingReaction = await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection(chatId != null ? 'privateMessages' : 'messages')
          .doc(chatId ?? messageId)
          .collection(chatId != null ? 'messages' : 'reactions')
          .doc(chatId != null ? messageId : '${userId}_$emoji')
          .get();

      if (existingReaction.exists) {
        // Remove existing reaction (toggle off)
        await existingReaction.reference.delete();
        Logger.info('Reaction removed: $emoji', tag: 'MessageReactionService');
        return;
      }

      // Add new reaction
      final reactionId = chatId != null
          ? const Uuid().v4()
          : '${userId}_$emoji';

      final reaction = MessageReaction(
        id: reactionId,
        messageId: messageId,
        emoji: emoji,
        userId: userId,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection(chatId != null ? 'privateMessages' : 'messages')
          .doc(chatId ?? messageId)
          .collection(chatId != null ? 'messages' : 'reactions')
          .doc(chatId != null ? reactionId : '${userId}_$emoji')
          .set(reaction.toJson());

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

