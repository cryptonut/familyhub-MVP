import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../models/user_model.dart';
import '../utils/firestore_path_utils.dart';
import '../services/auth_service.dart';

/// Service for managing User Acceptance Testing (UAT) test cases
class UATService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  /// Get all test rounds
  /// Checks both prefixed and unprefixed collections to find all test rounds
  /// In dev flavor, this ensures test artifacts from unprefixed collection are visible
  Future<List<UATTestRound>> getTestRounds() async {
    try {
      final prefixedPath = FirestorePathUtils.getCollectionPath('uat_test_rounds');
      final unprefixedPath = 'uat_test_rounds';
      
      final allRounds = <String, UATTestRound>{};
      
      Logger.info('getTestRounds: Querying prefixed path: $prefixedPath', tag: 'UATService');
      
      // Query prefixed collection (environment-specific)
      try {
        final prefixedSnapshot = await _firestore
            .collection(prefixedPath)
            .orderBy('createdAt', descending: true)
            .get();
        
        Logger.info('getTestRounds: Found ${prefixedSnapshot.docs.length} rounds in prefixed collection', tag: 'UATService');
        
        for (var doc in prefixedSnapshot.docs) {
          try {
            allRounds[doc.id] = UATTestRound.fromJson(doc.data(), doc.id);
            Logger.info('getTestRounds: Successfully parsed round ${doc.id}', tag: 'UATService');
          } catch (parseError, parseSt) {
            Logger.error('Error parsing UAT round ${doc.id}: $parseError', error: parseError, stackTrace: parseSt, tag: 'UATService');
            Logger.info('getTestRounds: Document data: ${doc.data()}', tag: 'UATService');
          }
        }
      } catch (e, st) {
        Logger.error('Error querying prefixed UAT rounds: $e', error: e, stackTrace: st, tag: 'UATService');
      }
      
      // ALWAYS query unprefixed collection (for shared test artifacts)
      // This ensures dev flavor can see test artifacts created in prod or shared collections
      try {
        Logger.info('getTestRounds: Querying unprefixed path: $unprefixedPath', tag: 'UATService');
        final unprefixedSnapshot = await _firestore
            .collection(unprefixedPath)
            .orderBy('createdAt', descending: true)
            .get();
        
        Logger.info('getTestRounds: Found ${unprefixedSnapshot.docs.length} rounds in unprefixed collection', tag: 'UATService');
        
        for (var doc in unprefixedSnapshot.docs) {
          // Use round ID as key to avoid duplicates (prefixed takes precedence if same ID exists)
          if (!allRounds.containsKey(doc.id)) {
            allRounds[doc.id] = UATTestRound.fromJson(doc.data(), doc.id);
          }
        }
      } catch (e, st) {
        Logger.warning('Error querying unprefixed UAT rounds', error: e, stackTrace: st, tag: 'UATService');
      }
      
      final result = allRounds.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      Logger.info('getTestRounds: Returning ${result.length} total test rounds', tag: 'UATService');
      return result;
    } catch (e, st) {
      Logger.error('Error fetching test rounds', error: e, stackTrace: st, tag: 'UATService');
      return [];
    }
  }

  /// Get test cases for a specific round
  /// Checks both prefixed and unprefixed collections
  /// In dev flavor, this ensures test cases from unprefixed collection are visible
  Future<List<UATTestCase>> getTestCases(String roundId) async {
    try {
      final prefixedPath = FirestorePathUtils.getCollectionPath('uat_test_rounds');
      final unprefixedPath = 'uat_test_rounds';
      
      final allCases = <String, UATTestCase>{};
      
      Logger.debug('getTestCases: Querying test cases for round $roundId', tag: 'UATService');
      
      // Try prefixed collection first (environment-specific)
      try {
        final prefixedSnapshot = await _firestore
            .collection(prefixedPath)
            .doc(roundId)
            .collection('test_cases')
            .orderBy('number')
            .get();
        
        Logger.debug('getTestCases: Found ${prefixedSnapshot.docs.length} test cases in prefixed collection', tag: 'UATService');
        
        for (var doc in prefixedSnapshot.docs) {
          allCases[doc.id] = UATTestCase.fromJson(doc.data(), doc.id);
        }
      } catch (e, st) {
        Logger.warning('Error querying prefixed test cases', error: e, stackTrace: st, tag: 'UATService');
      }
      
      // ALWAYS try unprefixed collection (for shared test artifacts)
      // This ensures dev flavor can see test cases created in prod or shared collections
      try {
        final unprefixedSnapshot = await _firestore
            .collection(unprefixedPath)
            .doc(roundId)
            .collection('test_cases')
            .orderBy('number')
            .get();
        
        Logger.debug('getTestCases: Found ${unprefixedSnapshot.docs.length} test cases in unprefixed collection', tag: 'UATService');
        
        for (var doc in unprefixedSnapshot.docs) {
          // Prefixed takes precedence if same ID exists
          if (!allCases.containsKey(doc.id)) {
            allCases[doc.id] = UATTestCase.fromJson(doc.data(), doc.id);
          }
        }
      } catch (e, st) {
        Logger.warning('Error querying unprefixed test cases', error: e, stackTrace: st, tag: 'UATService');
      }
      
      final result = allCases.values.toList()
        ..sort((a, b) => a.number.compareTo(b.number));
      
      Logger.info('getTestCases: Returning ${result.length} total test cases for round $roundId', tag: 'UATService');
      return result;
    } catch (e, st) {
      Logger.error('Error fetching test cases', error: e, stackTrace: st, tag: 'UATService');
      return [];
    }
  }

  /// Get sub-test cases for a test case
  /// Checks both prefixed and unprefixed collections
  /// In dev flavor, this ensures sub-test cases from unprefixed collection are visible
  Future<List<UATSubTestCase>> getSubTestCases(String roundId, String testCaseId) async {
    try {
      final prefixedPath = FirestorePathUtils.getCollectionPath('uat_test_rounds');
      final unprefixedPath = 'uat_test_rounds';
      
      final allSubCases = <String, UATSubTestCase>{};
      
      Logger.debug('getSubTestCases: Querying sub-test cases for round $roundId, test case $testCaseId', tag: 'UATService');
      
      // Try prefixed collection first (environment-specific)
      try {
        final prefixedSnapshot = await _firestore
            .collection(prefixedPath)
            .doc(roundId)
            .collection('test_cases')
            .doc(testCaseId)
            .collection('sub_test_cases')
            .orderBy('number')
            .get();
        
        Logger.debug('getSubTestCases: Found ${prefixedSnapshot.docs.length} sub-test cases in prefixed collection', tag: 'UATService');
        
        for (var doc in prefixedSnapshot.docs) {
          allSubCases[doc.id] = UATSubTestCase.fromJson(doc.data(), doc.id);
        }
      } catch (e, st) {
        Logger.warning('Error querying prefixed sub-test cases', error: e, stackTrace: st, tag: 'UATService');
      }
      
      // ALWAYS try unprefixed collection (for shared test artifacts)
      // This ensures dev flavor can see sub-test cases created in prod or shared collections
      try {
        final unprefixedSnapshot = await _firestore
            .collection(unprefixedPath)
            .doc(roundId)
            .collection('test_cases')
            .doc(testCaseId)
            .collection('sub_test_cases')
            .orderBy('number')
            .get();
        
        Logger.debug('getSubTestCases: Found ${unprefixedSnapshot.docs.length} sub-test cases in unprefixed collection', tag: 'UATService');
        
        for (var doc in unprefixedSnapshot.docs) {
          // Prefixed takes precedence if same ID exists
          if (!allSubCases.containsKey(doc.id)) {
            allSubCases[doc.id] = UATSubTestCase.fromJson(doc.data(), doc.id);
          }
        }
      } catch (e, st) {
        Logger.warning('Error querying unprefixed sub-test cases', error: e, stackTrace: st, tag: 'UATService');
      }
      
      final result = allSubCases.values.toList()
        ..sort((a, b) => a.number.compareTo(b.number));
      
      Logger.info('getSubTestCases: Returning ${result.length} total sub-test cases', tag: 'UATService');
      return result;
    } catch (e, st) {
      Logger.error('Error fetching sub test cases', error: e, stackTrace: st, tag: 'UATService');
      return [];
    }
  }

  /// Mark a test case or sub-test case as passed
  Future<void> markAsPassed({
    required String roundId,
    required String testCaseId,
    String? subTestCaseId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final userModel = await _authService.getCurrentUserModel();
      final testerName = userModel?.displayName ?? 'Unknown';

      if (subTestCaseId != null) {
        // Mark sub-test case
        await _firestore
            .collection(FirestorePathUtils.getCollectionPath('uat_test_rounds'))
            .doc(roundId)
            .collection('test_cases')
            .doc(testCaseId)
            .collection('sub_test_cases')
            .doc(subTestCaseId)
            .update({
          'status': 'passed',
          'testedBy': testerName,
          'testedById': userId,
          'testedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Mark test case
        await _firestore
            .collection(FirestorePathUtils.getCollectionPath('uat_test_rounds'))
            .doc(roundId)
            .collection('test_cases')
            .doc(testCaseId)
            .update({
          'status': 'passed',
          'testedBy': testerName,
          'testedById': userId,
          'testedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      Logger.error('Error marking test as passed', error: e, tag: 'UATService');
      rethrow;
    }
  }

  /// Mark a test case or sub-test case as failed
  Future<void> markAsFailed({
    required String roundId,
    required String testCaseId,
    String? subTestCaseId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final userModel = await _authService.getCurrentUserModel();
      final testerName = userModel?.displayName ?? 'Unknown';

      if (subTestCaseId != null) {
        // Mark sub-test case
        await _firestore
            .collection(FirestorePathUtils.getCollectionPath('uat_test_rounds'))
            .doc(roundId)
            .collection('test_cases')
            .doc(testCaseId)
            .collection('sub_test_cases')
            .doc(subTestCaseId)
            .update({
          'status': 'failed',
          'testedBy': testerName,
          'testedById': userId,
          'testedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Mark test case
        await _firestore
            .collection(FirestorePathUtils.getCollectionPath('uat_test_rounds'))
            .doc(roundId)
            .collection('test_cases')
            .doc(testCaseId)
            .update({
          'status': 'failed',
          'testedBy': testerName,
          'testedById': userId,
          'testedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      Logger.error('Error marking test as failed', error: e, tag: 'UATService');
      rethrow;
    }
  }

  /// Create a new test round (admin/tester only)
  Future<String> createTestRound({
    required String name,
    required String description,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null || (!userModel.hasRole('tester') && !userModel.hasRole('admin'))) {
        throw Exception('Only testers and admins can create test rounds');
      }

      final roundRef = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('uat_test_rounds'))
          .add({
        'name': name,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
      });

      Logger.info('Test round created: ${roundRef.id}', tag: 'UATService');
      return roundRef.id;
    } catch (e) {
      Logger.error('Error creating test round', error: e, tag: 'UATService');
      rethrow;
    }
  }

  /// Add a test case to a round (admin/tester only)
  Future<String> addTestCase({
    required String roundId,
    required int number,
    required String title,
    required String description,
    String? feature,
    String? test,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null || (!userModel.hasRole('tester') && !userModel.hasRole('admin'))) {
        throw Exception('Only testers and admins can add test cases');
      }

      final testCaseRef = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('uat_test_rounds'))
          .doc(roundId)
          .collection('test_cases')
          .add({
        'number': number,
        'title': title,
        'description': description,
        if (feature != null) 'feature': feature,
        if (test != null) 'test': test,
        'status': 'pending',
      });

      Logger.info('Test case added: ${testCaseRef.id}', tag: 'UATService');
      return testCaseRef.id;
    } catch (e) {
      Logger.error('Error adding test case', error: e, tag: 'UATService');
      rethrow;
    }
  }

  /// Add a sub-test case to a test case (admin/tester only)
  Future<String> addSubTestCase({
    required String roundId,
    required String testCaseId,
    required int number,
    required String title,
    required String description,
    String? feature,
    String? test,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null || (!userModel.hasRole('tester') && !userModel.hasRole('admin'))) {
        throw Exception('Only testers and admins can add sub-test cases');
      }

      final subTestCaseRef = await _firestore
          .collection(FirestorePathUtils.getCollectionPath('uat_test_rounds'))
          .doc(roundId)
          .collection('test_cases')
          .doc(testCaseId)
          .collection('sub_test_cases')
          .add({
        'number': number,
        'title': title,
        'description': description,
        if (feature != null) 'feature': feature,
        if (test != null) 'test': test,
        'status': 'pending',
      });

      Logger.info('Sub-test case added: ${subTestCaseRef.id}', tag: 'UATService');
      return subTestCaseRef.id;
    } catch (e) {
      Logger.error('Error adding sub-test case', error: e, tag: 'UATService');
      rethrow;
    }
  }

  /// Check if current user is a tester
  Future<bool> isTester() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      return userModel?.hasRole('tester') ?? false;
    } catch (e) {
      Logger.error('Error checking tester status', error: e, tag: 'UATService');
      return false;
    }
  }

  /// Check if current user can manage test cases (tester or admin)
  Future<bool> canManageTestCases() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null) return false;
      return userModel.hasRole('tester') || userModel.hasRole('admin');
    } catch (e) {
      Logger.error('Error checking test case management permission', error: e, tag: 'UATService');
      return false;
    }
  }
}

/// Model for UAT Test Round
class UATTestRound {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final String createdBy;

  UATTestRound({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.createdBy,
  });

  factory UATTestRound.fromJson(Map<String, dynamic> json, String id) {
    // Parse createdAt - handle both Timestamp and ISO8601 string formats
    DateTime? parseCreatedAt(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }
    
    return UATTestRound(
      id: id,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      createdAt: parseCreatedAt(json['createdAt']) ?? DateTime.now(),
      createdBy: (json['createdBy'] as String?) ?? '',
    );
  }
}

/// Model for UAT Test Case
class UATTestCase {
  final String id;
  final int number;
  final String title;
  final String description;
  final String? feature;
  final String? test;
  final String status; // 'pending', 'passed', 'failed'
  final String? testedBy;
  final String? testedById;
  final DateTime? testedAt;

  UATTestCase({
    required this.id,
    required this.number,
    required this.title,
    required this.description,
    this.feature,
    this.test,
    this.status = 'pending',
    this.testedBy,
    this.testedById,
    this.testedAt,
  });

  factory UATTestCase.fromJson(Map<String, dynamic> json, String id) {
    // Parse testedAt - handle both Timestamp and ISO8601 string formats
    DateTime? parseTestedAt(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }
    
    return UATTestCase(
      id: id,
      number: (json['number'] as int?) ?? 0,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      feature: json['feature'] as String?,
      test: json['test'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      testedBy: json['testedBy'] as String?,
      testedById: json['testedById'] as String?,
      testedAt: parseTestedAt(json['testedAt']),
    );
  }

  bool get isLocked => status == 'passed' || status == 'failed';
}

/// Model for UAT Sub Test Case
class UATSubTestCase {
  final String id;
  final int number;
  final String title;
  final String description;
  final String? feature;
  final String? test;
  final String status; // 'pending', 'passed', 'failed'
  final String? testedBy;
  final String? testedById;
  final DateTime? testedAt;

  UATSubTestCase({
    required this.id,
    required this.number,
    required this.title,
    required this.description,
    this.feature,
    this.test,
    this.status = 'pending',
    this.testedBy,
    this.testedById,
    this.testedAt,
  });

  factory UATSubTestCase.fromJson(Map<String, dynamic> json, String id) {
    // Parse testedAt - handle both Timestamp and ISO8601 string formats
    DateTime? parseTestedAt(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }
    
    return UATSubTestCase(
      id: id,
      number: (json['number'] as int?) ?? 0,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      feature: json['feature'] as String?,
      test: json['test'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      testedBy: json['testedBy'] as String?,
      testedById: json['testedById'] as String?,
      testedAt: parseTestedAt(json['testedAt']),
    );
  }

  bool get isLocked => status == 'passed' || status == 'failed';
}
