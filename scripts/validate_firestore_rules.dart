/// Validation script to ensure Firestore rules match model field names
/// Run with: dart scripts/validate_firestore_rules.dart

import 'dart:io';

void main() {
  print('🔍 Validating Firestore Rules Consistency...\n');
  
  bool hasErrors = false;
  
  // Check Hub model vs rules
  print('Checking Hub model...');
  final hubModel = File('lib/models/hub.dart').readAsStringSync();
  final firestoreRules = File('firestore.rules').readAsStringSync();
  
  // Hub uses creatorId, not createdBy
  if (hubModel.contains('creatorId') && !firestoreRules.contains('creatorId')) {
    print('❌ ERROR: Hub model uses creatorId but rules check createdBy');
    hasErrors = true;
  }
  
  if (hubModel.contains('memberIds') && !firestoreRules.contains('memberIds')) {
    print('❌ ERROR: Hub model uses memberIds but rules check members');
    hasErrors = true;
  }
  
  // Verify rules check creatorId for hubs
  if (!firestoreRules.contains('request.resource.data.creatorId == request.auth.uid')) {
    print('⚠️  WARNING: Rules may not check creatorId for hub creation');
  }
  
  // Check other models use createdBy consistently
  print('\nChecking other models...');
  final taskModel = File('lib/models/task.dart').readAsStringSync();
  final calendarModel = File('lib/models/calendar_event.dart').readAsStringSync();
  final photoAlbumModel = File('lib/models/photo_album.dart').readAsStringSync();
  
  if (taskModel.contains('createdBy') && !firestoreRules.contains('createdBy')) {
    print('❌ ERROR: Task model uses createdBy but rules may not check it');
    hasErrors = true;
  }
  
  if (calendarModel.contains('createdBy') && !firestoreRules.contains('createdBy')) {
    print('❌ ERROR: CalendarEvent model uses createdBy but rules may not check it');
    hasErrors = true;
  }
  
  if (photoAlbumModel.contains('createdBy') && !firestoreRules.contains('createdBy')) {
    print('❌ ERROR: PhotoAlbum model uses createdBy but rules may not check it');
    hasErrors = true;
  }
  
  print('\n✅ Validation complete!');
  
  if (hasErrors) {
    print('\n❌ ERRORS FOUND - Please fix before deploying rules!');
    exit(1);
  } else {
    print('✅ No errors found - Rules appear consistent with models');
    exit(0);
  }
}

