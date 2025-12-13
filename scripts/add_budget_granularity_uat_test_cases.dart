import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

// Configuration
const String firestoreBaseUrl = 'https://firestore.googleapis.com/v1/projects/family-hub-71ff0/databases/(default)/documents';
const String serviceAccountPath = 'scripts/firebase-service-account.json';

Future<String> authenticateWithServiceAccount() async {
  final accountCredentials = ServiceAccountCredentials.fromJson(
    json.decode(await File(serviceAccountPath).readAsString()),
  );
  
  final client = await clientViaServiceAccount(accountCredentials, [
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/datastore',
  ]);
  
  final token = await client.credentials.accessToken;
  return token.data;
}

Future<Map<String, dynamic>> createDocument(
  String collectionPath,
  Map<String, dynamic> data,
  String accessToken,
) async {
  final url = '$firestoreBaseUrl/$collectionPath';
  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: json.encode({'fields': _convertToFirestoreFields(data)}),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to create document: ${response.statusCode} ${response.body}');
  }

  return json.decode(response.body);
}

Future<Map<String, dynamic>> createSubcollectionDocument(
  String parentPath,
  String subcollectionName,
  Map<String, dynamic> data,
  String accessToken,
) async {
  final fullPath = '$parentPath/$subcollectionName';
  return createDocument(fullPath, data, accessToken);
}

Map<String, dynamic> _convertToFirestoreFields(Map<String, dynamic> data) {
  final fields = <String, dynamic>{};
  data.forEach((key, value) {
    if (value != null) {
      fields[key] = _convertValue(value);
    }
  });
  return fields;
}

dynamic _convertValue(dynamic value) {
  if (value is String) {
    return {'stringValue': value};
  } else if (value is int) {
    return {'integerValue': value.toString()};
  } else if (value is double) {
    return {'doubleValue': value};
  } else if (value is bool) {
    return {'booleanValue': value};
  } else if (value is DateTime) {
    return {'timestampValue': value.toUtc().toIso8601String()};
  } else if (value is List) {
    return {
      'arrayValue': {
        'values': value.map((v) => _convertValue(v)).toList(),
      },
    };
  } else if (value is Map) {
    return {
      'mapValue': {
        'fields': _convertToFirestoreFields(Map<String, dynamic>.from(value)),
      },
    };
  }
  return {'nullValue': null};
}

void main(List<String> args) async {
  final environment = args.isNotEmpty ? args[0] : 'dev';
  final prefix = environment == 'prod' ? '' : environment == 'qa' ? 'test_' : 'dev_';
  final collectionName = '${prefix}uat_test_rounds';

  print('Creating UAT test cases for Budget Granularity Features in $environment environment...');
  print('Collection: $collectionName\n');

  try {
    final accessToken = await authenticateWithServiceAccount();
    print('✓ Authenticated with service account\n');

    // Create test round
    final testRoundData = {
      'name': 'Budget Granularity Features',
      'description': 'Testing granular budget items, progress tracking, adherence indicators, and delete functionality',
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'active',
    };

    print('Creating test round...');
    final testRound = await createDocument(collectionName, testRoundData, accessToken);
    final testRoundId = testRound['name']!.split('/').last;
    print('✓ Created test round: $testRoundId\n');

    final testCasesData = [
      {
        'name': 'Create Budget with Items',
        'description': 'Verify users can create a budget and add multiple items to it',
        'testSteps': [
          'Navigate to Budgets screen',
          'Tap "Create Budget"',
          'Fill in budget details (name, amount, dates)',
          'Save budget',
          'Open budget detail screen',
          'Tap "Add Item"',
          'Enter item name, estimated amount',
          'Save item',
          'Verify item appears in the list',
        ],
        'expectedResult': 'Budget created with items visible in the list',
      },
      {
        'name': 'Edit Budget Item',
        'description': 'Verify users can edit existing budget items',
        'testSteps': [
          'Open a budget with items',
          'Tap on an item',
          'Modify item name or amount',
          'Save changes',
          'Verify item is updated in the list',
        ],
        'expectedResult': 'Item details are updated correctly',
      },
      {
        'name': 'Complete Budget Item',
        'description': 'Verify users can mark items as complete with actual cost',
        'testSteps': [
          'Open a budget with items',
          'Tap "Mark Complete" on an item',
          'Enter actual amount',
          'Optionally upload receipt photo',
          'Save',
          'Verify item shows as complete with actual amount',
          'Verify adherence status indicator appears',
        ],
        'expectedResult': 'Item marked complete with actual cost and status indicator',
      },
      {
        'name': 'Item Progress Tracking',
        'description': 'Verify progress is calculated based on completed items',
        'testSteps': [
          'Create budget with 5 items',
          'Complete 2 items',
          'Check progress section',
          'Verify item progress shows 2/5 (40%)',
        ],
        'expectedResult': 'Progress correctly shows 40% completion',
      },
      {
        'name': 'Dollar Progress Tracking (Premium)',
        'description': 'Verify premium users see dollar-based progress',
        'testSteps': [
          'As premium user, create budget with items',
          'Complete some items with actual costs',
          'Check progress section',
          'Verify dollar progress percentage is shown',
        ],
        'expectedResult': 'Dollar progress displayed for premium users',
      },
      {
        'name': 'Budget Adherence Indicators',
        'description': 'Verify adherence status shows correctly (green/yellow/red)',
        'testSteps': [
          'Create budget with items',
          'Complete item under budget (green)',
          'Complete item slightly over budget (yellow)',
          'Complete item significantly over budget (red)',
          'Verify correct color indicators appear',
        ],
        'expectedResult': 'Adherence indicators show correct colors based on threshold',
      },
      {
        'name': 'Drag to Reorder Items',
        'description': 'Verify users can reorder budget items',
        'testSteps': [
          'Open budget with multiple items',
          'Long press and drag an item',
          'Move to different position',
          'Release',
          'Verify items are reordered',
        ],
        'expectedResult': 'Items maintain new order after reordering',
      },
      {
        'name': 'Delete Budget Item',
        'description': 'Verify users can delete budget items',
        'testSteps': [
          'Open budget with items',
          'Tap delete icon on an item',
          'Confirm deletion',
          'Verify item is removed from list',
        ],
        'expectedResult': 'Item deleted and removed from budget',
      },
      {
        'name': 'Delete Budget',
        'description': 'Verify users can delete entire budgets',
        'testSteps': [
          'Navigate to Budgets screen',
          'Tap menu (three dots) on a budget',
          'Select "Delete Budget"',
          'Confirm deletion',
          'Verify budget is removed from list',
        ],
        'expectedResult': 'Budget and all associated items deleted',
      },
      {
        'name': 'Sub-items Support',
        'description': 'Verify items can have sub-items (hierarchical structure)',
        'testSteps': [
          'Create budget item',
          'Add sub-item to the item',
          'Verify sub-item appears nested',
          'Complete sub-items',
          'Verify parent item status updates',
        ],
        'expectedResult': 'Sub-items work correctly with parent item status tracking',
      },
    ];

    print('Creating ${testCasesData.length} test cases...\n');

    for (int i = 0; i < testCasesData.length; i++) {
      final testCase = testCasesData[i];
      print('Creating test case ${i + 1}/${testCasesData.length}: ${testCase['name']}');

      final testCaseData = {
        'name': testCase['name'],
        'description': testCase['description'],
        'testSteps': testCase['testSteps'],
        'expectedResult': testCase['expectedResult'],
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      };

      await createSubcollectionDocument(
        '$collectionName/$testRoundId',
        'testCases',
        testCaseData,
        accessToken,
      );

      print('✓ Created test case: ${testCase['name']}\n');
    }

    print('✓ Successfully created test round with ${testCasesData.length} test cases!');
    print('\nTest Round ID: $testRoundId');
    print('Collection: $collectionName');
  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

