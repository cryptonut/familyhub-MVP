import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

/// Script to check how many UAT test artifacts exist in Firestore
/// 
/// Usage: dart scripts/check_uat_test_artifacts.dart
/// 
/// This script queries all UAT collections and counts:
/// - Test rounds
/// - Test cases
/// - Sub-test cases
void main() async {
  print('=' * 60);
  print('UAT Test Artifacts Count Check');
  print('=' * 60);
  print('');
  
  print('Initializing Firebase...');
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✓ Firebase initialized');
  } catch (e) {
    print('✗ Error initializing Firebase: $e');
    exit(1);
  }
  
  final firestore = FirebaseFirestore.instance;
  
  // Collections to check
  final collections = [
    'uat_test_rounds',        // Unprefixed (shared/prod)
    'dev_uat_test_rounds',     // Dev environment
    'test_uat_test_rounds',    // QA/test environment
  ];
  
  int totalRounds = 0;
  int totalTestCases = 0;
  int totalSubTestCases = 0;
  
  for (var collectionPath in collections) {
    print('\n📁 Checking collection: $collectionPath');
    print('-' * 60);
    
    try {
      // Get all test rounds
      final roundsSnapshot = await firestore
          .collection(collectionPath)
          .get();
      
      final roundsCount = roundsSnapshot.docs.length;
      totalRounds += roundsCount;
      
      print('  Test Rounds: $roundsCount');
      
      if (roundsCount == 0) {
        print('  (No test rounds found)');
        continue;
      }
      
      // For each round, count test cases and sub-test cases
      for (var roundDoc in roundsSnapshot.docs) {
        final roundData = roundDoc.data();
        final roundName = roundData['name'] ?? 'Unnamed Round';
        print('  \n  Round: $roundName (ID: ${roundDoc.id})');
        
        // Count test cases
        final testCasesSnapshot = await roundDoc.reference
            .collection('test_cases')
            .get();
        
        final testCasesCount = testCasesSnapshot.docs.length;
        totalTestCases += testCasesCount;
        print('    Test Cases: $testCasesCount');
        
        // Count sub-test cases for each test case
        int subTestCasesInRound = 0;
        for (var testCaseDoc in testCasesSnapshot.docs) {
          final subTestCasesSnapshot = await testCaseDoc.reference
              .collection('sub_test_cases')
              .get();
          
          subTestCasesInRound += subTestCasesSnapshot.docs.length;
        }
        
        totalSubTestCases += subTestCasesInRound;
        print('    Sub-Test Cases: $subTestCasesInRound');
      }
      
    } catch (e) {
      print('  ✗ Error querying $collectionPath: $e');
      // Continue checking other collections
    }
  }
  
  print('\n' + '=' * 60);
  print('SUMMARY');
  print('=' * 60);
  print('Total Test Rounds: $totalRounds');
  print('Total Test Cases: $totalTestCases');
  print('Total Sub-Test Cases: $totalSubTestCases');
  print('');
  
  if (totalRounds == 0) {
    print('⚠️  WARNING: No test rounds found in any collection!');
    print('');
    print('To add test artifacts, run:');
    print('  dart scripts/add_uat_test_cases.dart dev');
    print('  dart scripts/add_uat_test_cases.dart qa');
    print('  dart scripts/add_uat_test_cases.dart prod');
  } else {
    print('✅ Test artifacts found!');
  }
  
  exit(0);
}

