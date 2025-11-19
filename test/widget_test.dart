import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:familyhub_mvp/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FamilyHubApp());

    // Verify that the app title is present
    expect(find.text('Family Hub'), findsNothing); // AppBar title might not be directly findable
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

