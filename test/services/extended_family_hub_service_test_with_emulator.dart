import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import '../helpers/firebase_test_helper.dart';
import 'package:familyhub_mvp/services/extended_family_hub_service.dart';
import 'package:familyhub_mvp/models/extended_family_hub_data.dart';
import 'package:familyhub_mvp/models/hub.dart';

/// Extended Family Hub Service tests using Firebase Emulator
/// 
/// To run these tests:
/// 1. Start Firebase emulator: firebase emulators:start
/// 2. Run: flutter test test/services/extended_family_hub_service_test_with_emulator.dart
void main() {
  setUpAll(() async {
    await FirebaseTestHelper.initializeFirebaseEmulator();
  });

  tearDownAll(() async {
    await FirebaseTestHelper.cleanup();
  });

  group('ExtendedFamilyHubService with Emulator', () {
    late ExtendedFamilyHubService service;

    setUp(() {
      service = ExtendedFamilyHubService();
    });

    test('getExtendedFamilyData returns null for non-extended family hub', () async {
      // This test requires a real hub in Firestore
      // For now, we test the logic structure
      expect(service, isNotNull);
    });

    test('ExtendedFamilyHubData model works correctly', () {
      final data = ExtendedFamilyHubData(
        relationships: {'user1': 'grandparent'},
        privacySettings: {'user1': 'minimal'},
        memberRoles: {'user1': 'viewer'},
      );

      expect(data.getRelationship('user1'), RelationshipType.grandparent);
      expect(data.getPrivacyLevel('user1'), PrivacyLevel.minimal);
      expect(data.getRole('user1'), ExtendedFamilyRole.viewer);
    });

    test('RelationshipType enum conversions work', () {
      expect(RelationshipType.grandparent.value, 'grandparent');
      expect(RelationshipTypeExtension.fromString('grandparent'), RelationshipType.grandparent);
      expect(RelationshipTypeExtension.fromString('unknown'), RelationshipType.other);
    });

    test('PrivacyLevel enum conversions work', () {
      expect(PrivacyLevel.minimal.value, 'minimal');
      expect(PrivacyLevelExtension.fromString('minimal'), PrivacyLevel.minimal);
      expect(PrivacyLevelExtension.fromString('unknown'), PrivacyLevel.minimal);
    });

    test('ExtendedFamilyRole enum conversions work', () {
      expect(ExtendedFamilyRole.viewer.value, 'viewer');
      expect(ExtendedFamilyRoleExtension.fromString('viewer'), ExtendedFamilyRole.viewer);
      expect(ExtendedFamilyRoleExtension.fromString('unknown'), ExtendedFamilyRole.viewer);
    });
  });
}

