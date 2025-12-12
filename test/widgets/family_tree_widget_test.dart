import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:familyhub_mvp/widgets/family_tree_widget.dart';
import 'package:familyhub_mvp/models/hub.dart';
import 'package:familyhub_mvp/services/extended_family_hub_service.dart';
import 'package:familyhub_mvp/services/auth_service.dart';

// Generate mocks
@GenerateMocks([
  ExtendedFamilyHubService,
  AuthService,
])
import 'family_tree_widget_test.mocks.dart';

void main() {
  group('FamilyTreeWidget Tests', () {
    late Hub testHub;

    setUp(() {
      testHub = Hub(
        id: 'hub1',
        name: 'Extended Family Hub',
        description: 'Test hub',
        creatorId: 'creator1',
        memberIds: ['user1', 'user2'],
        createdAt: DateTime.now(),
        hubType: HubType.extendedFamily,
      );
    });

    testWidgets('displays loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FamilyTreeWidget(hub: testHub),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays empty state when no members', (WidgetTester tester) async {
      final emptyHub = Hub(
        id: 'hub2',
        name: 'Empty Hub',
        description: 'Test',
        creatorId: 'creator1',
        memberIds: [],
        createdAt: DateTime.now(),
        hubType: HubType.extendedFamily,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FamilyTreeWidget(hub: emptyHub),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.text('No family members yet'), findsOneWidget);
      expect(find.text('Invite extended family members to see the family tree'), findsOneWidget);
    });

    testWidgets('displays family tree title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FamilyTreeWidget(hub: testHub),
        ),
      );

      // Wait for async operations
      await tester.pumpAndSettle();

      expect(find.text('Family Tree'), findsOneWidget);
    });
  });
}

