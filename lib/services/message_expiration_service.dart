import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/logger_service.dart';
import '../utils/firestore_path_utils.dart';
import '../config/config.dart';

/// Service for managing auto-destruct messages
/// Periodically checks for expired messages and deletes them
class MessageExpirationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _expirationCheckTimer;
  
  /// Start periodic expiration checks
  /// Checks every 5 minutes for expired messages
  void startExpirationChecks() {
    // Stop existing timer if any
    _expirationCheckTimer?.cancel();
    
    // Check immediately
    _checkExpiredMessages();
    
    // Then check every 5 minutes
    _expirationCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkExpiredMessages(),
    );
    
    Logger.info('Message expiration checks started', tag: 'MessageExpirationService');
  }
  
  /// Stop expiration checks
  void stopExpirationChecks() {
    _expirationCheckTimer?.cancel();
    _expirationCheckTimer = null;
    Logger.info('Message expiration checks stopped', tag: 'MessageExpirationService');
  }
  
  /// Check for and delete expired messages
  Future<void> _checkExpiredMessages() async {
    try {
      final now = DateTime.now();
      final prefix = Config.current.firestorePrefix;
      
      // Check family messages
      await _checkFamilyMessages(now, prefix);
      
      // Check hub messages
      await _checkHubMessages(now, prefix);
      
      Logger.debug('Expired messages check completed', tag: 'MessageExpirationService');
    } catch (e) {
      Logger.error('Error checking expired messages', error: e, tag: 'MessageExpirationService');
    }
  }
  
  /// Check and delete expired family messages
  Future<void> _checkFamilyMessages(DateTime now, String prefix) async {
    try {
      // Query families collection
      final familiesSnapshot = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('families'))
          .limit(100) // Process in batches
          .get();
      
      for (var familyDoc in familiesSnapshot.docs) {
        final familyId = familyDoc.id;
        final messagesPath = FirestorePathUtils.getFamilySubcollectionPath(familyId, 'messages');
        
        // Query messages with expiration before now
        final expiredMessages = await _firestore
            .collection(messagesPath)
            .where('expiresAt', isLessThan: Timestamp.fromDate(now))
            .where('isEncrypted', isEqualTo: true)
            .limit(500) // Firestore batch limit
            .get();
        
        if (expiredMessages.docs.isNotEmpty) {
          // Delete expired messages in batches
          final batch = _firestore.batch();
          var batchCount = 0;
          
          for (var doc in expiredMessages.docs) {
            batch.delete(doc.reference);
            batchCount++;
            
            // Commit batch every 500 operations
            if (batchCount >= 500) {
              await batch.commit();
              batchCount = 0;
            }
          }
          
          if (batchCount > 0) {
            await batch.commit();
          }
          
          Logger.info(
            'Deleted ${expiredMessages.docs.length} expired messages from family $familyId',
            tag: 'MessageExpirationService',
          );
        }
      }
    } catch (e) {
      Logger.error('Error checking family messages', error: e, tag: 'MessageExpirationService');
    }
  }
  
  /// Check and delete expired hub messages
  Future<void> _checkHubMessages(DateTime now, String prefix) async {
    try {
      // Query hubs collection
      final hubsSnapshot = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('hubs'))
          .limit(100) // Process in batches
          .get();
      
      for (var hubDoc in hubsSnapshot.docs) {
        final hubId = hubDoc.id;
        final messagesPath = FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages');
        
        // Query messages with expiration before now
        final expiredMessages = await _firestore
            .collection(messagesPath)
            .where('expiresAt', isLessThan: Timestamp.fromDate(now))
            .where('isEncrypted', isEqualTo: true)
            .limit(500) // Firestore batch limit
            .get();
        
        if (expiredMessages.docs.isNotEmpty) {
          // Delete expired messages in batches
          final batch = _firestore.batch();
          var batchCount = 0;
          
          for (var doc in expiredMessages.docs) {
            batch.delete(doc.reference);
            batchCount++;
            
            // Commit batch every 500 operations
            if (batchCount >= 500) {
              await batch.commit();
              batchCount = 0;
            }
          }
          
          if (batchCount > 0) {
            await batch.commit();
          }
          
          Logger.info(
            'Deleted ${expiredMessages.docs.length} expired messages from hub $hubId',
            tag: 'MessageExpirationService',
          );
        }
      }
    } catch (e) {
      Logger.error('Error checking hub messages', error: e, tag: 'MessageExpirationService');
    }
  }
  
  /// Manually check and delete expired messages for a specific conversation
  Future<void> checkConversationExpiredMessages(String conversationId, {String? hubId}) async {
    try {
      final now = DateTime.now();
      final messagesPath = hubId != null
          ? FirestorePathUtils.getHubSubcollectionPath(hubId, 'messages')
          : FirestorePathUtils.getFamilySubcollectionPath(conversationId, 'messages');
      
      final expiredMessages = await _firestore
          .collection(messagesPath)
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .where('isEncrypted', isEqualTo: true)
          .get();
      
      if (expiredMessages.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in expiredMessages.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        
        Logger.info(
          'Deleted ${expiredMessages.docs.length} expired messages from conversation $conversationId',
          tag: 'MessageExpirationService',
        );
      }
    } catch (e) {
      Logger.error(
        'Error checking conversation expired messages',
        error: e,
        tag: 'MessageExpirationService',
      );
    }
  }
  
  /// Calculate expiration time from duration
  static DateTime calculateExpiration(DateTime now, Duration duration) {
    return now.add(duration);
  }
  
  /// Get remaining time until expiration
  static Duration? getRemainingTime(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) return Duration.zero;
    return expiresAt.difference(now);
  }
  
  /// Format remaining time as human-readable string
  static String formatRemainingTime(Duration? remaining) {
    if (remaining == null) return '';
    if (remaining.inDays > 0) {
      return '${remaining.inDays}d ${remaining.inHours % 24}h';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m';
    } else {
      return '${remaining.inSeconds}s';
    }
  }
}
