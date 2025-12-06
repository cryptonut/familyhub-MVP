import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../lib/firebase_options.dart';

/// Script to delete ALL chess games and invites from Firestore
/// Run with: dart run scripts/cleanup_chess_games.dart
Future<void> main() async {
  print('🚀 Initializing Firebase...');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  print('📧 Please sign in to authenticate...');
  
  // Sign in (you'll need to provide credentials or use existing session)
  // For now, we'll try to use existing auth state
  final user = auth.currentUser;
  if (user == null) {
    print('❌ No user signed in. Please sign in through the app first.');
    return;
  }

  print('✅ Authenticated as: ${user.email}');
  print('🗑️  Starting cleanup of ALL chess games and invites...\n');

  int gamesDeleted = 0;
  int invitesDeleted = 0;
  int errors = 0;

  try {
    // Delete all chess games
    print('Deleting chess games...');
    final gamesSnapshot = await firestore.collection('chess_games').get();
    
    for (var doc in gamesSnapshot.docs) {
      try {
        await doc.reference.delete();
        gamesDeleted++;
        print('  ✓ Deleted game: ${doc.id}');
      } catch (e) {
        errors++;
        print('  ✗ Error deleting game ${doc.id}: $e');
      }
    }

    // Delete all invites
    print('\nDeleting invites...');
    final invitesSnapshot = await firestore.collection('invites').get();
    
    for (var doc in invitesSnapshot.docs) {
      try {
        await doc.reference.delete();
        invitesDeleted++;
        print('  ✓ Deleted invite: ${doc.id}');
      } catch (e) {
        errors++;
        print('  ✗ Error deleting invite ${doc.id}: $e');
      }
    }

    print('\n✅ Cleanup complete!');
    print('   Games deleted: $gamesDeleted');
    print('   Invites deleted: $invitesDeleted');
    if (errors > 0) {
      print('   Errors: $errors');
    }
  } catch (e) {
    print('❌ Fatal error during cleanup: $e');
  }
}

