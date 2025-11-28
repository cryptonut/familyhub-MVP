import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/logger_service.dart';
import '../../core/errors/app_exceptions.dart';

/// Migration service to add birthday field to existing users
/// This is a one-time migration that can be run manually or via Cloud Function
class BirthdayMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Migrate all users to add birthday field (if missing)
  /// This is safe to run multiple times - it only adds the field if it doesn't exist
  Future<void> migrateAllUsers() async {
    try {
      Logger.info('Starting birthday migration...', tag: 'BirthdayMigration');
      
      final usersSnapshot = await _firestore.collection('users').get();
      int updatedCount = 0;
      
      final batch = _firestore.batch();
      int batchCount = 0;
      const maxBatchSize = 500; // Firestore batch limit
      
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        
        // Only update if birthdayNotificationsEnabled is missing
        if (!data.containsKey('birthdayNotificationsEnabled')) {
          batch.update(doc.reference, {
            'birthdayNotificationsEnabled': true,
          });
          batchCount++;
          updatedCount++;
          
          // Commit batch if it reaches the limit
          if (batchCount >= maxBatchSize) {
            await batch.commit();
            batchCount = 0;
            Logger.info('Migrated batch of $maxBatchSize users...', tag: 'BirthdayMigration');
          }
        }
      }
      
      // Commit remaining updates
      if (batchCount > 0) {
        await batch.commit();
      }
      
      Logger.info('Birthday migration completed. Updated $updatedCount users.', tag: 'BirthdayMigration');
    } catch (e, st) {
      Logger.error('Error during birthday migration', error: e, stackTrace: st, tag: 'BirthdayMigration');
      rethrow;
    }
  }

  /// Migrate a single user (useful for on-demand updates)
  Future<void> migrateUser(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        throw FirestoreException('User not found: $userId', code: 'not-found');
      }
      
      final data = userDoc.data();
      if (data == null) return;
      
      // Only update if birthdayNotificationsEnabled is missing
      if (!data.containsKey('birthdayNotificationsEnabled')) {
        await userRef.update({
          'birthdayNotificationsEnabled': true,
        });
        Logger.info('Migrated user: $userId', tag: 'BirthdayMigration');
      }
    } catch (e) {
      Logger.error('Error migrating user $userId', error: e, tag: 'BirthdayMigration');
      rethrow;
    }
  }
}

