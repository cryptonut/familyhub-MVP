import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../models/chat_message.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';
import 'package:uuid/uuid.dart';

class MessageThreadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  /// Reply to a message (creates a thread)
  Future<ChatMessage> replyToMessage(
    String messageId,
    String text,
    String familyId, {
    String? chatId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final userModel = await _authService.getCurrentUserModel();
      final senderName = userModel?.displayName ?? 'Unknown';

      // Get parent message to determine threadId
      final parentDoc = await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection(chatId != null ? 'privateMessages' : 'messages')
          .doc(chatId ?? messageId)
          .collection(chatId != null ? 'messages' : '')
          .doc(chatId != null ? messageId : messageId)
          .get();

      final threadId = parentDoc.data()?['threadId'] as String? ?? messageId;

      // Create reply message
      final replyId = const Uuid().v4();
      final reply = ChatMessage(
        id: replyId,
        senderId: userId,
        senderName: senderName,
        content: text,
        timestamp: DateTime.now(),
        threadId: threadId,
        parentMessageId: messageId,
      );

      // Save reply
      await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection(chatId != null ? 'privateMessages' : 'messages')
          .doc(chatId ?? messageId)
          .collection(chatId != null ? 'messages' : 'replies')
          .doc(replyId)
          .set(reply.toJson());

      // Update parent message reply count
      await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection(chatId != null ? 'privateMessages' : 'messages')
          .doc(chatId ?? messageId)
          .collection(chatId != null ? 'messages' : '')
          .doc(chatId != null ? messageId : messageId)
          .update({
        'replyCount': FieldValue.increment(1),
      });

      Logger.info('Reply created: $replyId', tag: 'MessageThreadService');
      return reply;
    } catch (e, st) {
      Logger.error('Error replying to message', error: e, stackTrace: st, tag: 'MessageThreadService');
      rethrow;
    }
  }

  /// Get thread replies
  Stream<List<ChatMessage>> watchThreadReplies(
    String messageId,
    String familyId, {
    String? chatId,
  }) {
    final threadId = chatId ?? messageId;
    
    return _firestore
        .collection(FirestorePathUtils.getFamiliesCollection())
        .doc(familyId)
        .collection(chatId != null ? 'privateMessages' : 'messages')
        .doc(chatId ?? messageId)
        .collection(chatId != null ? 'messages' : 'replies')
        .where('threadId', isEqualTo: threadId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    });
  }

  /// Get thread replies (one-time)
  Future<List<ChatMessage>> getThreadReplies(
    String messageId,
    String familyId, {
    String? chatId,
  }) async {
    try {
      final threadId = chatId ?? messageId;
      
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getFamiliesCollection())
          .doc(familyId)
          .collection(chatId != null ? 'privateMessages' : 'messages')
          .doc(chatId ?? messageId)
          .collection(chatId != null ? 'messages' : 'replies')
          .where('threadId', isEqualTo: threadId)
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => ChatMessage.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e, st) {
      Logger.error('Error getting thread replies', error: e, stackTrace: st, tag: 'MessageThreadService');
      return [];
    }
  }
}

