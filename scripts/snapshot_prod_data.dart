import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

/// ONE-TIME script to snapshot production data and copy to dev and test environments
/// 
/// This script:
/// 1. Reads all data from production collections (no prefix)
/// 2. Copies it to dev_* collections
/// 3. Copies it to test_* collections
/// 4. Handles subcollections recursively
/// 
/// IMPORTANT: This is a ONE-TIME operation. After this, all new data will be
/// separated by environment. This just seeds dev/test with historical prod data.
/// 
/// Usage: dart scripts/snapshot_prod_data.dart
/// 
/// Requirements:
/// - Service account JSON file at: scripts/firebase-service-account.json
/// - Service account must have "Editor" role in Google Cloud Console

const String firebaseProjectId = 'family-hub-71ff0';
String get firestoreBaseUrl => 'https://firestore.googleapis.com/v1/projects/$firebaseProjectId/databases/(default)/documents';

// Collections to copy (root level collections that need environment prefixes)
final List<String> collectionsToCopy = [
  'users',
  'families',
  // Add other collections that need environment prefixes here
];

// Subcollections within families that need to be copied
final List<String> familySubcollections = [
  'tasks',
  'events',
  'messages',
  'privateMessages',
  'photos',
  'albums',
  'payoutRequests',
  'payouts',
  'recurringPayments',
  'pocketMoneyPayments',
  'notifications',
  'game_stats',
  'shoppingLists',
  'shoppingReceipts',
  'budgets',
];

// Subcollections within tasks
final List<String> taskSubcollections = [
  'dependencies',
];

// Subcollections within events
final List<String> eventSubcollections = [
  'chats',
];

// Subcollections within messages
final List<String> messageSubcollections = [
  'reactions',
  'replies',
];

// Subcollections within privateMessages
final List<String> privateMessageSubcollections = [
  'messages',
  'readStatus',
];

// Subcollections within albums
final List<String> albumSubcollections = [
  'photos',
];

// Subcollections within photos
final List<String> photoSubcollections = [
  'comments',
];

// Subcollections within shoppingLists
final List<String> shoppingListSubcollections = [
  'items',
];

// Subcollections within budgets
final List<String> budgetSubcollections = [
  'categories',
  'transactions',
  'savingsGoals',
];

/// Get access token from service account
Future<String> getAccessToken() async {
  final serviceAccountPath = 'scripts/firebase-service-account.json';
  final serviceAccountFile = File(serviceAccountPath);
  
  if (!await serviceAccountFile.exists()) {
    throw Exception('Service account file not found at: $serviceAccountPath\n'
        'Please ensure the service account JSON file is in the scripts directory.');
  }
  
  final serviceAccountJson = json.decode(await serviceAccountFile.readAsString());
  final credentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
  
  final client = await auth.clientViaServiceAccount(
    credentials,
    ['https://www.googleapis.com/auth/datastore'],
  );
  
  final accessToken = client.credentials.accessToken;
  return accessToken.data;
}

/// List all documents in a collection
Future<List<Map<String, dynamic>>> listDocuments(String collectionPath, String accessToken) async {
  final url = '$firestoreBaseUrl/$collectionPath';
  final response = await http.get(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
  );
  
  if (response.statusCode != 200) {
    if (response.statusCode == 404) {
      // Collection doesn't exist or is empty - that's okay
      return [];
    }
    throw Exception('Failed to list documents in $collectionPath: ${response.statusCode}\n${response.body}');
  }
  
  final data = json.decode(response.body);
  final documents = <Map<String, dynamic>>[];
  
  if (data.containsKey('documents')) {
    for (var doc in data['documents']) {
      documents.add(doc);
    }
  }
  
  return documents;
}

/// Get a single document
Future<Map<String, dynamic>?> getDocument(String documentPath, String accessToken) async {
  final url = '$firestoreBaseUrl/$documentPath';
  final response = await http.get(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
  );
  
  if (response.statusCode == 404) {
    return null;
  }
  
  if (response.statusCode != 200) {
    throw Exception('Failed to get document $documentPath: ${response.statusCode}\n${response.body}');
  }
  
  return json.decode(response.body);
}

/// Create a document with a specific ID
/// Data should already be in Firestore REST API format (from getDocument/listDocuments)
/// documentPath should be relative to firestoreBaseUrl (e.g., "dev_users/userId" or "dev_families/familyId/tasks/taskId")
/// Uses PATCH to create/update document with specific ID
Future<void> createDocument(String documentPath, Map<String, dynamic> data, String accessToken) async {
  // Ensure documentPath doesn't start with / and is relative
  final cleanPath = documentPath.startsWith('/') ? documentPath.substring(1) : documentPath;
  final url = '$firestoreBaseUrl/$cleanPath';
  
  // Data from Firestore REST API is already in the correct format
  // Just wrap it in the document structure
  final firestoreData = {
    'fields': data,
  };
  
  // Use PATCH to create/update document with specific ID
  // PATCH will create if doesn't exist, update if it does
  final response = await http.patch(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: json.encode(firestoreData),
  );
  
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('Failed to create document $documentPath: ${response.statusCode}\n${response.body}');
  }
}

/// Copy a document and its subcollections
Future<void> copyDocument(
  String sourcePath,
  String targetPath,
  String accessToken,
  List<String> subcollections,
) async {
  // Get the source document
  final sourceDoc = await getDocument(sourcePath, accessToken);
  if (sourceDoc == null) {
    print('  ⚠️  Document not found: $sourcePath');
    return;
  }
  
  // Extract document data (skip metadata fields)
  final docData = sourceDoc['fields'] ?? {};
  final docId = sourcePath.split('/').last;
  
  // Create the target document
  try {
    await createDocument('$targetPath/$docId', docData, accessToken);
    print('  ✅ Copied document: $docId');
  } catch (e) {
    print('  ❌ Failed to copy document $docId: $e');
    return;
  }
  
  // Copy subcollections
  for (var subcollection in subcollections) {
    final sourceSubPath = '$sourcePath/$docId/$subcollection';
    final targetSubPath = '$targetPath/$docId/$subcollection';
    
    try {
      final subDocs = await listDocuments(sourceSubPath, accessToken);
      if (subDocs.isEmpty) continue;
      
      print('    📁 Copying subcollection: $subcollection (${subDocs.length} documents)');
      
      for (var subDoc in subDocs) {
        final subDocId = subDoc['name']?.split('/').last ?? '';
        final subDocData = subDoc['fields'] ?? {};
        
        // Determine nested subcollections based on parent type
        List<String> nestedSubcollections = [];
        if (subcollection == 'tasks') {
          nestedSubcollections = taskSubcollections;
        } else if (subcollection == 'events') {
          nestedSubcollections = eventSubcollections;
        } else if (subcollection == 'messages') {
          nestedSubcollections = messageSubcollections;
        } else if (subcollection == 'privateMessages') {
          nestedSubcollections = privateMessageSubcollections;
        } else if (subcollection == 'albums') {
          nestedSubcollections = albumSubcollections;
        } else if (subcollection == 'photos') {
          nestedSubcollections = photoSubcollections;
        } else if (subcollection == 'shoppingLists') {
          nestedSubcollections = shoppingListSubcollections;
        } else if (subcollection == 'budgets') {
          nestedSubcollections = budgetSubcollections;
        }
        
        // Copy nested subcollections recursively
        if (nestedSubcollections.isNotEmpty) {
          for (var nestedSub in nestedSubcollections) {
            final nestedSourcePath = '$sourceSubPath/$subDocId/$nestedSub';
            final nestedTargetPath = '$targetSubPath/$subDocId/$nestedSub';
            
            try {
              final nestedDocs = await listDocuments(nestedSourcePath, accessToken);
              if (nestedDocs.isEmpty) continue;
              
              for (var nestedDoc in nestedDocs) {
                final nestedDocId = nestedDoc['name']?.split('/').last ?? '';
                final nestedDocData = nestedDoc['fields'] ?? {};
                
                try {
                  await createDocument('$nestedTargetPath/$nestedDocId', nestedDocData, accessToken);
                } catch (e) {
                  print('      ❌ Failed to copy nested document $nestedDocId: $e');
                }
              }
            } catch (e) {
              // Subcollection might not exist - that's okay
            }
          }
        }
        
        try {
          await createDocument('$targetSubPath/$subDocId', subDocData, accessToken);
        } catch (e) {
          print('      ❌ Failed to copy sub-document $subDocId: $e');
        }
      }
    } catch (e) {
      // Subcollection might not exist - that's okay
      print('    ⚠️  Subcollection $subcollection not found or empty');
    }
  }
}

/// Copy a collection to target environments
Future<void> copyCollection(
  String collectionName,
  String accessToken,
  List<String> subcollections,
) async {
  print('\n📦 Copying collection: $collectionName');
  
  // List all documents in production
  final prodDocs = await listDocuments(collectionName, accessToken);
  
  if (prodDocs.isEmpty) {
    print('  ℹ️  No documents found in production $collectionName');
    return;
  }
  
  print('  Found ${prodDocs.length} documents in production');
  
  // Copy to dev
  print('\n  🛠️  Copying to dev_$collectionName...');
  for (var doc in prodDocs) {
    final docName = doc['name'] ?? '';
    final docId = docName.split('/').last;
    
    await copyDocument(
      '$collectionName/$docId',
      'dev_$collectionName',
      accessToken,
      subcollections,
    );
  }
  
  // Copy to test
  print('\n  🧪 Copying to test_$collectionName...');
  for (var doc in prodDocs) {
    final docName = doc['name'] ?? '';
    final docId = docName.split('/').last;
    
    await copyDocument(
      '$collectionName/$docId',
      'test_$collectionName',
      accessToken,
      subcollections,
    );
  }
  
  print('  ✅ Completed copying $collectionName');
}

/// Main function
Future<void> main(List<String> args) async {
  print('=' * 80);
  print('ONE-TIME PRODUCTION DATA SNAPSHOT');
  print('=' * 80);
  print('\nThis script will:');
  print('  1. Read all data from production collections (no prefix)');
  print('  2. Copy to dev_* collections');
  print('  3. Copy to test_* collections');
  print('  4. Handle subcollections recursively');
  print('\n⚠️  WARNING: This is a ONE-TIME operation!');
  print('   After this, all new data will remain separated by environment.');
  print('   This just seeds dev/test with historical production data.\n');
  
  // Allow --yes flag to skip confirmation
  final skipConfirmation = args.contains('--yes') || args.contains('-y');
  
  if (!skipConfirmation) {
    stdout.write('Do you want to continue? (yes/no): ');
    final confirmation = stdin.readLineSync()?.toLowerCase();
    
    if (confirmation != 'yes' && confirmation != 'y') {
      print('Operation cancelled.');
      exit(0);
    }
  } else {
    print('⚠️  Running with --yes flag (skipping confirmation)\n');
  }
  
  try {
    print('\n🔐 Authenticating with service account...');
    final accessToken = await getAccessToken();
    print('✅ Authentication successful\n');
    
    // Copy users collection
    await copyCollection('users', accessToken, ['ignoredConflicts']);
    
    // Copy families collection with all subcollections
    await copyCollection('families', accessToken, familySubcollections);
    
    print('\n' + '=' * 80);
    print('✅ SNAPSHOT COMPLETE!');
    print('=' * 80);
    print('\nProduction data has been copied to dev and test environments.');
    print('All future data will remain separated by environment.\n');
    
  } catch (e, stackTrace) {
    print('\n❌ ERROR: $e');
    print('\nStack trace:');
    print(stackTrace);
    exit(1);
  }
}

