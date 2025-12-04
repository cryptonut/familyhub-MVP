import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:familyhub_mvp/core/constants/app_constants.dart';

/// Script to delete duplicate user: WkCr1tJzvXSl3mAMPjOCD5v9oZ42
/// Run with: dart run delete_duplicate_user.dart
Future<void> main() async {
  const duplicateUserId = 'WkCr1tJzvXSl3mAMPjOCD5v9oZ42';
  
  print('Initializing Firebase...');
  await Firebase.initializeApp();
  
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  
  try {
    // First, get the user document to check for familyId
    print('Fetching user document...');
    final userDoc = await firestore.collection('users').doc(duplicateUserId).get();
    
    if (!userDoc.exists) {
      print('User document does not exist in Firestore.');
    } else {
      final userData = userDoc.data();
      final familyId = userData?['familyId'] as String?;
      
      print('User found. Family ID: ${familyId ?? "none"}');
      
      // Delete user document
      print('Deleting user document...');
      await firestore.collection('users').doc(duplicateUserId).delete();
      print('✓ User document deleted');
      
      // Delete user's notifications
      print('Deleting user notifications...');
      final notificationsSnapshot = await firestore
          .collection('notifications')
          .where('userId', isEqualTo: duplicateUserId)
          .get();
      
      if (notificationsSnapshot.docs.isNotEmpty) {
        final batchSize = 500;
        for (int i = 0; i < notificationsSnapshot.docs.length; i += batchSize) {
          final batch = firestore.batch();
          final end = (i + batchSize < notificationsSnapshot.docs.length) 
              ? i + batchSize 
              : notificationsSnapshot.docs.length;
          
          for (int j = i; j < end; j++) {
            batch.delete(notificationsSnapshot.docs[j].reference);
          }
          await batch.commit();
        }
        print('✓ Deleted ${notificationsSnapshot.docs.length} notifications');
      } else {
        print('✓ No notifications to delete');
      }
      
      // Delete old user-specific collections (if any)
      print('Checking for old user-specific collections...');
      try {
        final oldPath = 'families/$duplicateUserId';
        final oldCollectionRef = firestore.collection(oldPath);
        final oldSnapshot = await oldCollectionRef.get();
        
        if (oldSnapshot.docs.isNotEmpty) {
          final batchSize = 500;
          for (int i = 0; i < oldSnapshot.docs.length; i += batchSize) {
            final batch = firestore.batch();
            final end = (i + batchSize < oldSnapshot.docs.length) 
                ? i + batchSize 
                : oldSnapshot.docs.length;
            
            for (int j = i; j < end; j++) {
              batch.delete(oldSnapshot.docs[j].reference);
            }
            await batch.commit();
          }
          print('✓ Deleted old user path: $oldPath');
        }
      } catch (e) {
        print('⚠ Error deleting old user path: $e');
      }
    }
    
    // Try to delete Firebase Auth account (requires admin privileges or the user to be logged in)
    print('Attempting to delete Firebase Auth account...');
    try {
      // Note: This requires admin SDK or the user to be logged in
      // For now, we'll just log that it needs to be done manually
      print('⚠ Firebase Auth account deletion requires admin SDK or user login.');
      print('   Please delete manually from Firebase Console if needed.');
    } catch (e) {
      print('⚠ Could not delete Auth account: $e');
    }
    
    print('\n✅ Duplicate user data deleted successfully!');
    print('   User ID: $duplicateUserId');
    print('   Note: If the Firebase Auth account still exists, delete it manually from Firebase Console.');
    
  } catch (e, st) {
    print('❌ Error deleting user: $e');
    print('Stack trace: $st');
  } finally {
    // Clean up
    await Firebase.app().delete();
  }
}

