import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

/// Script to add UAT test cases for the Co-Parenting Hub
/// 
/// Usage: dart scripts/add_coparenting_uat_test_cases.dart [environment]
/// Environment options: dev, qa, prod (default: dev)

const String firebaseProjectId = 'family-hub-71ff0';
String get firestoreBaseUrl => 'https://firestore.googleapis.com/v1/projects/$firebaseProjectId/databases/(default)/documents';

/// Convert a value to Firestore document format
dynamic toFirestoreValue(dynamic value) {
  if (value == null) {
    return {'nullValue': null};
  } else if (value is String) {
    return {'stringValue': value};
  } else if (value is int) {
    return {'integerValue': value.toString()};
  } else if (value is double) {
    return {'doubleValue': value};
  } else if (value is bool) {
    return {'booleanValue': value};
  } else if (value is DateTime) {
    return {'timestampValue': value.toUtc().toIso8601String()};
  } else if (value is Map) {
    return {'mapValue': {'fields': _mapToFirestoreFields(value as Map<String, dynamic>)}};
  } else if (value is List) {
    return {'arrayValue': {'values': value.map((v) => toFirestoreValue(v)).toList()}};
  } else {
    return {'stringValue': value.toString()};
  }
}

Map<String, dynamic> _mapToFirestoreFields(Map<String, dynamic> map) {
  final fields = <String, dynamic>{};
  for (var entry in map.entries) {
    fields[entry.key] = toFirestoreValue(entry.value);
  }
  return fields;
}

/// Create a document in Firestore via REST API
Future<String> createDocument(
  String collectionPath,
  Map<String, dynamic> data,
  String accessToken,
) async {
  final url = '$firestoreBaseUrl/$collectionPath';
  
  // Convert data to Firestore format
  final firestoreData = {
    'fields': _mapToFirestoreFields(data),
  };
  
  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
    body: jsonEncode(firestoreData),
  );
  
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('Failed to create document: ${response.statusCode}\n${response.body}');
  }
  
  final responseData = jsonDecode(response.body) as Map<String, dynamic>;
  // Extract document ID from response (it's in the name field)
  final name = responseData['name'] as String? ?? '';
  final parts = name.split('/');
  return parts.last;
}

/// Create a subcollection document
Future<String> createSubcollectionDocument(
  String parentPath,
  String subcollectionName,
  Map<String, dynamic> data,
  String accessToken,
) async {
  final url = '$firestoreBaseUrl/$parentPath/$subcollectionName';
  return createDocument(url.replaceFirst(firestoreBaseUrl + '/', ''), data, accessToken);
}

// Co-Parenting Hub test cases
final coparentingTestCases = [
  {
    'number': 1,
    'title': 'Create Co-Parenting Hub',
    'description': 'Verify users can create a new co-parenting hub with premium access',
    'feature': 'Hub Creation',
    'test': 'Navigate to My Hubs. Tap "Add New Hub". Select "Co-Parenting Hub". Enter hub name and description. Tap "Create Hub". Verify hub appears in hub list. Verify hub type is set to coparenting. Verify premium access is checked.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Create hub with name and description',
        'description': 'Create a co-parenting hub with all required fields',
        'feature': 'Hub Creation',
        'test': 'Create hub with name "Timmy\'s Co Parenting" and description. Verify creation successful. Verify hub appears in list.',
      },
      {
        'number': 2,
        'title': 'Verify premium access required',
        'description': 'Verify that non-premium users cannot create co-parenting hubs',
        'feature': 'Hub Creation',
        'test': 'As non-premium user, attempt to create co-parenting hub. Verify error message about premium access. Verify hub is not created.',
      },
      {
        'number': 3,
        'title': 'Verify hub type is correct',
        'description': 'Verify created hub has correct hub type',
        'feature': 'Hub Creation',
        'test': 'After creating hub, verify hub type is "coparenting" in Firestore. Verify UI shows co-parenting specific features.',
      },
    ],
  },
  {
    'number': 2,
    'title': 'Co-Parenting Hub UI',
    'description': 'Verify the co-parenting hub screen displays correctly with unique UI elements',
    'feature': 'Hub UI',
    'test': 'Open a co-parenting hub. Verify screen shows: Members section with count, Quick stats (pending expenses, schedule requests), Feature cards (Custody Schedules, Schedule Change Requests, Shared Expenses), Chat widget. Verify UI is different from Extended Family Hub.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify members section displays',
        'description': 'Verify members section shows member count and list',
        'feature': 'Hub UI',
        'test': 'Open co-parenting hub. Verify "Members" heading with count. Verify member cards display correctly. Verify "Invite New Members" button works.',
      },
      {
        'number': 2,
        'title': 'Verify quick stats display',
        'description': 'Verify pending expenses and schedule requests stats show',
        'feature': 'Hub UI',
        'test': 'Verify two stat cards: "Pending Expenses" and "Schedule Requests". Verify counts are correct. Verify cards highlight when count > 0.',
      },
      {
        'number': 3,
        'title': 'Verify feature cards display',
        'description': 'Verify all three feature cards are visible and navigable',
        'feature': 'Hub UI',
        'test': 'Verify three feature cards: Custody Schedules, Schedule Change Requests, Shared Expenses. Verify each card has icon, title, description, and arrow. Verify tapping navigates to correct screen.',
      },
      {
        'number': 4,
        'title': 'Verify chat widget displays',
        'description': 'Verify chat widget is present and functional',
        'feature': 'Hub UI',
        'test': 'Verify chat widget section is visible. Verify "View Full" button works. Verify messages can be sent from widget.',
      },
    ],
  },
  {
    'number': 3,
    'title': 'Custody Schedules',
    'description': 'Verify users can create and manage custody schedules',
    'feature': 'Custody Schedules',
    'test': 'Navigate to Custody Schedules from co-parenting hub. Verify screen loads. Tap "Create Schedule". Select child, schedule type, and dates. Save schedule. Verify schedule appears in list.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Create week-on-week-off schedule',
        'description': 'Create alternating weekly custody schedule',
        'feature': 'Custody Schedules',
        'test': 'Create schedule with type "Week On Week Off". Set start date. Verify schedule is created. Verify alternating weeks are assigned correctly.',
      },
      {
        'number': 2,
        'title': 'Create custom schedule',
        'description': 'Create custom weekly schedule with specific days',
        'feature': 'Custody Schedules',
        'test': 'Create schedule with type "Custom". Assign specific days to each parent. Verify schedule is saved correctly. Verify weekly view shows correct assignments.',
      },
      {
        'number': 3,
        'title': 'Add schedule exceptions',
        'description': 'Add holidays or special date exceptions to schedule',
        'feature': 'Custody Schedules',
        'test': 'Open existing schedule. Add exception for holiday. Assign parent for exception date. Verify exception is saved. Verify exception appears in schedule view.',
      },
    ],
  },
  {
    'number': 4,
    'title': 'Schedule Change Requests',
    'description': 'Verify users can request and manage schedule changes',
    'feature': 'Schedule Change Requests',
    'test': 'Navigate to Schedule Change Requests. Tap "Request Change". Select date and reason. Submit request. Verify request appears in pending list. Verify other parent can approve/reject.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Create schedule change request',
        'description': 'Request a change to existing custody schedule',
        'feature': 'Schedule Change Requests',
        'test': 'Create request for specific date. Add reason. Verify request is created with status "pending". Verify request appears in pending list.',
      },
      {
        'number': 2,
        'title': 'Approve schedule change request',
        'description': 'Approve a pending schedule change request',
        'feature': 'Schedule Change Requests',
        'test': 'As other parent, view pending request. Tap "Approve". Verify request status changes to "approved". Verify schedule is updated if applicable.',
      },
      {
        'number': 3,
        'title': 'Reject schedule change request',
        'description': 'Reject a pending schedule change request',
        'feature': 'Schedule Change Requests',
        'test': 'As other parent, view pending request. Tap "Reject". Verify request status changes to "rejected". Verify notification is sent to requester.',
      },
      {
        'number': 4,
        'title': 'Swap dates request',
        'description': 'Request to swap two dates in schedule',
        'feature': 'Schedule Change Requests',
        'test': 'Create swap request. Select date to swap and date to swap with. Verify both dates are specified. Verify swap logic works correctly.',
      },
    ],
  },
  {
    'number': 5,
    'title': 'Shared Expenses',
    'description': 'Verify users can track and split expenses with co-parent',
    'feature': 'Shared Expenses',
    'test': 'Navigate to Shared Expenses. Tap "Add Expense". Enter expense details (amount, category, description, child). Select split ratio. Optionally add receipt. Save expense. Verify expense appears in list. Verify pending approval count updates.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Create expense with 50/50 split',
        'description': 'Create expense with default 50/50 split',
        'feature': 'Shared Expenses',
        'test': 'Create expense: \$100, category "Medical", description "Doctor visit", child selected. Verify split ratio is 50/50. Verify amount owed is \$50. Verify expense status is "pending".',
      },
      {
        'number': 2,
        'title': 'Create expense with custom split',
        'description': 'Create expense with non-50/50 split ratio',
        'feature': 'Shared Expenses',
        'test': 'Create expense with 70/30 split. Verify amount owed calculation is correct. Verify split ratio is saved.',
      },
      {
        'number': 3,
        'title': 'Add receipt to expense',
        'description': 'Upload receipt photo for expense',
        'feature': 'Shared Expenses',
        'test': 'Create expense. Tap "Add Receipt". Select or take photo. Verify photo uploads. Verify receipt URL is saved with expense. Verify receipt displays in expense detail.',
      },
      {
        'number': 4,
        'title': 'Approve expense',
        'description': 'Approve a pending expense',
        'feature': 'Shared Expenses',
        'test': 'As other parent, view pending expense. Tap "Approve". Verify expense status changes to "approved". Verify pending count decreases. Verify approval timestamp is saved.',
      },
      {
        'number': 5,
        'title': 'Reject expense',
        'description': 'Reject a pending expense',
        'feature': 'Shared Expenses',
        'test': 'As other parent, view pending expense. Tap "Reject". Verify expense status changes to "rejected". Verify rejection reason can be added. Verify notification is sent.',
      },
      {
        'number': 6,
        'title': 'Mark expense as paid',
        'description': 'Mark approved expense as paid',
        'feature': 'Shared Expenses',
        'test': 'After expense is approved, mark as "Paid". Verify expense status changes to "paid". Verify payment tracking works.',
      },
    ],
  },
  {
    'number': 6,
    'title': 'Co-Parenting Hub Navigation',
    'description': 'Verify navigation and back button functionality',
    'feature': 'Navigation',
    'test': 'Navigate to co-parenting hub from My Hubs. Verify back arrow works. Navigate to each feature screen. Verify back navigation works from all screens. Verify settings button works.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify back arrow functionality',
        'description': 'Verify back arrow navigates correctly',
        'feature': 'Navigation',
        'test': 'Open co-parenting hub. Tap back arrow. Verify returns to My Hubs screen. Verify no errors occur.',
      },
      {
        'number': 2,
        'title': 'Verify feature screen navigation',
        'description': 'Verify navigation to and from feature screens',
        'feature': 'Navigation',
        'test': 'Navigate to each feature (Custody Schedules, Schedule Change Requests, Expenses). Verify each screen loads. Verify back navigation works from each.',
      },
      {
        'number': 3,
        'title': 'Verify settings access',
        'description': 'Verify settings button opens hub settings',
        'feature': 'Navigation',
        'test': 'Tap settings icon in co-parenting hub. Verify hub settings screen opens. Verify settings can be modified.',
      },
    ],
  },
];

Future<void> main(List<String> args) async {
  final environment = args.isNotEmpty ? args[0] : 'dev';
  final prefix = environment == 'dev' ? 'dev_' : (environment == 'qa' ? 'test_' : '');
  final collectionPath = '${prefix}uat_test_rounds';

  print('Creating UAT test cases for Co-Parenting Hub...');
  print('Environment: $environment');
  print('Collection: $collectionPath');

  // Get access token
  String accessToken;
  try {
    final serviceAccountJson = await File('scripts/firebase-service-account.json').readAsString();
    final credentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
    final client = await auth.clientViaServiceAccount(
      credentials,
      [
        'https://www.googleapis.com/auth/cloud-platform',
        'https://www.googleapis.com/auth/datastore',
      ],
    );
    
    // Get access token from the authenticated client
    final token = client.credentials.accessToken;
    accessToken = token.data;
    
    print('✓ Authentication successful!');
  } catch (e) {
    print('Error getting access token: $e');
    print('Make sure scripts/firebase-service-account.json exists');
    exit(1);
  }

  try {
    // Create test round
    final now = DateTime.now().toUtc();
    final testRoundData = {
      'title': 'Co-Parenting Hub Features',
      'description': 'UAT test cases for Co-Parenting Hub functionality including custody schedules, schedule change requests, and shared expenses',
      'status': 'active',
      'createdAt': now.toIso8601String(),
      'createdBy': 'system',
    };

    print('\nCreating test round...');
    final testRoundId = await createDocument(collectionPath, testRoundData, accessToken);
    print('Test round created: $testRoundId');

    // Create test cases
    for (var testCase in coparentingTestCases) {
      print('\nCreating test case ${testCase['number']}: ${testCase['title']}');
      
      final testCaseData = {
        'number': testCase['number'],
        'title': testCase['title'],
        'description': testCase['description'],
        'feature': testCase['feature'],
        'test': testCase['test'],
        'status': 'pending',
        'testRoundId': testRoundId,
        'createdAt': now.toIso8601String(),
      };

      final testCaseId = await createSubcollectionDocument(
        '$collectionPath/$testRoundId',
        'testCases',
        testCaseData,
        accessToken,
      );

      // Create sub-test cases
      final subTestCases = testCase['subTestCases'] as List<dynamic>? ?? [];
      for (var subTestCase in subTestCases) {
        final subTestCaseData = {
          'number': subTestCase['number'],
          'title': subTestCase['title'],
          'description': subTestCase['description'],
          'feature': subTestCase['feature'],
          'test': subTestCase['test'],
          'status': 'pending',
          'createdAt': now.toIso8601String(),
        };

        await createSubcollectionDocument(
          '$collectionPath/$testRoundId/testCases/$testCaseId',
          'subTestCases',
          subTestCaseData,
          accessToken,
        );
      }

      print('  Created ${subTestCases.length} sub-test cases');
    }

    print('\n✅ Successfully created ${coparentingTestCases.length} test cases for Co-Parenting Hub');
    print('Test round ID: $testRoundId');
  } catch (e) {
    print('\n❌ Error creating test cases: $e');
    exit(1);
  }
}


