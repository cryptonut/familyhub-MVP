import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/logger_service.dart';
import '../models/chat_message.dart';
import '../utils/firestore_path_utils.dart';

/// Service for managing auto-destruct messages
class MessageExpirationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _expirationTimer;

  /// Start monitoring for expired messages
  void startMonitoring() {
    // Check for expired messages every minute
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndDeleteExpiredMessages();
    });
    
    Logger.info('Message expiration monitoring started', tag: 'MessageExpirationService');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _expirationTimer?.cancel();
    _expirationTimer = null;
    Logger.info('Message expiration monitoring stopped', tag: 'MessageExpirationService');
  }

  /// Check and delete expired messages
  Future<void> _checkAndDeleteExpiredMessages() async {
    try {
      final now = DateTime.now();
      
      // Query messages with expiration dates in the past
      // Note: This requires a Firestore index on 'expiresAt'
      final prefixedPath = FirestorePathUtils.getCollectionPath('messages');
      final unprefixedPath = 'messages';
      
      // Query prefixed collection
      try {
        final expiredSnapshot = await _firestore
            .collection(prefixedPath)
            .where('expiresAt', isLessThan: now.toIso8601String())
            .where('isEncrypted', isEqualTo: true)
            .limit(50) // Process in batches
            .get();

        for (var doc in expiredSnapshot.docs) {
          await _deleteExpiredMessage(doc.reference);
        }
      } catch (e) {
        Logger.warning('Error querying prefixed collection for expired messages', error: e, tag: 'MessageExpirationService');
      }

      // Query unprefixed collection if different
      if (prefixedPath != unprefixedPath) {
        try {
          final expiredSnapshot = await _firestore
              .collection(unprefixedPath)
              .where('expiresAt', isLessThan: now.toIso8601String())
              .where('isEncrypted', isEqualTo: true)
              .limit(50)
              .get();

          for (var doc in expiredSnapshot.docs) {
            await _deleteExpiredMessage(doc.reference);
          }
        } catch (e) {
          Logger.warning('Error querying unprefixed collection for expired messages', error: e, tag: 'MessageExpirationService');
        }
      }
    } catch (e) {
      Logger.error('Error checking expired messages', error: e, tag: 'MessageExpirationService');
    }
  }

  /// Delete an expired message
  Future<void> _deleteExpiredMessage(DocumentReference messageRef) async {
    try {
      await messageRef.delete();
      Logger.debug('Deleted expired message: ${messageRef.id}', tag: 'MessageExpirationService');
    } catch (e) {
      Logger.warning('Error deleting expired message', error: e, tag: 'MessageExpirationService');
    }
  }

  /// Set expiration for a message
  Future<void> setMessageExpiration({
    required String messageId,
    required DateTime expiresAt,
    required String familyId,
    String? hubId,
  }) async {
    try {
      final collectionPath = hubId != null
          ? FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages')
          : FirestorePathUtils.getFamilySubcollectionPath(familyId, 'messages');

      await _firestore
          .collection(collectionPath)
          .doc(messageId)
          .update({
        'expiresAt': expiresAt.toIso8601String(),
        'isEncrypted': true,
      });

      Logger.info('Message expiration set: $messageId expires at $expiresAt', tag: 'MessageExpirationService');
    } catch (e) {
      Logger.error('Error setting message expiration', error: e, tag: 'MessageExpirationService');
      rethrow;
    }
  }

  /// Get time remaining until expiration
  Duration? getTimeRemaining(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Check if message is expired
  bool isExpired(DateTime? expiresAt) {
    if (expiresAt == null) return false;
    return expiresAt.isBefore(DateTime.now());
  }
}


