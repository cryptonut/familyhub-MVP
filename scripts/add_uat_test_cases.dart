import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

/// Standalone script to add UAT test cases using Firebase REST API
/// 
/// This version uses HTTP requests directly via the `http` package,
/// avoiding Flutter-specific dependencies that require compilation
/// 
/// Usage: dart scripts/add_uat_test_cases.dart [environment] [access_token]
/// 
/// Environment options: dev, qa, prod (default: dev)
/// 
/// Authentication:
/// Option 1: Get access token from Firebase CLI: firebase login:ci
/// Option 2: Use service account (set GOOGLE_APPLICATION_CREDENTIALS env var)
/// Option 3: Get token from running app (check logs for Firebase auth token)
/// 
/// This script adds test cases to Firestore for the UAT system.
/// Test cases are added to the appropriate collection based on environment:
/// - dev: dev_uat_test_rounds
/// - qa: test_uat_test_rounds
/// - prod: uat_test_rounds

const String firebaseProjectId = 'family-hub-71ff0';
String get firestoreBaseUrl => 'https://firestore.googleapis.com/v1/projects/$firebaseProjectId/databases/(default)/documents';

// Test cases data structure
final testCasesData = [
  {
    'number': 1,
    'title': 'Data Isolation Between Environments',
    'description': 'Verify that data created in dev environment is isolated from QA and production environments',
    'feature': 'Data Isolation',
    'test': 'Create data in dev environment (tasks, messages, events). Verify data appears in dev_* collections in Firebase Console. Verify data does NOT appear in unprefixed or test_* collections. Switch to QA environment and verify data is isolated.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify users collection isolation',
        'description': 'Create user in dev → verify in dev_users. Create user in QA → verify in test_users. Verify no cross-contamination.',
        'feature': 'Data Isolation',
        'test': 'Check Firebase Console collections',
      },
      {
        'number': 2,
        'title': 'Verify families collection isolation',
        'description': 'Create family in dev → verify in dev_families. Create family in QA → verify in test_families. Verify no cross-contamination.',
        'feature': 'Data Isolation',
        'test': 'Check Firebase Console collections',
      },
      {
        'number': 3,
        'title': 'Verify subcollections isolation',
        'description': 'Create tasks in dev → verify in dev_families/{id}/tasks. Create messages in dev → verify in dev_families/{id}/messages. Create events in dev → verify in dev_families/{id}/events. Verify QA environment doesn\'t see dev data.',
        'feature': 'Data Isolation',
        'test': 'Check Firebase Console subcollections',
      },
      {
        'number': 4,
        'title': 'Verify production uses unprefixed paths',
        'description': 'Run app in prod flavor. Verify data created in unprefixed collections (users, families). Verify backward compatibility with existing production data.',
        'feature': 'Data Isolation',
        'test': 'Run prod flavor and check collections',
      },
    ],
  },
  {
    'number': 2,
    'title': 'Subscription Fields in UserModel',
    'description': 'Verify that UserModel correctly stores and retrieves subscription information',
    'feature': 'Subscription Management',
    'test': 'Verify UserModel has subscription fields (tier, status, expiresAt, etc.). Verify subscription fields are saved to Firestore correctly. Verify subscription fields are loaded from Firestore correctly. Verify helper methods (hasActivePremiumSubscription, hasPremiumHubAccess) work correctly.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify subscription tier storage',
        'description': 'Set subscription tier to premium. Verify tier is saved to Firestore. Reload user model and verify tier is correct.',
        'feature': 'Subscription Management',
        'test': 'Update user subscription and verify in Firestore',
      },
      {
        'number': 2,
        'title': 'Verify subscription status storage',
        'description': 'Set subscription status to active. Verify status is saved to Firestore. Reload user model and verify status is correct.',
        'feature': 'Subscription Management',
        'test': 'Update subscription status and verify',
      },
      {
        'number': 3,
        'title': 'Verify subscription expiration',
        'description': 'Set expiration date. Verify date is saved correctly. Verify days until expiration calculation works.',
        'feature': 'Subscription Management',
        'test': 'Set expiration and verify calculation',
      },
      {
        'number': 4,
        'title': 'Verify premium hub access check',
        'description': 'Add premium hub type to user. Verify hasPremiumHubAccess returns true for that hub type. Verify hasPremiumHubAccess returns false for other hub types.',
        'feature': 'Subscription Management',
        'test': 'Test hasPremiumHubAccess method',
      },
    ],
  },
  {
    'number': 3,
    'title': 'AppConfig Premium Feature Flags',
    'description': 'Verify that premium feature flags are correctly configured per environment',
    'feature': 'Feature Flags',
    'test': 'Verify dev environment has premium features enabled. Verify QA environment has premium features enabled. Verify prod environment has premium features disabled (until launch). Verify flags are accessible via Config.current.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify dev flags',
        'description': 'Run app in dev flavor. Verify enablePremiumHubs = true. Verify enableExtendedFamilyHub = true. Verify enableHomeschoolingHub = true. Verify enableCoparentingHub = true. Verify enableEncryptedChat = true.',
        'feature': 'Feature Flags',
        'test': 'Check Config.current values in dev',
      },
      {
        'number': 2,
        'title': 'Verify QA flags',
        'description': 'Run app in QA flavor. Verify all premium flags are true (same as dev).',
        'feature': 'Feature Flags',
        'test': 'Check Config.current values in QA',
      },
      {
        'number': 3,
        'title': 'Verify prod flags',
        'description': 'Run app in prod flavor. Verify enablePremiumHubs = false. Verify all premium hub flags are false. Verify enableEncryptedChat = false.',
        'feature': 'Feature Flags',
        'test': 'Check Config.current values in prod',
      },
    ],
  },
  {
    'number': 4,
    'title': 'Subscription Service - IAP Integration',
    'description': 'Verify that SubscriptionService correctly handles IAP operations',
    'feature': 'In-App Purchases',
    'test': 'Verify service initializes correctly. Verify hasActiveSubscription() returns correct status. Verify getCurrentTier() returns correct tier. Verify getAvailableProducts() returns products (if configured). Verify purchase flow (if IAP products are configured). Verify restore purchases functionality.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify service initialization',
        'description': 'Initialize SubscriptionService. Verify no errors. Verify IAP availability check works.',
        'feature': 'In-App Purchases',
        'test': 'Check service initialization logs',
      },
      {
        'number': 2,
        'title': 'Verify subscription status checks',
        'description': 'Check hasActiveSubscription() for free user → should return false. Check hasActiveSubscription() for premium user → should return true. Check getCurrentTier() → should return correct tier.',
        'feature': 'In-App Purchases',
        'test': 'Test subscription status methods',
      },
      {
        'number': 3,
        'title': 'Verify product listing',
        'description': 'Call getAvailableProducts(). Verify products are returned (if configured in Play Console/App Store). Verify product details (price, description) are correct.',
        'feature': 'In-App Purchases',
        'test': 'Test product listing (requires IAP setup)',
      },
      {
        'number': 4,
        'title': 'Verify purchase flow (requires IAP setup)',
        'description': 'Attempt to purchase subscription. Verify purchase is processed. Verify subscription status is updated in Firestore. Verify user model reflects new subscription.',
        'feature': 'In-App Purchases',
        'test': 'Test purchase flow (requires IAP products)',
      },
      {
        'number': 5,
        'title': 'Verify restore purchases',
        'description': 'Call restorePurchases(). Verify existing purchases are restored. Verify subscription status is updated.',
        'feature': 'In-App Purchases',
        'test': 'Test restore purchases functionality',
      },
    ],
  },
  {
    'number': 5,
    'title': 'Premium Feature Gate Widget',
    'description': 'Verify that PremiumFeatureGate correctly gates premium features',
    'feature': 'Feature Gating',
    'test': 'Verify widget shows child for premium users. Verify widget shows fallback/upgrade prompt for free users. Verify widget handles loading state. Verify widget checks subscription correctly.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify free user sees upgrade prompt',
        'description': 'Wrap feature in PremiumFeatureGate. Verify free user sees upgrade prompt. Verify upgrade button is clickable.',
        'feature': 'Feature Gating',
        'test': 'Test PremiumFeatureGate with free user',
      },
      {
        'number': 2,
        'title': 'Verify premium user sees content',
        'description': 'Wrap feature in PremiumFeatureGate. Verify premium user sees actual content (child widget). Verify no upgrade prompt is shown.',
        'feature': 'Feature Gating',
        'test': 'Test PremiumFeatureGate with premium user',
      },
      {
        'number': 3,
        'title': 'Verify hub-specific gating',
        'description': 'Use PremiumFeatureGate with requiredHubType. Verify user with access sees content. Verify user without access sees upgrade prompt.',
        'feature': 'Feature Gating',
        'test': 'Test hub-specific gating',
      },
      {
        'number': 4,
        'title': 'Verify custom fallback',
        'description': 'Provide custom fallback widget. Verify custom fallback is shown for free users. Verify custom fallback is not shown for premium users.',
        'feature': 'Feature Gating',
        'test': 'Test custom fallback widget',
      },
    ],
  },
  {
    'number': 6,
    'title': 'Subscription Screen UI',
    'description': 'Verify that SubscriptionScreen displays and manages subscriptions correctly',
    'feature': 'Subscription Management UI',
    'test': 'Verify screen loads without errors. Verify current subscription is displayed correctly. Verify premium features list is shown. Verify upgrade options are displayed for free users. Verify purchase buttons work (if IAP configured). Verify restore purchases button works.',
    'subTestCases': [
      {
        'number': 1,
        'title': 'Verify screen loads',
        'description': 'Navigate to Subscription screen. Verify no errors. Verify loading indicator shows then disappears.',
        'feature': 'Subscription Management UI',
        'test': 'Navigate to subscription screen',
      },
      {
        'number': 2,
        'title': 'Verify free user view',
        'description': 'View subscription screen as free user. Verify "Free" tier is displayed. Verify upgrade options are shown. Verify product cards are displayed (if products available).',
        'feature': 'Subscription Management UI',
        'test': 'Test subscription screen as free user',
      },
      {
        'number': 3,
        'title': 'Verify premium user view',
        'description': 'View subscription screen as premium user. Verify "Premium" tier is displayed. Verify subscription status is shown. Verify expiration date is displayed. Verify days remaining is calculated correctly. Verify "Manage Subscription" section is shown.',
        'feature': 'Subscription Management UI',
        'test': 'Test subscription screen as premium user',
      },
      {
        'number': 4,
        'title': 'Verify premium features list',
        'description': 'Verify all premium features are listed. Verify features show checkmark for premium users. Verify features show lock icon for free users.',
        'feature': 'Subscription Management UI',
        'test': 'Check premium features list display',
      },
      {
        'number': 5,
        'title': 'Verify purchase flow (requires IAP setup)',
        'description': 'Tap purchase button on product card. Verify purchase dialog appears. Complete purchase. Verify subscription screen updates. Verify success message is shown.',
        'feature': 'Subscription Management UI',
        'test': 'Test purchase flow (requires IAP products)',
      },
      {
        'number': 6,
        'title': 'Verify restore purchases',
        'description': 'Tap "Restore Purchases" button. Verify restore process completes. Verify subscription screen updates. Verify success message is shown.',
        'feature': 'Subscription Management UI',
        'test': 'Test restore purchases button',
      },
    ],
  },
];

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

Future<void> main(List<String> args) async {
  print('=' * 60);
  print('UAT Test Cases Addition Script (Standalone)');
  print('=' * 60);
  print('');
  
  // Determine environment
  final env = args.isNotEmpty ? args[0].toLowerCase() : 'dev';
  final prefix = env == 'dev' ? 'dev_' : (env == 'qa' ? 'test_' : '');
  final collectionPath = '${prefix}uat_test_rounds';
  
  // Get access token from args, environment, or service account
  String? accessToken = args.length > 1 ? args[1] : Platform.environment['FIREBASE_ACCESS_TOKEN'];
  
  // Check for service account JSON file
  final serviceAccountPath = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'] ?? 
                            (File('scripts/firebase-service-account.json').existsSync() 
                              ? 'scripts/firebase-service-account.json' 
                              : null);
  
  print('Environment: $env');
  print('Collection path: $collectionPath');
  print('Firebase Project: $firebaseProjectId');
  print('');
  
  // If no access token but service account exists, use it to get a token
  if ((accessToken == null || accessToken.isEmpty) && serviceAccountPath != null) {
    print('Found service account file: $serviceAccountPath');
    print('Authenticating with service account...');
    
    try {
      final serviceAccountFile = File(serviceAccountPath);
      if (!serviceAccountFile.existsSync()) {
        throw Exception('Service account file not found: $serviceAccountPath');
      }
      
      final serviceAccountJson = jsonDecode(await serviceAccountFile.readAsString()) as Map<String, dynamic>;
      final credentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
      final client = await auth.clientViaServiceAccount(
        credentials,
        [
          'https://www.googleapis.com/auth/cloud-platform',
          'https://www.googleapis.com/auth/datastore',
        ],
      );
      
      // Get access token from the authenticated client
      final token = await client.credentials.accessToken;
      accessToken = token.data;
      
      print('Service account email: ${credentials.email}');
      print('Token scopes: ${client.credentials.scopes}');
      
      print('✓ Authentication successful!');
      print('');
    } catch (e) {
      print('❌ Failed to authenticate with service account: $e');
      print('');
      print('Please check:');
      print('  1. Service account file exists: $serviceAccountPath');
      print('  2. Service account has "Cloud Datastore User" role');
      print('  3. Service account JSON is valid');
      print('');
      exit(1);
    }
  }
  
  if (accessToken == null || accessToken.isEmpty) {
    print('⚠️  Access token required!');
    print('');
    print('The script needs authentication to write to Firestore.');
    print('');
    print('RECOMMENDED: Use Service Account (see scripts/README_ADD_UAT_TEST_CASES.md)');
    print('');
    print('QUICK START:');
    print('  1. Create service account in Google Cloud Console');
    print('  2. Download JSON key file');
    print('  3. Save as: scripts/firebase-service-account.json');
    print('  4. Run: dart scripts/add_uat_test_cases.dart dev');
    print('');
    print('OR provide access token:');
    print('  dart scripts/add_uat_test_cases.dart dev YOUR_TOKEN');
    print('');
    print('For detailed instructions, see: scripts/README_ADD_UAT_TEST_CASES.md');
    print('');
    exit(1);
  }
  
  print('Creating test round...');
  
  try {
    // Create test round
    final roundData = {
      'name': 'Roadmap Phase 1.1 & 1.2 Implementation',
      'description': 'Testing data isolation, subscription management, and premium features',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'createdBy': 'system',
    };
    
    final roundId = await createDocument(collectionPath, roundData, accessToken);
    print('✓ Test round created: $roundId');
    
    // Add test cases
    for (var testCaseData in testCasesData) {
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
      
      // Add sub-test cases
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
    print('✅ All test cases added successfully!');
    print('Test Round ID: $roundId');
    print('Total Test Cases: ${testCasesData.length}');
    final totalSubTestCases = testCasesData.fold<int>(
      0,
      (sum, tc) => sum + (tc['subTestCases'] as List).length,
    );
    print('Total Sub-Test Cases: $totalSubTestCases');
    print('');
    
  } catch (e, st) {
    print('');
    print('❌ Error: $e');
    print('');
    if (e.toString().contains('401')) {
      print('Authentication failed. Please check your access token or service account.');
    } else if (e.toString().contains('403')) {
      print('Permission denied. The service account needs proper IAM role.');
      print('');
      print('Please verify:');
      print('  1. Service account has "Cloud Datastore User" role');
      print('  2. Or try "Cloud Firestore User" role instead');
      print('  3. Check IAM permissions in Google Cloud Console');
      print('');
      print('To fix:');
      print('  1. Go to: https://console.cloud.google.com/iam-admin/iam?project=family-hub-71ff0');
      print('  2. Find your service account');
      print('  3. Click "Edit" (pencil icon)');
      print('  4. Ensure role is "Cloud Datastore User" or "Cloud Firestore User"');
      print('  5. Click "Save"');
    }
    print('');
    exit(1);
  }
  
  exit(0);
}
