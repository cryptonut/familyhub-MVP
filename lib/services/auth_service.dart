import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../utils/relationship_utils.dart';
import 'package:uuid/uuid.dart';
import '../core/services/logger_service.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exceptions.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Track if we're currently in the registration process to prevent auto-creation conflicts
  static final Set<String> _registeringUserIds = <String>{};

  // Get current user model
  // Returns null if user doesn't exist or document is missing
  // Does NOT auto-create documents - that should be handled during registration
  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) {
      Logger.debug('No Firebase Auth user - returning null', tag: 'AuthService');
      return null;
    }
    
    Logger.debug('Firebase Auth user exists: ${user.uid} (${user.email})', tag: 'AuthService');
    Logger.debug('Attempting to load user document from Firestore...', tag: 'AuthService');

    // If user is currently registering, wait briefly then try again
    if (_registeringUserIds.contains(user.uid)) {
      Logger.debug('User ${user.uid} is currently registering, waiting...', tag: 'AuthService');
      await Future.delayed(const Duration(milliseconds: 500));
      if (_registeringUserIds.contains(user.uid)) {
        Logger.debug('Still registering, returning null', tag: 'AuthService');
        return null;
      }
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    
    // CRITICAL FIX from code review: Ensure user doc exists before queries
    // This prevents Firestore rules circular dependency issues on Android cold-start
    // Use cacheAndServer (cache first, then server) to allow gRPC channel to establish naturally
    
    int maxRetries = AppConstants.maxRetries;
    DateTime? startTime;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          Logger.debug('Retry attempt $attempt/$maxRetries after ${attempt}s delay...', tag: 'AuthService');
          await Future.delayed(Duration(seconds: attempt));
        }
        
        Logger.debug('Attempting Firestore query (attempt ${attempt + 1})...', tag: 'AuthService');
        startTime = DateTime.now();
        
        // CRITICAL FIX: Wait for gRPC channel to initialize before querying
        // The channel reset loop (initChannel -> shutdownNow) happens when queries
        // are made before the gRPC channel is ready. Wait on first attempt.
        DocumentSnapshot userDoc;
        
        // Wait for gRPC channel to initialize on first attempt (Android only)
        if (attempt == 0 && !kIsWeb) {
          Logger.debug('Waiting for gRPC channel to initialize...', tag: 'AuthService');
          await Future.delayed(AppConstants.gRPCChannelInitDelay);
        }
        
        // Use server source to ensure fresh data and prevent cache-related channel issues
        // Increased timeout to allow for initial gRPC channel establishment
        userDoc = await userRef
            .get(GetOptions(source: Source.server))
            .timeout(AppConstants.firestoreQueryTimeout);
        
        final elapsed = DateTime.now().difference(startTime);
        
        // If doc doesn't exist, create minimal user doc to satisfy Firestore rules
        if (!userDoc.exists) {
          Logger.debug('User document does not exist for ${user.uid} - creating...', tag: 'AuthService');
          try {
            // Use ISO8601 string for createdAt to match UserModel.fromJson expectations
            // This prevents "type 'Timestamp' is not a subtype of type 'String'" errors on Android
            final now = DateTime.now().toIso8601String();
            await userRef.set({
              'uid': user.uid,
              'email': user.email ?? '',
              'familyId': null,
              'roles': <String>[],
              'createdAt': now,
            }, SetOptions(merge: true));
            Logger.debug('Created user document', tag: 'AuthService');
            // Re-fetch the newly created doc from server to ensure we have the latest
            userDoc = await userRef
                .get(GetOptions(source: Source.server))
                .timeout(AppConstants.firestoreQueryTimeout);
          } catch (e, st) {
            Logger.error('Failed to create user doc', error: e, stackTrace: st, tag: 'AuthService');
            return null;
          }
        }

        final data = userDoc.data();
        if (data == null) {
          Logger.warning('User document has no data', tag: 'AuthService');
          return null;
        }
        
        Logger.debug('Successfully loaded user data in ${elapsed.inMilliseconds}ms', tag: 'AuthService');
        return UserModel.fromJson(data as Map<String, dynamic>);
      } on TimeoutException {
        final elapsed = startTime != null ? DateTime.now().difference(startTime!) : const Duration(seconds: 0);
        Logger.warning('Firestore query timeout after ${elapsed.inMilliseconds}ms (attempt ${attempt + 1})', tag: 'AuthService');
        if (attempt == maxRetries - 1) {
          Logger.error('ALL RETRY ATTEMPTS FAILED - TIMEOUT', tag: 'AuthService');
          return null;
        }
      } catch (e, stackTrace) {
        final errorStr = e.toString().toLowerCase();
        final errorCode = e is FirebaseException ? e.code : 'unknown';
        Logger.warning('Firestore error (attempt ${attempt + 1}/$maxRetries)', tag: 'AuthService');
        Logger.debug('  Error: $e', tag: 'AuthService');
        Logger.debug('  Error code: $errorCode', tag: 'AuthService');
        Logger.debug('  Error type: ${e.runtimeType}', tag: 'AuthService');
        
        if (errorStr.contains('unavailable') || errorCode == 'unavailable') {
          Logger.warning('Firestore unavailable error detected', tag: 'AuthService');
          Logger.debug('  Possible causes:', tag: 'AuthService');
          Logger.debug('    - API key restrictions blocking Firestore API', tag: 'AuthService');
          Logger.debug('    - Firestore API not enabled in Google Cloud Console', tag: 'AuthService');
          Logger.debug('    - Network connectivity issues', tag: 'AuthService');
          Logger.debug('    - App Check enforcement blocking requests', tag: 'AuthService');
          Logger.debug('    - Firestore service temporarily down', tag: 'AuthService');
          
          if (attempt < maxRetries - 1) {
            Logger.debug('Will retry (attempt ${attempt + 1}/$maxRetries) after ${attempt + 1}s delay...', tag: 'AuthService');
            // On last retry before giving up, try forcing server source to bypass cache
            // This applies to Android/iOS where cache can cause issues, not a Chrome workaround
            if (attempt == maxRetries - 2 && !kIsWeb) {
              Logger.debug('Last retry - will try forcing server source to bypass cache issues (Android/iOS)', tag: 'AuthService');
            }
          } else {
            Logger.error('All retries exhausted - Firestore unavailable', error: e, stackTrace: stackTrace, tag: 'AuthService');
            return null;
          }
        } else {
          Logger.warning('Non-unavailable error: $e', tag: 'AuthService');
          Logger.debug('  Error code: $errorCode', tag: 'AuthService');
          // Don't retry on non-unavailable errors (permission, not-found, etc.)
          return null;
        }
      }
    }
    
    return null;
  }

  // Sign in with email and password
  // Rebuild: Clean, simple sign-in with timeout protection
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      Logger.info('=== SIGN IN START ===', tag: 'AuthService');
      Logger.debug('Email: $email', tag: 'AuthService');
      Logger.debug('Current user before sign in: ${_auth.currentUser?.uid ?? "null"}', tag: 'AuthService');
      Logger.debug('Firebase Auth instance: ${_auth.app.name}', tag: 'AuthService');
      Logger.debug('Firebase project ID: ${_auth.app.options.projectId}', tag: 'AuthService');
      
      // IMPORTANT: Do NOT call signOut() before signIn() - this can cause race conditions
      // Firebase Auth handles existing sessions automatically
      // Do NOT add network connectivity tests - Firebase SDK handles this internally
      // Platform-specific workarounds are NOT needed - Firebase Auth works consistently across platforms
      
      Logger.debug('Calling Firebase signInWithEmailAndPassword...', tag: 'AuthService');
      Logger.debug('Email (trimmed): "${email.trim()}"', tag: 'AuthService');
      Logger.debug('Password length: ${password.length}', tag: 'AuthService');
      
      // Check Firebase Auth settings
      Logger.debug('Firebase Auth settings:', tag: 'AuthService');
      Logger.debug('  - App name: ${_auth.app.name}', tag: 'AuthService');
      Logger.debug('  - Project ID: ${_auth.app.options.projectId}', tag: 'AuthService');
      final apiKey = _auth.app.options.apiKey ?? '';
      if (apiKey.isNotEmpty) {
        Logger.logApiKey(apiKey, tag: 'AuthService');
        Logger.debug('  - NOTE: This is the ANDROID API key (different from web key)', tag: 'AuthService');
        Logger.debug('  - If this times out, check restrictions for THIS key in Google Cloud Console', tag: 'AuthService');
      } else {
        Logger.warning('API Key: NULL (this is a problem!)', tag: 'AuthService');
      }
      
      // Direct call to Firebase Auth - let it throw actual errors
      Logger.debug('Calling Firebase signInWithEmailAndPassword...', tag: 'AuthService');
      final startTime = DateTime.now();
      
      try {
        // Call Firebase Auth directly with a reasonable timeout
        // CRITICAL: The "empty reCAPTCHA token" error indicates Firebase Auth is trying to use reCAPTCHA
        // but can't get a token. This is typically caused by:
        // 1. reCAPTCHA enabled in Firebase Console but not properly configured
        // 2. Network issues preventing reCAPTCHA from loading
        // 3. API key restrictions blocking reCAPTCHA endpoints
        // 4. OAuth client/SHA-1 fingerprint mismatch
        Logger.debug('About to call signInWithEmailAndPassword - this may trigger reCAPTCHA on Android', tag: 'AuthService');
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ).timeout(
          AppConstants.authOperationTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Firebase Auth sign-in timed out after ${AppConstants.authOperationTimeout.inSeconds} seconds.\n\n'
              'CRITICAL: Logcat shows "empty reCAPTCHA token" - this indicates:\n'
              '1. reCAPTCHA is enabled in Firebase Console but token generation is failing\n'
              '2. Go to Firebase Console > Authentication > Settings > reCAPTCHA provider\n'
              '3. DISABLE reCAPTCHA for email/password authentication\n'
              '4. Verify API key restrictions include "Identity Toolkit API"\n'
              '5. Verify OAuth client and SHA-1 fingerprint are correct\n'
              '6. Check network connectivity to reCAPTCHA endpoints',
              AppConstants.authOperationTimeout,
            );
          },
        );
        
        final elapsed = DateTime.now().difference(startTime);
        Logger.info('✓ Firebase Auth succeeded in ${elapsed.inMilliseconds}ms', tag: 'AuthService');
        return _handleSignInSuccess(userCredential);
      } on TimeoutException catch (e) {
        Logger.error('=== TIMEOUT: Firebase Auth hung ===', error: e, tag: 'AuthService');
        Logger.warning('⚠️ CRITICAL: If logcat shows "empty reCAPTCHA token", this is the root cause!', tag: 'AuthService');
        Logger.debug('   The authentication is hanging because Firebase Auth cannot get a reCAPTCHA token.', tag: 'AuthService');
        Logger.debug('   IMMEDIATE FIX REQUIRED:', tag: 'AuthService');
        Logger.debug('   1. Go to Firebase Console > Authentication > Settings (gear icon)', tag: 'AuthService');
        Logger.debug('   2. Scroll to "reCAPTCHA provider" section', tag: 'AuthService');
        Logger.debug('   3. DISABLE reCAPTCHA for email/password authentication', tag: 'AuthService');
        Logger.debug('   4. Save and wait 1-2 minutes for changes to propagate', tag: 'AuthService');
        Logger.debug('   5. Rebuild app: flutter clean && flutter run', tag: 'AuthService');
        
        // Check if Firebase is actually initialized
        try {
          final app = _auth.app;
          Logger.debug('Firebase app name: ${app.name}', tag: 'AuthService');
          Logger.debug('Firebase project ID: ${app.options.projectId}', tag: 'AuthService');
          final apiKey = app.options.apiKey;
          if (apiKey != null && apiKey.isNotEmpty) {
            Logger.logApiKey(apiKey, tag: 'AuthService');
            Logger.debug('⚠️ Also verify this API key in Google Cloud Console:', tag: 'AuthService');
            Logger.debug('  1. Verify API restrictions include "Identity Toolkit API"', tag: 'AuthService');
            Logger.debug('  2. Verify application restrictions allow Android app', tag: 'AuthService');
            Logger.debug('  3. Verify OAuth client is configured in google-services.json', tag: 'AuthService');
            Logger.debug('  4. Ensure reCAPTCHA API is not blocked by restrictions', tag: 'AuthService');
          } else {
            Logger.error('Firebase API key: NULL (this is a critical problem!)', tag: 'AuthService');
          }
        } catch (err, st) {
          Logger.error('Cannot access Firebase app', error: err, stackTrace: st, tag: 'AuthService');
        }
        rethrow;
      } on FirebaseAuthException catch (e) {
        Logger.error('Firebase Auth error', error: e, tag: 'AuthService');
        Logger.debug('Code: ${e.code}', tag: 'AuthService');
        Logger.debug('Message: ${e.message}', tag: 'AuthService');
        rethrow;
      } on PlatformException catch (e) {
        Logger.error('Platform Exception (Native Android)', error: e, tag: 'AuthService');
        Logger.debug('Code: ${e.code}', tag: 'AuthService');
        Logger.debug('Message: ${e.message}', tag: 'AuthService');
        Logger.debug('Details: ${e.details}', tag: 'AuthService');
        
        // Handle specific Android platform exceptions
        if (e.code == 'DEVELOPER_ERROR' || e.message?.contains('DEVELOPER_ERROR') == true) {
          Logger.warning('⚠️ DEVELOPER_ERROR detected - this usually means:', tag: 'AuthService');
          Logger.debug('  1. OAuth client not configured in google-services.json', tag: 'AuthService');
          Logger.debug('  2. SHA-1 fingerprint mismatch', tag: 'AuthService');
          Logger.debug('  3. Package name mismatch', tag: 'AuthService');
          Logger.debug('  4. Need to wait 2-3 minutes after adding SHA-1 to Firebase Console', tag: 'AuthService');
          throw AuthException(
            'Firebase configuration error. Please verify OAuth client and SHA-1 fingerprint in Firebase Console.',
            code: 'DEVELOPER_ERROR',
          );
        }
        
        rethrow;
      } catch (e, stackTrace) {
        Logger.error('Unexpected error', error: e, stackTrace: stackTrace, tag: 'AuthService');
        Logger.debug('Type: ${e.runtimeType}', tag: 'AuthService');
        
        // Check for common Android-specific issues
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('network') || errorStr.contains('socket') || errorStr.contains('connection')) {
          Logger.warning('⚠️ Network-related error detected on Android', tag: 'AuthService');
          Logger.debug('  This may indicate network connectivity issues or firewall blocking', tag: 'AuthService');
        }
        
        rethrow;
      }
    } on TimeoutException {
      Logger.warning('TimeoutException caught', tag: 'AuthService');
      rethrow;
    } catch (e, stackTrace) {
      Logger.error('SIGN IN ERROR', error: e, stackTrace: stackTrace, tag: 'AuthService');
      Logger.debug('Error type: ${e.runtimeType}', tag: 'AuthService');
      throw _handleAuthError(e);
    }
  }

  // Helper method to handle successful sign-in
  UserModel? _handleSignInSuccess(UserCredential userCredential) {
    if (userCredential.user == null) {
      Logger.error('Sign in succeeded but no user returned', tag: 'AuthService');
      throw AuthException('Sign in succeeded but no user returned', code: 'no-user');
    }
    
    Logger.info('SIGN IN SUCCESS', tag: 'AuthService');
    Logger.debug('User ID: ${userCredential.user!.uid}', tag: 'AuthService');
    Logger.debug('Email: ${userCredential.user!.email}', tag: 'AuthService');
    
    // Return null - app screens will load user model as needed
    return null;
  }

  // Register with email and password
  // Optional familyId parameter - if provided, user joins that family instead of creating a new one
  Future<UserModel?> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName, {
    String? familyId,
    String? creatorRelationship,
  }) async {
    String? userId;
    try {
      Logger.info('=== REGISTRATION START ===', tag: 'AuthService');
      Logger.debug('Email: $email', tag: 'AuthService');
      Logger.debug('Display Name: $displayName', tag: 'AuthService');
      Logger.debug('Invitation Code provided: ${familyId != null && familyId!.isNotEmpty}', tag: 'AuthService');
      if (familyId != null && familyId.isNotEmpty) {
        Logger.debug('Invitation Code: "$familyId"', tag: 'AuthService');
      }
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        userId = userCredential.user!.uid;
        // CRITICAL: Mark this user as currently registering IMMEDIATELY after Auth account creation
        // This prevents getCurrentUserModel() from auto-creating a document with wrong familyId
        _registeringUserIds.add(userId);
        Logger.debug('🔒 IMMEDIATELY marked user $userId as registering - preventing auto-creation', tag: 'AuthService');
        Logger.debug('  Registration flag set BEFORE any document operations', tag: 'AuthService');
        // CRITICAL: Do NOT call getCurrentUserModel() here as it will auto-create
        // a user document with a new familyId before we process the invitation code!
        // We'll create the user document ourselves after verifying the family exists.
        
        // If familyId is provided, verify it exists BEFORE creating any user document
        String? finalFamilyId;
        bool isJoiningExistingFamily = false;
        
        Logger.info('=== REGISTRATION START ===', tag: 'AuthService');
        Logger.debug('Email: $email', tag: 'AuthService');
        Logger.debug('Display Name: $displayName', tag: 'AuthService');
        Logger.debug('Invitation Code provided: ${familyId != null && familyId!.isNotEmpty}', tag: 'AuthService');
        if (familyId != null && familyId.isNotEmpty) {
          Logger.debug('Invitation Code: "$familyId"', tag: 'AuthService');
        }
        
        if (familyId != null && familyId.isNotEmpty) {
          // Clean the familyId (remove whitespace, but keep case as UUIDs are case-sensitive)
          final cleanFamilyId = familyId.trim();
          
          Logger.debug('=== REGISTRATION WITH FAMILY ID ===', tag: 'AuthService');
          Logger.debug('Provided familyId: "$familyId"', tag: 'AuthService');
          Logger.debug('Cleaned familyId: "$cleanFamilyId"', tag: 'AuthService');
          Logger.debug('Length: ${cleanFamilyId.length}', tag: 'AuthService');
          Logger.debug('Character codes: ${cleanFamilyId.codeUnits}', tag: 'AuthService');
          
          // Try multiple methods to verify the family exists
          bool familyExists = false;
          DocumentSnapshot? foundUserDoc;
          
          // Method 1: Query by familyId (preferred method)
          try {
            Logger.debug('Method 1: Querying users collection by familyId...', tag: 'AuthService');
            final familyCheck = await _firestore
                .collection('users')
                .where('familyId', isEqualTo: cleanFamilyId)
                .limit(1)
                .get(GetOptions(source: Source.server));
            
            Logger.debug('Query result: ${familyCheck.docs.length} documents found', tag: 'AuthService');
            
            if (familyCheck.docs.isNotEmpty) {
              foundUserDoc = familyCheck.docs.first;
              familyExists = true;
              Logger.debug('✓ Family found via query method', tag: 'AuthService');
            } else {
              Logger.debug('✗ Query returned no results', tag: 'AuthService');
            }
          } catch (e, st) {
            Logger.warning('✗ Query method failed', error: e, stackTrace: st, tag: 'AuthService');
            Logger.debug('This might indicate a missing Firestore index', tag: 'AuthService');
          }
          
          // Method 2: If query failed, try reading all users and checking manually
          if (!familyExists) {
            try {
              Logger.debug('Method 2: Reading all users and checking manually...', tag: 'AuthService');
              final allUsers = await _firestore
                  .collection('users')
                  .limit(AppConstants.usersQueryLimit)
                  .get(GetOptions(source: Source.server));
              
              Logger.debug('Total users in database: ${allUsers.docs.length}', tag: 'AuthService');
              
              for (var doc in allUsers.docs) {
                final data = doc.data();
                final existingFamilyId = data['familyId'] as String?;
                
                Logger.debug('  Checking user ${doc.id}:', tag: 'AuthService');
                Logger.debug('    Email: ${data['email']}', tag: 'AuthService');
                Logger.debug('    familyId in DB: "$existingFamilyId"', tag: 'AuthService');
                Logger.debug('    familyId length: ${existingFamilyId?.length ?? 0}', tag: 'AuthService');
                Logger.debug('    Looking for: "$cleanFamilyId"', tag: 'AuthService');
                Logger.debug('    Looking for length: ${cleanFamilyId.length}', tag: 'AuthService');
                Logger.debug('    Codes match (==): ${existingFamilyId == cleanFamilyId}', tag: 'AuthService');
                Logger.debug('    Codes match (compareTo): ${existingFamilyId?.compareTo(cleanFamilyId) ?? -999}', tag: 'AuthService');
                
                // Also check character by character
                if (existingFamilyId != null && existingFamilyId.length == cleanFamilyId.length) {
                  bool allMatch = true;
                  for (int i = 0; i < existingFamilyId.length; i++) {
                    if (existingFamilyId[i] != cleanFamilyId[i]) {
                      Logger.debug('    Character mismatch at position $i: "${existingFamilyId[i]}" (${existingFamilyId.codeUnitAt(i)}) vs "${cleanFamilyId[i]}" (${cleanFamilyId.codeUnitAt(i)})', tag: 'AuthService');
                      allMatch = false;
                      break;
                    }
                  }
                  Logger.debug('    Character-by-character match: $allMatch', tag: 'AuthService');
                }
                
                if (existingFamilyId != null && existingFamilyId == cleanFamilyId) {
                  foundUserDoc = doc;
                  familyExists = true;
                  Logger.debug('✓ Family found via manual check!', tag: 'AuthService');
                  break;
                }
              }
              
              if (!familyExists) {
                Logger.warning('✗ Manual check found no matching familyId', tag: 'AuthService');
                Logger.debug('Summary: Searched ${allUsers.docs.length} users, none had familyId matching "$cleanFamilyId"', tag: 'AuthService');
              }
            } catch (e, st) {
              Logger.warning('✗ Manual check method failed', error: e, stackTrace: st, tag: 'AuthService');
            }
          }
          
          // Method 3: If still not found, wait a moment and retry (in case of timing issue)
          if (!familyExists) {
            Logger.debug('Method 3: Waiting 2 seconds and retrying query (timing issue check)...', tag: 'AuthService');
            await Future.delayed(const Duration(seconds: 2));
            
            try {
              final retryCheck = await _firestore
                  .collection('users')
                  .where('familyId', isEqualTo: cleanFamilyId)
                  .limit(1)
                  .get(GetOptions(source: Source.server));
              
              Logger.debug('Retry query result: ${retryCheck.docs.length} documents found', tag: 'AuthService');
              
              if (retryCheck.docs.isNotEmpty) {
                foundUserDoc = retryCheck.docs.first;
                familyExists = true;
                Logger.debug('✓ Family found on retry!', tag: 'AuthService');
              }
            } catch (e, st) {
              Logger.warning('✗ Retry query failed', error: e, stackTrace: st, tag: 'AuthService');
            }
          }
          
          if (familyExists && foundUserDoc != null) {
            // Valid familyId - user is joining an existing family
            final foundData = foundUserDoc.data() as Map<String, dynamic>;
            Logger.info('=== FAMILY VERIFIED ===', tag: 'AuthService');
            Logger.debug('Found user ID: ${foundUserDoc.id}', tag: 'AuthService');
            Logger.debug('Found user email: ${foundData['email']}', tag: 'AuthService');
            Logger.debug('Found user familyId: "${foundData['familyId']}"', tag: 'AuthService');
            Logger.debug('FamilyId matches: ${foundData['familyId'] == cleanFamilyId}', tag: 'AuthService');
            
            finalFamilyId = cleanFamilyId;
            isJoiningExistingFamily = true;
            Logger.info('✓ User will join existing family: $finalFamilyId', tag: 'AuthService');
            Logger.debug('  Continuing to create user document with this familyId...', tag: 'AuthService');
          } else {
            // Invalid familyId - throw error instead of creating new family
            Logger.error('=== ERROR: FAMILY NOT FOUND ===', tag: 'AuthService');
            Logger.warning('Invalid family invitation code: "$cleanFamilyId"', tag: 'AuthService');
            Logger.warning('No users found with this familyId using any method', tag: 'AuthService');
            
            // Delete the user account that was just created
            try {
              await userCredential.user!.delete();
              Logger.info('Deleted user account after invalid familyId', tag: 'AuthService');
            } catch (e, st) {
              Logger.error('Error deleting user account after invalid familyId', error: e, stackTrace: st, tag: 'AuthService');
            }
            throw ValidationException(
              'Invalid family invitation code. Please check the code and try again.\n\nCode provided: "$cleanFamilyId"\n\nIf you copied the code correctly, this might indicate the family no longer exists or there was an error.',
            );
          }
        } else {
          // No familyId provided, create new one (user is creating a new family)
          finalFamilyId = const Uuid().v4();
          isJoiningExistingFamily = false;
          Logger.info('User is creating new family: $finalFamilyId', tag: 'AuthService');
        }
        
        // Check if this is the first user in the family (family creator gets Admin role)
        // Only check this if NOT joining an existing family
        Logger.debug('=== DETERMINING ROLES ===', tag: 'AuthService');
        Logger.debug('isJoiningExistingFamily: $isJoiningExistingFamily', tag: 'AuthService');
        Logger.debug('finalFamilyId: $finalFamilyId', tag: 'AuthService');
        
        final List<String> roles;
        if (isJoiningExistingFamily) {
          // Joining existing family - no roles (not Admin)
          roles = [];
          Logger.debug('✓ User joining existing family - no roles assigned', tag: 'AuthService');
        } else {
          // Creating new family - user is always the creator (gets Admin role)
          // Since we just generated a new UUID, there can't be any existing members
          // But we check anyway to be safe
          bool isFamilyCreator = true;
          try {
            final existingFamilyMembers = await _firestore
                .collection('users')
                .where('familyId', isEqualTo: finalFamilyId)
                .limit(1)
                .get(GetOptions(source: Source.server));
            
            isFamilyCreator = existingFamilyMembers.docs.isEmpty;
            Logger.debug('Checked for existing family members: found ${existingFamilyMembers.docs.length}', tag: 'AuthService');
          } catch (e, st) {
            Logger.warning('Error checking for existing family members (assuming creator)', error: e, stackTrace: st, tag: 'AuthService');
            // If query fails, assume user is creator (safe default for new family)
            isFamilyCreator = true;
          }
          
          roles = isFamilyCreator ? [AppConstants.roleAdmin] : [];
          Logger.debug('User creating new family - isFamilyCreator: $isFamilyCreator, roles: $roles', tag: 'AuthService');
        }
        
        // CRITICAL: Check if user document was auto-created by getCurrentUserModel()
        // This can happen if auth state changes trigger getCurrentUserModel() before
        // we finish processing the invitation code
        Logger.debug('=== CHECKING FOR EXISTING DOCUMENT ===', tag: 'AuthService');
        Logger.debug('User ID: ${userCredential.user!.uid}', tag: 'AuthService');
        final existingDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get(GetOptions(source: Source.server));
        Logger.debug('Document exists: ${existingDoc.exists}', tag: 'AuthService');
        
        if (existingDoc.exists) {
          final existingData = existingDoc.data();
          final existingFamilyId = existingData?['familyId'] as String?;
          Logger.warning('⚠️ WARNING: User document already exists!', tag: 'AuthService');
          Logger.debug('  This suggests getCurrentUserModel() was called before registration completed.', tag: 'AuthService');
          Logger.debug('  Existing familyId: "$existingFamilyId"', tag: 'AuthService');
          Logger.debug('  Intended familyId: "$finalFamilyId"', tag: 'AuthService');
          
          if (existingFamilyId != null && existingFamilyId != finalFamilyId) {
            Logger.warning('  ⚠️ CONFLICT DETECTED: User document has wrong familyId!', tag: 'AuthService');
            Logger.debug('  This is the root cause - auto-created document overwrote invitation code.', tag: 'AuthService');
            Logger.debug('  Fixing by updating to correct familyId...', tag: 'AuthService');
          }
        } else {
          Logger.debug('✓ User document does not exist yet (good - no auto-creation happened)', tag: 'AuthService');
        }
        
        // Create or update user document in Firestore with CORRECT familyId
        // This will overwrite any auto-created document
        // Handle createdAt - can be Timestamp, String, or DateTime (from existing doc or new)
        DateTime parseCreatedAt(dynamic value) {
          if (value == null) return DateTime.now();
          if (value is Timestamp) return value.toDate();
          if (value is DateTime) return value;
          if (value is String) {
            try {
              return DateTime.parse(value);
            } catch (e) {
              Logger.warning('Error parsing createdAt string', error: e, tag: 'AuthService');
              return DateTime.now();
            }
          }
          return DateTime.now();
        }
        
        final existingCreatedAt = existingDoc.exists && existingDoc.data()?['createdAt'] != null
            ? existingDoc.data()!['createdAt']
            : null;
        
        final userModel = UserModel(
          uid: userCredential.user!.uid,
          email: email,
          displayName: displayName,
          createdAt: parseCreatedAt(existingCreatedAt),
          familyId: finalFamilyId, // This is the CORRECT familyId (either from invitation or new)
          roles: roles,
          relationship: creatorRelationship, // Store creator's relationship if provided
        );

        // Use set() to overwrite any auto-created document with wrong familyId
        // Use merge: false to ensure we completely overwrite any existing document
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userModel.toJson(), SetOptions(merge: false));

        Logger.info('=== USER DOCUMENT CREATED/UPDATED ===', tag: 'AuthService');
        Logger.debug('User ID: ${userCredential.user!.uid}', tag: 'AuthService');
        Logger.debug('Family ID: $finalFamilyId (${isJoiningExistingFamily ? "JOINING EXISTING" : "NEW FAMILY"})', tag: 'AuthService');
        Logger.debug('Roles: $roles', tag: 'AuthService');
        Logger.debug('Email: $email', tag: 'AuthService');
        
        // AGGRESSIVE: Verify and fix multiple times to catch any race conditions
        // Something is overwriting the document immediately after creation
        // We need to keep fixing it until it sticks
        int maxAttempts = 5;
        bool verified = false;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
          await Future.delayed(Duration(milliseconds: 150 * attempt));
          final verifyDoc = await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .get(GetOptions(source: Source.server));
          if (verifyDoc.exists) {
            final verifyData = verifyDoc.data();
            final verifyFamilyId = verifyData?['familyId'] as String?;
            Logger.debug('✓ Verification attempt $attempt: Document familyId = "$verifyFamilyId"', tag: 'AuthService');
            if (verifyFamilyId != finalFamilyId) {
              Logger.warning('⚠️ VERIFICATION FAILED on attempt $attempt: Document was overwritten!', tag: 'AuthService');
              Logger.debug('  Expected: "$finalFamilyId"', tag: 'AuthService');
              Logger.debug('  Found: "$verifyFamilyId"', tag: 'AuthService');
              Logger.debug('  Something is overwriting the document - fixing again...', tag: 'AuthService');
              
              // Use set() with merge: false to completely overwrite
              await _firestore.collection('users').doc(userCredential.user!.uid).set({
                'uid': userCredential.user!.uid,
                'email': email,
                'displayName': displayName,
                'createdAt': userModel.createdAt.toIso8601String(),
                'familyId': finalFamilyId, // CORRECT familyId
                'roles': roles,
              }, SetOptions(merge: false));
              
              Logger.debug('  ✓ Fixed on attempt $attempt (using set with merge: false)', tag: 'AuthService');
              
              // If this is the last attempt, log a warning
              if (attempt == maxAttempts) {
                Logger.warning('⚠️ WARNING: Document keeps getting overwritten after $maxAttempts attempts!', tag: 'AuthService');
                Logger.debug('  This suggests getCurrentUserModel() is being called repeatedly.', tag: 'AuthService');
              }
            } else {
              Logger.debug('  ✓ Verification passed on attempt $attempt: familyId is correct', tag: 'AuthService');
              verified = true;
              break; // Success, no need to retry
            }
          }
        }
        
        if (!verified) {
          Logger.error('⚠️⚠️⚠️ CRITICAL: Could not verify correct familyId after $maxAttempts attempts!', tag: 'AuthService');
          Logger.warning('  The document keeps getting overwritten by something.', tag: 'AuthService');
          Logger.warning('  This is a race condition that needs to be fixed.', tag: 'AuthService');
        }

        // Update display name
        await userCredential.user!.updateDisplayName(displayName);
        
        // CRITICAL: Wait a moment and verify the document is still correct
        // This catches any race conditions where getCurrentUserModel() might have overwritten it
        await Future.delayed(const Duration(milliseconds: 500));
        final finalCheck = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get(GetOptions(source: Source.server));
        if (finalCheck.exists) {
          final finalData = finalCheck.data();
          final foundFamilyId = finalData?['familyId'] as String?;
          if (foundFamilyId != finalFamilyId) {
            Logger.warning('⚠️ FINAL CHECK: Document was overwritten! Fixing...', tag: 'AuthService');
            Logger.debug('  Expected: "$finalFamilyId"', tag: 'AuthService');
            Logger.debug('  Found: "$foundFamilyId"', tag: 'AuthService');
            await _firestore.collection('users').doc(userCredential.user!.uid).update({
              'familyId': finalFamilyId,
              'roles': roles,
            });
            Logger.info('✓ Fixed overwritten document', tag: 'AuthService');
            
            // Verify the fix worked
            await Future.delayed(const Duration(milliseconds: 200));
            final verifyFix = await _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .get(GetOptions(source: Source.server));
            final verifyFamilyId = verifyFix.data()?['familyId'] as String?;
            if (verifyFamilyId == finalFamilyId) {
              Logger.debug('✓✓ Fix verified: familyId is now correct', tag: 'AuthService');
            } else {
              Logger.warning('⚠️ Fix verification failed: still "$verifyFamilyId"', tag: 'AuthService');
            }
          } else {
            Logger.debug('✓ Final check passed: familyId is correct', tag: 'AuthService');
          }
        }
        
        // CRITICAL: Keep the registration flag active for a bit longer
        // This prevents getCurrentUserModel() from being called immediately after
        // and potentially overwriting the document
        Logger.debug('🔒 Keeping registration flag active for 2 more seconds to prevent overwrites...', tag: 'AuthService');
        await Future.delayed(const Duration(seconds: 2));
        
        // Final verification before removing flag
        final preRemoveCheck = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get(GetOptions(source: Source.server));
        if (preRemoveCheck.exists) {
          final preRemoveData = preRemoveCheck.data();
          final preRemoveFamilyId = preRemoveData?['familyId'] as String?;
          if (preRemoveFamilyId != finalFamilyId) {
            Logger.warning('⚠️ PRE-REMOVE CHECK: Document still has wrong familyId!', tag: 'AuthService');
            Logger.debug('  Expected: "$finalFamilyId"', tag: 'AuthService');
            Logger.debug('  Found: "$preRemoveFamilyId"', tag: 'AuthService');
            Logger.debug('  Fixing one more time...', tag: 'AuthService');
            await _firestore.collection('users').doc(userCredential.user!.uid).set({
              'uid': userCredential.user!.uid,
              'email': email,
              'displayName': displayName,
              'createdAt': userModel.createdAt.toIso8601String(),
              'familyId': finalFamilyId,
              'roles': roles,
            }, SetOptions(merge: false));
            Logger.debug('  ✓ Fixed before removing registration flag', tag: 'AuthService');
          } else {
            Logger.debug('✓ Pre-remove check passed: familyId is correct', tag: 'AuthService');
          }
        }
        
        // Now remove from registering set - registration is complete
        _registeringUserIds.remove(userId);
        Logger.debug('🔓 Removed user $userId from registering set', tag: 'AuthService');

        return userModel;
      }
      return null;
    } catch (e) {
      // Remove from registering set on error
      if (userId != null) {
        _registeringUserIds.remove(userId);
        Logger.debug('🔓 Removed user $userId from registering set (error occurred)', tag: 'AuthService');
      }
      // If it's already our custom exception, rethrow it
      if (e.toString().contains('Invalid family invitation code')) {
        rethrow;
      }
      throw _handleAuthError(e);
    }
  }

  // Sign out - ensure complete cleanup
  Future<void> signOut() async {
    try {
      Logger.info('Signing out user', tag: 'AuthService');
      await _auth.signOut();
      Logger.info('Sign out complete', tag: 'AuthService');
      // Give Firebase a moment to update auth state
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e, st) {
      Logger.error('Error during sign out', error: e, stackTrace: st, tag: 'AuthService');
      // Force sign out even if there's an error
      try {
        await _auth.signOut();
      } catch (_) {
        // Ignore secondary errors
      }
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Join family by family ID
  Future<void> joinFamily(String familyId) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('User not logged in', code: 'not-authenticated');

    // Clean the familyId (remove whitespace, but keep case as UUIDs are case-sensitive)
    final cleanFamilyId = familyId.trim();
    
    if (cleanFamilyId.isEmpty) {
      throw ValidationException('Family ID cannot be empty');
    }

    // Verify the family exists (check if at least one user has this familyId)
    // Note: Firestore queries are case-sensitive, so we need exact match
    try {
      Logger.info('Attempting to join family with code: $cleanFamilyId', tag: 'AuthService');
      Logger.debug('User ID: ${user.uid}', tag: 'AuthService');
      
      final familyCheck = await _firestore
          .collection('users')
          .where('familyId', isEqualTo: cleanFamilyId)
          .limit(1)
          .get();
      
      Logger.debug('Query result: ${familyCheck.docs.length} documents found', tag: 'AuthService');
      
      if (familyCheck.docs.isNotEmpty) {
        final foundUser = familyCheck.docs.first;
        Logger.debug('Found user with this familyId: ${foundUser.id}', tag: 'AuthService');
        Logger.debug('User data: ${foundUser.data()}', tag: 'AuthService');
      }
      
      if (familyCheck.docs.isEmpty) {
        // Debug: Let's check what familyIds actually exist
        Logger.warning('No exact match found for familyId: $cleanFamilyId', tag: 'AuthService');
        Logger.debug('Checking all users to see what familyIds exist...', tag: 'AuthService');
        
        try {
          final allUsers = await _firestore
              .collection('users')
              .limit(10)
              .get();
          
          Logger.debug('Total users checked: ${allUsers.docs.length}', tag: 'AuthService');
          for (var doc in allUsers.docs) {
            final data = doc.data();
            final familyId = data['familyId'] as String?;
            Logger.debug('User ${doc.id}: familyId = $familyId', tag: 'AuthService');
          }
        } catch (e, st) {
          Logger.warning('Error checking all users', error: e, stackTrace: st, tag: 'AuthService');
        }
        
        // Get current user's familyId to see the format
        final currentUserDoc = await _firestore.collection('users').doc(user.uid).get();
        if (currentUserDoc.exists) {
          final currentData = currentUserDoc.data();
          final currentFamilyId = currentData?['familyId'] as String?;
          Logger.debug('Current user familyId: $currentFamilyId', tag: 'AuthService');
        } else {
          Logger.warning('Current user document does not exist', tag: 'AuthService');
        }
        
        throw ValidationException('Invalid family invitation code. Please check the code and try again.\n\nCode provided: $cleanFamilyId');
      }

      // Check if user is already in this family
      final currentUserDoc = await _firestore.collection('users').doc(user.uid).get();
      if (currentUserDoc.exists) {
        final currentData = currentUserDoc.data();
        final currentFamilyId = currentData?['familyId'] as String?;
        if (currentFamilyId == cleanFamilyId) {
          throw ValidationException('You are already a member of this family.');
        }
        
        // User is in a different family - allow them to switch
        if (currentFamilyId != null && currentFamilyId.isNotEmpty) {
          Logger.info('User is switching from family $currentFamilyId to $cleanFamilyId', tag: 'AuthService');
        }
      }

      // Update user's familyId (this will switch them to the new family)
      await _firestore.collection('users').doc(user.uid).update({
        'familyId': cleanFamilyId,
      });
      
      Logger.info('Successfully joined family: $cleanFamilyId', tag: 'AuthService');
    } catch (e) {
      if (e.toString().contains('Invalid family invitation code') || 
          e.toString().contains('already a member')) {
        rethrow;
      }
      Logger.error('Error joining family', error: e, tag: 'AuthService');
      throw AuthException('Error joining family: $e', originalError: e);
    }
  }
  
  // Get family invitation code (returns the family ID)
  // If user doesn't have a familyId, creates one automatically
  Future<String?> getFamilyInvitationCode() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('User not logged in', code: 'not-authenticated');
    
    // First, ensure user document exists (getCurrentUserModel will create it if needed)
    final currentUserModel = await getCurrentUserModel();
    if (currentUserModel == null) {
      throw AuthException('Unable to load user information', code: 'user-load-failed');
    }
    
    // Verify the familyId from Firestore directly (not from cache)
    Logger.debug('=== GETTING FAMILY INVITATION CODE ===', tag: 'AuthService');
    Logger.debug('User ID: ${user.uid}', tag: 'AuthService');
    Logger.debug('UserModel familyId: ${currentUserModel.familyId}', tag: 'AuthService');
    
    // Read directly from Firestore to ensure we have the latest value
    final userDoc = await _firestore.collection('users').doc(user.uid).get(GetOptions(source: Source.server));
    if (userDoc.exists) {
      final docData = userDoc.data();
      final docFamilyId = docData?['familyId'] as String?;
      Logger.debug('Firestore document familyId: "$docFamilyId"', tag: 'AuthService');
      Logger.debug('FamilyId from model matches document: ${currentUserModel.familyId == docFamilyId}', tag: 'AuthService');
      
      if (docFamilyId != null && docFamilyId.isNotEmpty) {
        return docFamilyId;
      }
    } else {
      Logger.warning('WARNING: User document does not exist in Firestore!', tag: 'AuthService');
    }
    
    // If user already has a familyId, return it
    if (currentUserModel.familyId != null && currentUserModel.familyId!.isNotEmpty) {
      return currentUserModel.familyId;
    }
    
    // User doesn't have a familyId, create one
    final newFamilyId = const Uuid().v4();
    
    // Try to update first, if that fails (document might not exist), use set
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'familyId': newFamilyId,
      });
    } catch (e) {
      // If update fails, the document might not exist, so create it
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'User',
        createdAt: DateTime.now(),
        familyId: newFamilyId,
      );
      await _firestore.collection('users').doc(user.uid).set(userModel.toJson());
    }
    
    return newFamilyId;
  }
  
  // Initialize family ID for existing users who don't have one
  Future<void> initializeFamilyId() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('User not logged in', code: 'not-authenticated');
    
    // Get current user document
    final doc = await _firestore.collection('users').doc(user.uid).get();
    
    if (!doc.exists) {
      // Document doesn't exist, create it with familyId
      final newFamilyId = const Uuid().v4();
        // Check if this is the first user in the family
        final existingFamilyMembers = await _firestore
            .collection('users')
            .where('familyId', isEqualTo: newFamilyId)
            .get();
      
      final isFamilyCreator = existingFamilyMembers.docs.isEmpty;
      final List<String> roles = isFamilyCreator ? [AppConstants.roleAdmin] : [];
      
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'User',
        createdAt: DateTime.now(),
        familyId: newFamilyId,
        roles: roles,
      );
      await _firestore.collection('users').doc(user.uid).set(userModel.toJson());
      return;
    }
    
    // Document exists, check if it has familyId
    final data = doc.data();
    if (data == null) {
      throw AuthException('User document exists but has no data', code: 'invalid-document');
    }
    
    final currentFamilyId = data['familyId'] as String?;
    
    // If user already has a familyId, do nothing
    if (currentFamilyId != null && currentFamilyId.isNotEmpty) {
      return;
    }
    
    // Create a new familyId for the user
    final newFamilyId = const Uuid().v4();
    
    // Use set with merge to ensure we don't lose other fields
    await _firestore.collection('users').doc(user.uid).set({
      'familyId': newFamilyId,
    }, SetOptions(merge: true));
  }
  
  // Force initialize family ID (for debugging/fixing existing users)
  // This will create or update the familyId regardless of current state
  Future<String> forceInitializeFamilyId() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('User not logged in', code: 'not-authenticated');
    
    final newFamilyId = const Uuid().v4();
    
    // Get current document to preserve existing data
    final doc = await _firestore.collection('users').doc(user.uid).get();
    
    if (doc.exists) {
      // Update existing document
      final existingData = doc.data() ?? {};
      await _firestore.collection('users').doc(user.uid).set({
        ...existingData,
        'familyId': newFamilyId,
      }, SetOptions(merge: true));
    } else {
      // Create new document
      final userModel = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'User',
        createdAt: DateTime.now(),
        familyId: newFamilyId,
      );
      await _firestore.collection('users').doc(user.uid).set(userModel.toJson());
    }
    
    return newFamilyId;
  }
  
  // Join family by invitation code (alias for joinFamily for clarity)
  Future<void> joinFamilyByInvitationCode(String invitationCode) async {
    if (invitationCode.isEmpty) {
      throw ValidationException('Invitation code cannot be empty');
    }
    // Remove any whitespace - keep original case since UUIDs are case-sensitive
    final cleanCode = invitationCode.trim();
    if (cleanCode.isEmpty) {
      throw ValidationException('Invalid invitation code');
    }
    await joinFamily(cleanCode);
  }

  /// Directly update the current user's familyId to match another user's family
  /// This is useful for fixing familyId mismatches caused by auto-creation issues
  /// WARNING: This bypasses validation - use with caution
  Future<void> updateFamilyIdDirectly(String familyId) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('User not logged in', code: 'not-authenticated');

    final cleanFamilyId = familyId.trim();
    if (cleanFamilyId.isEmpty) {
      throw ValidationException('Family ID cannot be empty');
    }

    Logger.info('updateFamilyIdDirectly: Updating familyId for user ${user.uid}', tag: 'AuthService');
    Logger.debug('  New familyId: "$cleanFamilyId"', tag: 'AuthService');
    
    // Get current familyId for logging
    final currentDoc = await _firestore.collection('users').doc(user.uid).get();
    final currentData = currentDoc.data();
    final currentFamilyId = currentData?['familyId'] as String?;
    Logger.debug('  Current familyId: "$currentFamilyId"', tag: 'AuthService');

    // Verify the target family exists (at least one user has this familyId)
    final familyCheck = await _firestore
        .collection('users')
        .where('familyId', isEqualTo: cleanFamilyId)
        .limit(1)
        .get(GetOptions(source: Source.server));

    if (familyCheck.docs.isEmpty) {
      Logger.warning('⚠️ WARNING: No users found with familyId "$cleanFamilyId"', tag: 'AuthService');
      Logger.debug('  This family may not exist. Proceeding anyway as requested...', tag: 'AuthService');
    } else {
      final foundUser = familyCheck.docs.first;
      final foundData = foundUser.data();
      Logger.debug('  ✓ Found family with user: ${foundData['email'] ?? foundUser.id}', tag: 'AuthService');
    }

    // Update the familyId
    await _firestore.collection('users').doc(user.uid).update({
      'familyId': cleanFamilyId,
    });

    Logger.info('  ✓ FamilyId updated successfully', tag: 'AuthService');
    
    // Verify the update
    final verifyDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get(GetOptions(source: Source.server));
    final verifyFamilyId = verifyDoc.data()?['familyId'] as String?;
    
    if (verifyFamilyId == cleanFamilyId) {
      Logger.debug('  ✓✓ Verification passed: familyId is now "$verifyFamilyId"', tag: 'AuthService');
    } else {
      Logger.warning('  ⚠️ Verification failed: expected "$cleanFamilyId", got "$verifyFamilyId"', tag: 'AuthService');
      throw AuthException('FamilyId update verification failed', code: 'verification-failed');
    }
  }

  /// Get familyId for a specific user by email (useful for finding Kate's familyId)
  /// Returns null if user not found
  Future<String?> getFamilyIdByEmail(String email) async {
    try {
      Logger.debug('getFamilyIdByEmail: Looking for user with email: $email', tag: 'AuthService');
      
      // Query users by email
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get(GetOptions(source: Source.server));

      if (query.docs.isEmpty) {
        Logger.debug('  No user found with email: $email', tag: 'AuthService');
        return null;
      }

      final userDoc = query.docs.first;
      final data = userDoc.data();
      final familyId = data['familyId'] as String?;
      final displayName = data['displayName'] as String?;
      
      Logger.debug('  Found user: ${displayName ?? userDoc.id}', tag: 'AuthService');
      Logger.debug('  FamilyId: "$familyId"', tag: 'AuthService');
      
      return familyId;
    } catch (e, st) {
      Logger.warning('getFamilyIdByEmail: Error', error: e, stackTrace: st, tag: 'AuthService');
      return null;
    }
  }

  /// Get a user model by user ID
  Future<UserModel?> getUserModel(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromJson(doc.data()!);
    } catch (e) {
      Logger.error('Error getting user model', error: e, tag: 'AuthService');
      return null;
    }
  }

  // Get family members
  Future<List<UserModel>> getFamilyMembers() async {
    try {
      final currentUserModel = await getCurrentUserModel();
      if (currentUserModel == null || currentUserModel.familyId == null) {
        Logger.warning('getFamilyMembers: No current user model or familyId', tag: 'AuthService');
        return [];
      }

      Logger.debug('getFamilyMembers: Querying for familyId: "${currentUserModel.familyId}"', tag: 'AuthService');
      Logger.debug('getFamilyMembers: Current user ID: ${currentUserModel.uid}', tag: 'AuthService');
      Logger.debug('getFamilyMembers: Current user email: ${currentUserModel.email}', tag: 'AuthService');
      
      QuerySnapshot snapshot;
      try {
        snapshot = await _firestore
            .collection('users')
            .where('familyId', isEqualTo: currentUserModel.familyId)
            .get(GetOptions(source: Source.server));
      } catch (e, st) {
        Logger.warning('getFamilyMembers: Query failed with error', error: e, stackTrace: st, tag: 'AuthService');
        Logger.debug('getFamilyMembers: This might be a permission issue or missing index', tag: 'AuthService');
        
        // Fallback: Try to get all users and filter manually (less efficient but works)
        Logger.debug('getFamilyMembers: Attempting fallback method (get all users and filter)...', tag: 'AuthService');
        try {
          final allUsersSnapshot = await _firestore
              .collection('users')
              .limit(100)
              .get(GetOptions(source: Source.server));
          
          Logger.debug('getFamilyMembers: Retrieved ${allUsersSnapshot.docs.length} total users', tag: 'AuthService');
          
          final matchingUsers = allUsersSnapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final docFamilyId = data['familyId'] as String?;
            final matches = docFamilyId == currentUserModel.familyId;
            if (matches) {
              Logger.debug('  Found match: ${data['displayName']} (${doc.id}), familyId: "$docFamilyId"', tag: 'AuthService');
            }
            return matches;
          }).toList();
          
          Logger.debug('getFamilyMembers: Fallback found ${matchingUsers.length} matching members', tag: 'AuthService');
          
          return matchingUsers
              .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
        } catch (fallbackError, fallbackSt) {
          Logger.error('getFamilyMembers: Fallback method also failed', error: fallbackError, stackTrace: fallbackSt, tag: 'AuthService');
          return [];
        }
      }

      Logger.debug('getFamilyMembers: Found ${snapshot.docs.length} members', tag: 'AuthService');
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        Logger.debug('  - ${data['displayName']} (${doc.id}), familyId: "${data['familyId']}"', tag: 'AuthService');
      }

      return snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      Logger.error('getFamilyMembers: Unexpected error', error: e, stackTrace: stackTrace, tag: 'AuthService');
      return [];
    }
  }
  
  /// Get the family creator (the user who created the family)
  /// This is typically the user with the earliest createdAt date in the family
  Future<UserModel?> getFamilyCreator() async {
    final currentUserModel = await getCurrentUserModel();
    if (currentUserModel == null || currentUserModel.familyId == null) {
      return null;
    }

    try {
      // Try with index first (if it exists)
      final snapshot = await _firestore
          .collection('users')
          .where('familyId', isEqualTo: currentUserModel.familyId)
          .orderBy('createdAt', descending: false)
          .limit(1)
          .get(GetOptions(source: Source.server));

      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromJson(snapshot.docs.first.data());
      }
    } catch (e) {
      // If index doesn't exist, fall back to fetching all and sorting in memory
      Logger.warning('getFamilyCreator: Index error, falling back to in-memory sort', error: e, tag: 'AuthService');
      
      final snapshot = await _firestore
          .collection('users')
          .where('familyId', isEqualTo: currentUserModel.familyId)
          .get(GetOptions(source: Source.server));

      if (snapshot.docs.isEmpty) return null;

      // Sort by createdAt in memory
      final sorted = snapshot.docs.toList()
        ..sort((a, b) {
          final aCreated = a.data()['createdAt'] as String?;
          final bCreated = b.data()['createdAt'] as String?;
          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;
          return aCreated.compareTo(bCreated);
        });

      return UserModel.fromJson(sorted.first.data());
    }

    return null;
  }
  
  /// Update a user's relationship (Admin or family creator only)
  /// Automatically sets reciprocal relationships where applicable
  Future<void> updateRelationship(String userId, String? relationship) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw AuthException('User not logged in', code: 'not-authenticated');
    
    // Check if current user is Admin or family creator
    final currentUserModel = await getCurrentUserModel();
    if (currentUserModel == null) {
      throw AuthException('User not found', code: 'user-not-found');
    }
    
    final familyCreator = await getFamilyCreator();
    final isCreator = familyCreator?.uid == currentUser.uid;
    final isAdmin = currentUserModel.isAdmin();
    
    if (!isCreator && !isAdmin) {
      throw PermissionException('Only the family creator or Admins can update relationships', code: 'insufficient-permissions');
    }
    
    // Verify target user is in the same family
    final targetUserDoc = await _firestore.collection('users').doc(userId).get();
    if (!targetUserDoc.exists) {
      throw AuthException('User not found', code: 'user-not-found');
    }
    
    final targetUserData = targetUserDoc.data();
    if (targetUserData == null) {
      throw AuthException('User data not found', code: 'invalid-document');
    }
    
    final targetFamilyId = targetUserData['familyId'] as String?;
    if (targetFamilyId != currentUserModel.familyId) {
      throw PermissionException('Cannot update relationships for users outside your family', code: 'family-mismatch');
    }
    
    // Update relationship
    final updateData = <String, dynamic>{};
    if (relationship != null && relationship.isNotEmpty) {
      updateData['relationship'] = relationship;
    } else {
      // Remove relationship if null or empty
      updateData['relationship'] = null;
    }
    
    await _firestore.collection('users').doc(userId).update(updateData);
    
    // Automatically set reciprocal relationship if applicable
    if (relationship != null && relationship.isNotEmpty && !isCreator) {
      // If a non-creator is setting a relationship, ensure their own relationship
      // is set correctly so the reciprocal works
      final requiredRelationship = RelationshipUtils.getRequiredSetterRelationship(
        relationshipBeingSet: relationship,
        currentSetterRelationship: currentUserModel.relationship,
        isCreator: false,
      );
      
      if (requiredRelationship != null && 
          currentUserModel.relationship != requiredRelationship) {
        // Update the setter's relationship to make the reciprocal work
        await _firestore.collection('users').doc(currentUser.uid).update({
          'relationship': requiredRelationship,
        });
        Logger.debug('Automatically set reciprocal relationship: ${currentUserModel.displayName} -> $requiredRelationship', tag: 'AuthService');
      }
    }
  }
  
  // Role management methods (Admin only)
  
  /// Assign roles to a user (Admin only)
  Future<void> assignRoles(String userId, List<String> roles) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw AuthException('User not logged in', code: 'not-authenticated');
    
    // Check if current user is Admin
    final currentUserModel = await getCurrentUserModel();
    if (currentUserModel == null || !currentUserModel.isAdmin()) {
      throw PermissionException('Only Admins can assign roles', code: 'insufficient-permissions');
    }
    
    // Verify target user is in the same family
    final targetUserDoc = await _firestore.collection('users').doc(userId).get();
    if (!targetUserDoc.exists) {
      throw AuthException('User not found', code: 'user-not-found');
    }
    
    final targetUserData = targetUserDoc.data();
    if (targetUserData == null) {
      throw AuthException('User data not found', code: 'invalid-document');
    }
    
    final targetFamilyId = targetUserData['familyId'] as String?;
    if (targetFamilyId != currentUserModel.familyId) {
      throw PermissionException('Cannot assign roles to users outside your family', code: 'family-mismatch');
    }
    
    // Update roles
    await _firestore.collection('users').doc(userId).update({
      'roles': roles,
    });
  }
  
  /// Update displayName in Firestore from Firebase Auth
  /// This syncs the displayName from Firebase Auth profile to Firestore
  /// If Firebase Auth doesn't have displayName, it will try to get it from Firestore first,
  /// then fall back to email prefix
  Future<void> updateDisplayNameFromAuth() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('User not logged in', code: 'not-authenticated');
    
    // Get displayName from Firebase Auth
    String displayName = user.displayName ?? '';
    
    Logger.debug('updateDisplayNameFromAuth: Firebase Auth displayName: $displayName', tag: 'AuthService');
    Logger.debug('updateDisplayNameFromAuth: Firebase Auth email: ${user.email}', tag: 'AuthService');
    
    // If Firebase Auth doesn't have displayName, try to get it from Firestore first
    if (displayName.isEmpty) {
      try {
        final currentDoc = await _firestore.collection('users').doc(user.uid).get();
        if (currentDoc.exists) {
          final currentData = currentDoc.data() as Map<String, dynamic>?;
          final firestoreDisplayName = currentData?['displayName'] as String?;
          if (firestoreDisplayName != null && 
              firestoreDisplayName.isNotEmpty && 
              firestoreDisplayName != 'User') {
            displayName = firestoreDisplayName;
            Logger.debug('updateDisplayNameFromAuth: Using Firestore displayName: $displayName', tag: 'AuthService');
          }
        }
      } catch (e, st) {
        Logger.warning('updateDisplayNameFromAuth: Error reading Firestore', error: e, stackTrace: st, tag: 'AuthService');
      }
    }
    
    // If still empty, try to get it from email
    if (displayName.isEmpty && user.email != null) {
      final emailName = user.email!.split('@').first;
      // Capitalize first letter and handle camelCase
      if (emailName.isNotEmpty) {
        displayName = emailName[0].toUpperCase() + 
            (emailName.length > 1 ? emailName.substring(1) : '');
        // If it looks like camelCase (e.g., "simoncase"), try to split it
        if (emailName.length > 5 && !emailName.contains(RegExp(r'[A-Z]'))) {
          // Try to find word boundaries (e.g., "simoncase" -> "Simon Case")
          final words = emailName.split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])'));
          if (words.length > 1) {
            displayName = words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
          }
        }
      }
      Logger.debug('updateDisplayNameFromAuth: Using email-derived name: $displayName', tag: 'AuthService');
    }
    
    // If still empty, use a default
    if (displayName.isEmpty) {
      throw ValidationException('No displayName available. Please set it manually.');
    }
    
    // Update both Firestore and Firebase Auth
    await _firestore.collection('users').doc(user.uid).update({
      'displayName': displayName,
    });
    
    Logger.info('updateDisplayNameFromAuth: Updated Firestore displayName to $displayName', tag: 'AuthService');
    
    // Always update Firebase Auth (even if it's already set, to ensure sync)
    try {
      await user.updateDisplayName(displayName);
      Logger.info('updateDisplayNameFromAuth: Updated Firebase Auth displayName to $displayName', tag: 'AuthService');
    } catch (e, st) {
      Logger.warning('Error updating Firebase Auth displayName', error: e, stackTrace: st, tag: 'AuthService');
      // Continue even if this fails - Firestore is updated
    }
  }

  /// Self-assign admin role (one-time use for first user/family creator)
  /// This bypasses the admin check to allow the first user to become admin
  Future<void> selfAssignAdminRole() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw AuthException('User not logged in', code: 'not-authenticated');
    
    // Get current user document
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    if (!userDoc.exists) {
      throw AuthException('User document not found. Please use "Fix User Document" first.', code: 'user-not-found');
    }
    
    final userData = userDoc.data();
    if (userData == null) {
      throw AuthException('User data not found', code: 'invalid-document');
    }
    
    // Get current roles
    final currentRoles = <String>[];
    if (userData['roles'] != null) {
      if (userData['roles'] is List) {
        currentRoles.addAll((userData['roles'] as List).map((e) => e.toString().toLowerCase()));
      }
    }
    
    // Add admin role if not already present
    if (!currentRoles.contains(AppConstants.roleAdmin)) {
      currentRoles.add(AppConstants.roleAdmin);
      await _firestore.collection('users').doc(currentUser.uid).update({
        'roles': currentRoles,
      });
    } else {
      throw ValidationException('You already have the Admin role');
    }
  }

  /// Re-authenticate the current user with their password
  /// Required before sensitive operations like account deletion
  Future<void> reauthenticateUser(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('No user logged in', code: 'not-authenticated');
    if (user.email == null) throw AuthException('User email is missing', code: 'missing-email');

    try {
      // Create credential with email and password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      
      // Re-authenticate
      await user.reauthenticateWithCredential(credential);
      Logger.info('User re-authenticated successfully', tag: 'AuthService');
    } catch (e, st) {
      Logger.error('Error re-authenticating user', error: e, stackTrace: st, tag: 'AuthService');
      if (e is FirebaseAuthException) {
        throw AuthException.fromFirebaseCode(e.code);
      }
      rethrow;
    }
  }

  /// Delete the current user's account and all their data
  /// WARNING: This is irreversible!
  /// Requires recent authentication - call reauthenticateUser() first!
  /// If skipFirestoreDeletion is true, only deletes the Auth account (useful if Firestore data was already deleted)
  Future<void> deleteCurrentUserAccount({String? password, bool skipFirestoreDeletion = false}) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('No user logged in', code: 'not-authenticated');

    // If password is provided, re-authenticate first
    if (password != null && password.isNotEmpty) {
      await reauthenticateUser(password);
    }

    // Only delete Firestore data if not skipped (allows caller to handle deletion separately)
    if (!skipFirestoreDeletion) {
      final userModel = await getCurrentUserModel();
      final familyId = userModel?.familyId;
      final userId = user.uid;

      // Delete all user data from Firestore (errors are handled internally)
      try {
        await deleteUserData(userId, familyId);
      } catch (e) {
        Logger.warning('deleteCurrentUserAccount: Some Firestore deletions failed', error: e, tag: 'AuthService');
        // Continue to delete Auth account even if Firestore deletions fail
      }
    }

    // Always delete the Firebase Auth account, even if Firestore deletions failed
    try {
      await user.delete();
      Logger.info('deleteCurrentUserAccount: User ${user.uid} deleted from Auth', tag: 'AuthService');
    } catch (e, st) {
      Logger.error('deleteCurrentUserAccount: Error deleting Auth account', error: e, stackTrace: st, tag: 'AuthService');
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        throw AuthException('This operation requires recent authentication. Please re-enter your password.', code: 'requires-recent-login');
      }
      rethrow; // This is critical, so rethrow
    }
  }

  /// Delete all data for a specific user
  Future<void> deleteUserData(String userId, String? familyId) async {
    // Delete user document
    try {
      await _firestore.collection('users').doc(userId).delete();
      Logger.info('deleteUserData: Deleted user document for $userId', tag: 'AuthService');
    } catch (e, st) {
      Logger.warning('deleteUserData: Error deleting user document', error: e, stackTrace: st, tag: 'AuthService');
      // Continue even if this fails - we'll still delete the auth account
    }

    // Delete user's family collections if they have a familyId
    if (familyId != null) {
      try {
        await deleteFamilyData(familyId);
      } catch (e, st) {
        Logger.warning('deleteUserData: Error deleting family data', error: e, stackTrace: st, tag: 'AuthService');
        // Continue even if this fails
      }
    }

    // Also delete old user-specific collections (backward compatibility)
    try {
      final oldPath = 'families/$userId';
      await deleteCollectionRecursive(oldPath);
      Logger.info('deleteUserData: Deleted old user path $oldPath', tag: 'AuthService');
    } catch (e, st) {
      Logger.warning('deleteUserData: Error deleting old user path', error: e, stackTrace: st, tag: 'AuthService');
      // Continue even if this fails
    }
  }

  /// Delete all data for a family
  Future<void> deleteFamilyData(String familyId) async {
    try {
      final familyPath = 'families/$familyId';
      await deleteCollectionRecursive(familyPath);
      Logger.info('deleteFamilyData: Deleted family data for $familyId', tag: 'AuthService');
    } catch (e, st) {
      Logger.warning('deleteFamilyData: Error deleting family collections', error: e, stackTrace: st, tag: 'AuthService');
      // Continue to try deleting wallet document
    }

    // Delete family wallet document if it exists
    try {
      await _firestore.collection('families').doc(familyId).delete();
      Logger.info('deleteFamilyData: Deleted family wallet document', tag: 'AuthService');
    } catch (e, st) {
      Logger.warning('deleteFamilyData: Could not delete family wallet document', error: e, stackTrace: st, tag: 'AuthService');
      // This is okay - document might not exist or permissions might not allow it
    }
  }

  /// Recursively delete a collection and all its subcollections
  /// For families/{familyId}, this deletes tasks, events, messages, members subcollections
  Future<void> deleteCollectionRecursive(String collectionPath) async {
    try {
      // Handle families/{familyId} structure - delete subcollections directly
      if (collectionPath.startsWith('families/')) {
        final parts = collectionPath.split('/');
        if (parts.length == 2) {
          // families/{familyId} - delete all subcollections
          final familyId = parts[1];
          final subcollections = ['tasks', 'events', 'messages', 'members'];
          
          for (var subcollection in subcollections) {
            try {
              final subcollectionPath = '$collectionPath/$subcollection';
              final subcollectionRef = _firestore.collection(subcollectionPath);
              final subSnapshot = await subcollectionRef.get();
              
              if (subSnapshot.docs.isNotEmpty) {
                // Firestore batch limit is 500 operations, so we need to batch in chunks
                final batchSize = 500;
                for (int i = 0; i < subSnapshot.docs.length; i += batchSize) {
                  final batch = _firestore.batch();
                  final end = (i + batchSize < subSnapshot.docs.length) 
                      ? i + batchSize 
                      : subSnapshot.docs.length;
                  
                  for (int j = i; j < end; j++) {
                    batch.delete(subSnapshot.docs[j].reference);
                  }
                  await batch.commit();
                }
                Logger.info('deleteCollectionRecursive: Deleted $subcollectionPath (${subSnapshot.docs.length} docs)', tag: 'AuthService');
              }
            } catch (e, st) {
              Logger.warning('deleteCollectionRecursive: Error deleting $subcollection', error: e, stackTrace: st, tag: 'AuthService');
              // Continue with other subcollections
            }
          }
          return;
        }
      }
      
      // For other collection paths, delete documents directly
      final collectionRef = _firestore.collection(collectionPath);
      final snapshot = await collectionRef.get();
      
      if (snapshot.docs.isNotEmpty) {
        // Firestore batch limit is 500 operations
        final batchSize = 500;
        for (int i = 0; i < snapshot.docs.length; i += batchSize) {
          final batch = _firestore.batch();
          final end = (i + batchSize < snapshot.docs.length) 
              ? i + batchSize 
              : snapshot.docs.length;
          
          for (int j = i; j < end; j++) {
            batch.delete(snapshot.docs[j].reference);
          }
          await batch.commit();
        }
        Logger.info('deleteCollectionRecursive: Deleted $collectionPath (${snapshot.docs.length} docs)', tag: 'AuthService');
      }
    } catch (e, st) {
      Logger.error('deleteCollectionRecursive: Error deleting $collectionPath', error: e, stackTrace: st, tag: 'AuthService');
      rethrow; // Let caller handle the error
    }
  }

  /// Delete all notifications for the current user
  Future<void> deleteUserNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (notificationsSnapshot.docs.isEmpty) {
        Logger.debug('deleteUserNotifications: No notifications to delete', tag: 'AuthService');
        return;
      }

      // Firestore batch limit is 500 operations
      final batchSize = AppConstants.firestoreBatchSize;
      for (int i = 0; i < notificationsSnapshot.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < notificationsSnapshot.docs.length) 
            ? i + batchSize 
            : notificationsSnapshot.docs.length;
        
        for (int j = i; j < end; j++) {
          batch.delete(notificationsSnapshot.docs[j].reference);
        }
        await batch.commit();
      }
      Logger.info('deleteUserNotifications: Deleted ${notificationsSnapshot.docs.length} notifications', tag: 'AuthService');
    } catch (e, st) {
      Logger.warning('deleteUserNotifications: Error deleting notifications', error: e, stackTrace: st, tag: 'AuthService');
      // Continue even if this fails - notifications are not critical
    }
  }

  /// Complete database reset - delete current user and all their data
  /// WARNING: This will sign out the user and delete everything!
  Future<void> resetDatabaseForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('No user logged in', code: 'not-authenticated');

    final userModel = await getCurrentUserModel();
    final familyId = userModel?.familyId;
    final userId = user.uid;

    // Delete all user data
    await deleteUserData(userId, familyId);
    
    // Delete notifications
    await deleteUserNotifications();

    // Delete the Firebase Auth account
    await user.delete();
    
    Logger.info('resetDatabaseForCurrentUser: Complete reset completed for $userId', tag: 'AuthService');
  }

  Exception _handleAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      String message;
      switch (error.code) {
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
          break;
        case 'user-not-found':
          message = 'No user found for that email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'operation-not-allowed':
          message = 'Email/Password authentication is not enabled. Please enable it in Firebase Console > Authentication > Sign-in method.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection and try again.';
          break;
        case 'too-many-requests':
          message = 'Too many requests. Please try again later.';
          break;
        default:
          message = error.message ?? 'An error occurred: ${error.code}';
      }
      return AuthException(message, code: error.code, originalError: error);
    }
    // If it's already an AppException, return it
    if (error is AppException) {
      return error;
    }
    // If it's already an Exception, wrap it
    if (error is Exception) {
      return AuthException(error.toString(), originalError: error);
    }
    return AuthException(error.toString(), originalError: error);
  }
}

