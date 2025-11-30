import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

/// Script to remove all synced calendar events from Firestore
/// This allows you to test calendar sync from scratch
/// 
/// Usage:
///   flutter run scripts/clean_synced_events.dart
/// 
/// Note: You must be logged into the app first for this script to work.

Future<void> main() async {
  print('=' * 60);
  print('Clean Synced Calendar Events Script');
  print('=' * 60);
  print('');

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✓ Firebase initialized');
  } catch (e) {
    print('✗ Error initializing Firebase: $e');
    print('Make sure you have Firebase configured in your project.');
    exit(1);
  }

  // Check authentication
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser;
  if (user == null) {
    print('✗ No user logged in. Please log in to the app first.');
    exit(1);
  }
  print('✓ User authenticated: ${user.email}');
  print('');

  // Get user's family ID
  final firestore = FirebaseFirestore.instance;
  final userDoc = await firestore.collection('users').doc(user.uid).get();
  if (!userDoc.exists) {
    print('✗ User document not found');
    exit(1);
  }

  final userData = userDoc.data()!;
  final familyId = userData['familyId'] as String?;
  if (familyId == null) {
    print('✗ User is not part of a family');
    exit(1);
  }
  print('✓ Family ID: $familyId');
  print('');

  // Get all events with importedFromDevice = true
  print('Searching for synced events...');
  final eventsRef = firestore
      .collection('families')
      .doc(familyId)
      .collection('events');

  final snapshot = await eventsRef
      .where('importedFromDevice', isEqualTo: true)
      .get();

  final syncedEvents = snapshot.docs;
  print('Found ${syncedEvents.length} synced events');
  print('');

  if (syncedEvents.isEmpty) {
    print('No synced events to delete. Exiting.');
    exit(0);
  }

  // Show summary
  print('Events to be deleted:');
  for (var doc in syncedEvents) {
    final data = doc.data();
    final title = data['title'] as String? ?? 'Untitled';
    final source = data['sourceCalendar'] as String? ?? 'Unknown source';
    print('  - $title ($source)');
  }
  print('');

  // Ask for confirmation
  print('⚠️  WARNING: This will permanently delete ${syncedEvents.length} synced events.');
  print('This action cannot be undone.');
  print('');
  stdout.write('Do you want to continue? (yes/no): ');
  final confirmation = stdin.readLineSync()?.toLowerCase().trim();

  if (confirmation != 'yes' && confirmation != 'y') {
    print('Operation cancelled.');
    exit(0);
  }

  // Delete events in batches (Firestore batch limit is 500)
  print('');
  print('Deleting events...');
  int deletedCount = 0;
  const batchSize = 500;

  for (int i = 0; i < syncedEvents.length; i += batchSize) {
    final batch = firestore.batch();
    final batchEnd = (i + batchSize < syncedEvents.length)
        ? i + batchSize
        : syncedEvents.length;

    for (int j = i; j < batchEnd; j++) {
      batch.delete(syncedEvents[j].reference);
    }

    await batch.commit();
    deletedCount += batchEnd - i;
    print('  Deleted $deletedCount / ${syncedEvents.length} events...');
  }

  print('');
  print('✓ Successfully deleted $deletedCount synced events');
  print('');

  // Ask if user wants to reset lastSyncedAt
  stdout.write('Do you want to reset lastSyncedAt timestamp? (yes/no): ');
  final resetTimestamp = stdin.readLineSync()?.toLowerCase().trim();

  if (resetTimestamp == 'yes' || resetTimestamp == 'y') {
    await firestore.collection('users').doc(user.uid).update({
      'lastSyncedAt': FieldValue.delete(),
    });
    print('✓ Reset lastSyncedAt timestamp');
  }

  print('');
  print('=' * 60);
  print('Cleanup complete! You can now sync from scratch.');
  print('=' * 60);
}

