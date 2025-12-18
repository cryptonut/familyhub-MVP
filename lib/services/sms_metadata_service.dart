import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sms_message.dart';
import '../models/sms_conversation.dart';
import '../utils/firestore_path_utils.dart';
import '../utils/phone_number_utils.dart';
import '../core/services/logger_service.dart';
import 'auth_service.dart';

/// Service for syncing SMS metadata to Firestore (hybrid approach)
class SmsMetadataService {
  static const String _tag = 'SmsMetadataService';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  /// Sync conversation metadata to Firestore
  Future<void> syncConversationMetadata(SmsConversation conversation) async {
    try {
      final currentUser = await _authService.getCurrentUserModel();
      if (currentUser == null) {
        Logger.warning('No current user for SMS metadata sync', tag: _tag);
        return;
      }
      
      final conversationPath = FirestorePathUtils.getUserSubcollectionPath(
        currentUser.uid,
        'sms_conversations',
      );
      
      // Use normalized phone number as document ID
      final docRef = _firestore
          .doc('$conversationPath/${conversation.normalizedPhoneNumber}');
      
      await docRef.set(conversation.toJson(), SetOptions(merge: true));
      
      Logger.debug('Synced conversation metadata: ${conversation.normalizedPhoneNumber}', tag: _tag);
    } catch (e) {
      Logger.error('Error syncing conversation metadata', error: e, tag: _tag);
      rethrow;
    }
  }
  
  /// Get synced conversations from Firestore
  Future<List<SmsConversation>> getSyncedConversations() async {
    try {
      final currentUser = await _authService.getCurrentUserModel();
      if (currentUser == null) {
        Logger.warning('No current user for SMS metadata sync', tag: _tag);
        return [];
      }
      
      final conversationPath = FirestorePathUtils.getUserSubcollectionPath(
        currentUser.uid,
        'sms_conversations',
      );
      
      final snapshot = await _firestore.collection(conversationPath).get();
      
      final conversations = snapshot.docs.map((doc) {
        try {
          return SmsConversation.fromJson({
            'id': doc.id,
            ...doc.data(),
          });
        } catch (e) {
          Logger.warning('Error parsing conversation ${doc.id}', error: e, tag: _tag);
          return null;
        }
      }).whereType<SmsConversation>().toList();
      
      Logger.debug('Retrieved ${conversations.length} synced conversations', tag: _tag);
      return conversations;
    } catch (e) {
      Logger.error('Error getting synced conversations', error: e, tag: _tag);
      return [];
    }
  }
  
  /// Sync message metadata to Firestore
  Future<void> syncMessageMetadata(SmsMessage message) async {
    try {
      final currentUser = await _authService.getCurrentUserModel();
      if (currentUser == null) {
        Logger.warning('No current user for SMS metadata sync', tag: _tag);
        return;
      }
      
      final conversationPath = FirestorePathUtils.getUserSubcollectionPath(
        currentUser.uid,
        'sms_conversations',
      );
      
      final messagePath = '$conversationPath/${message.normalizedPhoneNumber ?? message.phoneNumber}/messages';
      
      // Use message ID as document ID
      final docRef = _firestore.doc('$messagePath/${message.id}');
      
      await docRef.set(message.toJson(), SetOptions(merge: true));
      
      Logger.debug('Synced message metadata: ${message.id}', tag: _tag);
    } catch (e) {
      Logger.error('Error syncing message metadata', error: e, tag: _tag);
      // Don't rethrow - message sync failures shouldn't block the app
    }
  }
  
  /// Delete conversation metadata from Firestore
  Future<void> deleteConversationMetadata(String phoneNumber) async {
    try {
      final currentUser = await _authService.getCurrentUserModel();
      if (currentUser == null) {
        Logger.warning('No current user for SMS metadata sync', tag: _tag);
        return;
      }
      
      final normalizedPhone = PhoneNumberUtils.normalizePhoneNumber(phoneNumber);
      if (normalizedPhone == null) {
        Logger.warning('Could not normalize phone number: $phoneNumber', tag: _tag);
        return;
      }
      
      final conversationPath = FirestorePathUtils.getUserSubcollectionPath(
        currentUser.uid,
        'sms_conversations',
      );
      
      final docRef = _firestore.doc('$conversationPath/$normalizedPhone');
      
      // Delete conversation and all messages
      final batch = _firestore.batch();
      batch.delete(docRef);
      
      // Delete all messages in subcollection
      final messagesSnapshot = await docRef.collection('messages').get();
      for (final messageDoc in messagesSnapshot.docs) {
        batch.delete(messageDoc.reference);
      }
      
      await batch.commit();
      
      Logger.info('Deleted conversation metadata: $normalizedPhone', tag: _tag);
    } catch (e) {
      Logger.error('Error deleting conversation metadata', error: e, tag: _tag);
      rethrow;
    }
  }
  
  /// Batch sync multiple conversations
  Future<void> batchSyncConversations(List<SmsConversation> conversations) async {
    try {
      final currentUser = await _authService.getCurrentUserModel();
      if (currentUser == null) {
        Logger.warning('No current user for SMS metadata sync', tag: _tag);
        return;
      }
      
      final conversationPath = FirestorePathUtils.getUserSubcollectionPath(
        currentUser.uid,
        'sms_conversations',
      );
      
      var batch = _firestore.batch();
      int count = 0;
      
      for (final conversation in conversations) {
        final docRef = _firestore
            .doc('$conversationPath/${conversation.normalizedPhoneNumber}');
        batch.set(docRef, conversation.toJson(), SetOptions(merge: true));
        count++;
        
        // Firestore batch limit is 500
        if (count >= 500) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }
      
      if (count > 0) {
        await batch.commit();
      }
      
      Logger.info('Batch synced ${conversations.length} conversations', tag: _tag);
    } catch (e) {
      Logger.error('Error batch syncing conversations', error: e, tag: _tag);
      rethrow;
    }
  }
}

