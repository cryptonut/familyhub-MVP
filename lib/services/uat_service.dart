import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Service for managing User Acceptance Testing (UAT) test cases
class UATService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  /// Get all test rounds
  Future<List<UATTestRound>> getTestRounds() async {
    try {
      final snapshot = await _firestore
          .collection('uat_test_rounds')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => UATTestRound.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      Logger.error('Error fetching test rounds', error: e, tag: 'UATService');
      return [];
    }
  }

  /// Get test cases for a specific round
  Future<List<UATTestCase>> getTestCases(String roundId) async {
    try {
      final snapshot = await _firestore
          .collection('uat_test_rounds')
          .doc(roundId)
          .collection('test_cases')
          .orderBy('number')
          .get();

      return snapshot.docs
          .map((doc) => UATTestCase.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      Logger.error('Error fetching test cases', error: e, tag: 'UATService');
      return [];
    }
  }

  /// Get sub-test cases for a test case
  Future<List<UATSubTestCase>> getSubTestCases(String roundId, String testCaseId) async {
    try {
      final snapshot = await _firestore
          .collection('uat_test_rounds')
          .doc(roundId)
          .collection('test_cases')
          .doc(testCaseId)
          .collection('sub_test_cases')
          .orderBy('number')
          .get();

      return snapshot.docs
          .map((doc) => UATSubTestCase.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      Logger.error('Error fetching sub test cases', error: e, tag: 'UATService');
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
            .collection('uat_test_rounds')
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
            .collection('uat_test_rounds')
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
            .collection('uat_test_rounds')
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
            .collection('uat_test_rounds')
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
    return UATTestRound(
      id: id,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: json['createdBy'] ?? '',
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
    return UATTestCase(
      id: id,
      number: json['number'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      feature: json['feature'],
      test: json['test'],
      status: json['status'] ?? 'pending',
      testedBy: json['testedBy'],
      testedById: json['testedById'],
      testedAt: (json['testedAt'] as Timestamp?)?.toDate(),
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
    return UATSubTestCase(
      id: id,
      number: json['number'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      feature: json['feature'],
      test: json['test'],
      status: json['status'] ?? 'pending',
      testedBy: json['testedBy'],
      testedById: json['testedById'],
      testedAt: (json['testedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isLocked => status == 'passed' || status == 'failed';
}

