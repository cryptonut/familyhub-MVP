import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

/// Script to add UAT test cases for the Budgeting System
/// 
/// Usage: dart scripts/add_budget_uat_test_cases.dart [environment]
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

// Budgeting test cases
final budgetTestCases = [
  {
    'number': 1,
    'title': 'Create Family Budget',
    'description': 'Verify users can create a new family budget with all required fields',
    'feature': 'Budget Creation',
    'test': 'Navigate to Budget tab. Tap "Create Budget" button. Fill in budget name, amount, period, and date range. Tap "Create Budget". Verify budget appears in budget list. Verify default categories are initialized.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Create monthly family budget',
        'description': 'Create a monthly family budget with \$1000 limit',
        'feature': 'Budget Creation',
        'test': 'Create budget with name "Monthly Budget", amount \$1000, period "monthly", dates for current month. Verify creation successful.',
      },
      {
        'number': 2,
        'title': 'Verify default categories created',
        'description': 'After creating budget, verify 8 default categories are created',
        'feature': 'Budget Creation',
        'test': 'Check budget detail screen. Verify categories: Food & Groceries, Transport, Entertainment, Utilities, Shopping, Health & Fitness, Education, Other.',
      },
      {
        'number': 3,
        'title': 'Create budget with custom dates',
        'description': 'Create budget with custom start and end dates',
        'feature': 'Budget Creation',
        'test': 'Select custom date range. Verify dates are saved correctly. Verify budget period shows as "custom".',
      },
    ],
  },
  {
    'number': 2,
    'title': 'Add Transaction',
    'description': 'Verify users can add income and expense transactions to a budget',
    'feature': 'Transaction Management',
    'test': 'Open a budget. Tap "Add Transaction" button. Select transaction type (income/expense). Enter amount and description. Select category (optional). Select date. Optionally add receipt photo. Tap "Add Transaction". Verify transaction appears in transaction list.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Add expense transaction',
        'description': 'Add a \$50 expense for groceries',
        'feature': 'Transaction Management',
        'test': 'Add expense transaction: \$50, description "Groceries", category "Food & Groceries". Verify transaction appears. Verify budget spent amount updates.',
      },
      {
        'number': 2,
        'title': 'Add income transaction',
        'description': 'Add a \$200 income transaction',
        'feature': 'Transaction Management',
        'test': 'Add income transaction: \$200, description "Allowance". Verify transaction appears. Verify budget balance updates.',
      },
      {
        'number': 3,
        'title': 'Add transaction with receipt',
        'description': 'Add transaction and upload receipt photo',
        'feature': 'Transaction Management',
        'test': 'Add transaction. Tap "Add Receipt Photo". Take or select photo. Verify photo uploads. Verify receipt URL is saved with transaction.',
      },
      {
        'number': 4,
        'title': 'Add transaction without category',
        'description': 'Add transaction without selecting a category',
        'feature': 'Transaction Management',
        'test': 'Add transaction without category. Verify transaction saves successfully. Verify it shows as "Uncategorized" in list.',
      },
    ],
  },
  {
    'number': 3,
    'title': 'Budget Tracking and Progress',
    'description': 'Verify budget progress tracking and remaining amount calculations',
    'feature': 'Budget Tracking',
    'test': 'Create budget with \$1000 limit. Add expenses totaling \$300. Verify budget detail shows: Total Budget \$1000, Spent \$300, Remaining \$700, 30% used. Verify progress bar shows 30% filled.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify progress calculation',
        'description': 'Verify progress percentage is calculated correctly',
        'feature': 'Budget Tracking',
        'test': 'Budget \$1000, spent \$250. Verify shows 25% used. Verify progress bar at 25%.',
      },
      {
        'number': 2,
        'title': 'Verify over-budget detection',
        'description': 'Verify system detects when budget is exceeded',
        'feature': 'Budget Tracking',
        'test': 'Budget \$1000, add expenses totaling \$1100. Verify remaining shows -\$100 (red). Verify percent used shows >100%.',
      },
      {
        'number': 3,
        'title': 'Verify balance calculation',
        'description': 'Verify balance (income - expenses) is calculated correctly',
        'feature': 'Budget Tracking',
        'test': 'Add income \$500, expenses \$300. Verify balance shows \$200. Verify summary shows correct income and expense totals.',
      },
    ],
  },
  {
    'number': 4,
    'title': 'Category Management',
    'description': 'Verify users can view and manage budget categories',
    'feature': 'Category Management',
    'test': 'Open budget detail. View categories list. Verify default categories are displayed. Verify each category shows icon, name, and color. Verify categories can be used when adding transactions.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'View default categories',
        'description': 'Verify all 8 default categories are visible',
        'feature': 'Category Management',
        'test': 'Open budget. Check categories. Verify 8 default categories: Food, Transport, Entertainment, Utilities, Shopping, Health, Education, Other.',
      },
      {
        'number': 2,
        'title': 'Use category in transaction',
        'description': 'Verify category can be selected when adding transaction',
        'feature': 'Category Management',
        'test': 'Add transaction. Open category dropdown. Verify all categories listed. Select category. Verify category is saved with transaction.',
      },
    ],
  },
  {
    'number': 5,
    'title': 'Budget Navigation Integration',
    'description': 'Verify budget feature is accessible from main navigation',
    'feature': 'Navigation',
    'test': 'From home screen, verify Budget tab appears in bottom navigation. Tap Budget tab. Verify Budget Home Screen loads. Verify navigation works correctly.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify budget tab visible',
        'description': 'Verify Budget tab appears in navigation bar',
        'feature': 'Navigation',
        'test': 'Check bottom navigation. Verify Budget tab with wallet icon is visible. Verify tab is in correct position.',
      },
      {
        'number': 2,
        'title': 'Navigate to budget screen',
        'description': 'Verify tapping Budget tab navigates correctly',
        'feature': 'Navigation',
        'test': 'Tap Budget tab. Verify Budget Home Screen loads. Verify no errors occur.',
      },
    ],
  },
  {
    'number': 6,
    'title': 'Budget List and Empty State',
    'description': 'Verify budget list displays correctly with and without budgets',
    'feature': 'Budget Display',
    'test': 'Navigate to Budget screen. If no budgets exist, verify empty state shows with "Create Budget" button. Create a budget. Verify budget appears in list with name, amount, and date range. Tap budget to view details.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify empty state',
        'description': 'Verify empty state displays when no budgets exist',
        'feature': 'Budget Display',
        'test': 'Delete all budgets. Navigate to Budget screen. Verify empty state with icon, message, and "Create Budget" button appears.',
      },
      {
        'number': 2,
        'title': 'Verify budget list item',
        'description': 'Verify budget list items show correct information',
        'feature': 'Budget Display',
        'test': 'Create budget. Verify list item shows: budget name, description/type, period chip, total amount, date range. Verify item is tappable.',
      },
      {
        'number': 3,
        'title': 'Navigate to budget detail',
        'description': 'Verify tapping budget opens detail screen',
        'feature': 'Budget Display',
        'test': 'Tap budget in list. Verify Budget Detail Screen opens. Verify all budget information is displayed correctly.',
      },
    ],
  },
  {
    'number': 7,
    'title': 'Transaction List and Filtering',
    'description': 'Verify transaction list displays and filters correctly',
    'feature': 'Transaction Display',
    'test': 'Open budget detail. View transaction list. Verify transactions are sorted by date (newest first). Verify each transaction shows: type icon, description, category, date, amount. Verify income shows green, expenses show red.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify transaction list display',
        'description': 'Verify transactions are displayed correctly',
        'feature': 'Transaction Display',
        'test': 'Add multiple transactions. Verify all appear in list. Verify correct icons, colors, and formatting.',
      },
      {
        'number': 2,
        'title': 'Verify transaction sorting',
        'description': 'Verify transactions are sorted by date',
        'feature': 'Transaction Display',
        'test': 'Add transactions on different dates. Verify newest transactions appear first in list.',
      },
    ],
  },
];

Future<void> main(List<String> args) async {
  final environment = args.isNotEmpty ? args[0] : 'dev';
  final collectionPrefix = environment == 'dev' ? 'dev_' : (environment == 'qa' ? 'test_' : '');
  final collectionPath = '${collectionPrefix}uat_test_rounds';

  print('Adding Budgeting UAT test cases to $collectionPath...');

  // Authenticate using service account
  final serviceAccountPath = 'scripts/firebase-service-account.json';
  final serviceAccountFile = File(serviceAccountPath);
  
  if (!serviceAccountFile.existsSync()) {
    print('Error: Service account file not found at $serviceAccountPath');
    print('Please ensure the service account JSON file is in the scripts directory.');
    exit(1);
  }

  try {
    final serviceAccountJson = await serviceAccountFile.readAsString();
    final serviceAccount = jsonDecode(serviceAccountJson) as Map<String, dynamic>;
    
    final credentials = auth.ServiceAccountCredentials.fromJson(serviceAccount);
    final client = await auth.clientViaServiceAccount(credentials, [
      'https://www.googleapis.com/auth/cloud-platform',
      'https://www.googleapis.com/auth/datastore',
    ]);

    final token = await client.credentials.accessToken;
    final accessToken = token.data;
    client.close();

    // Create test round
    final roundData = {
      'name': 'Budgeting System UAT',
      'description': 'User Acceptance Testing for the Family Budgeting System',
      'createdBy': 'system',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    final roundId = await createDocument(collectionPath, roundData, accessToken);
    print('✓ Test round created: $roundId');

    // Create test cases
    for (var testCaseData in budgetTestCases) {
      final subTestCases = testCaseData['subTestCases'] as List<Map<String, dynamic>>;
      final testCaseDataCopy = Map<String, dynamic>.from(testCaseData);
      testCaseDataCopy.remove('subTestCases');
      testCaseDataCopy['status'] = 'pending';
      
      print('\nAdding test case ${testCaseData['number']}: ${testCaseData['title']}...');
      
      final testCaseId = await createSubcollectionDocument(
        '$collectionPath/$roundId',
        'test_cases',
        testCaseDataCopy,
        accessToken,
      );
      print('  ✓ Test case added: $testCaseId');

      // Create sub-test cases
      for (var subTestCaseData in subTestCases) {
        final subTestCaseDataCopy = Map<String, dynamic>.from(subTestCaseData);
        subTestCaseDataCopy['status'] = 'pending';
        
        await createSubcollectionDocument(
          '$collectionPath/$roundId/test_cases/$testCaseId',
          'sub_test_cases',
          subTestCaseDataCopy,
          accessToken,
        );
      }
      print('  ✓ ${subTestCases.length} sub-test cases added');
    }

    print('');
    print('✅ Successfully added ${budgetTestCases.length} test cases to $collectionPath');
    print('Test Round ID: $roundId');
    final totalSubTestCases = budgetTestCases.fold<int>(
      0,
      (sum, tc) => sum + (tc['subTestCases'] as List).length,
    );
    print('Total Sub-Test Cases: $totalSubTestCases');
    print('');
  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}

