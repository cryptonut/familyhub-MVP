import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../utils/relationship_utils.dart';
import 'package:uuid/uuid.dart';

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
      debugPrint('getCurrentUserModel: No Firebase Auth user - returning null');
      return null;
    }
    
    debugPrint('getCurrentUserModel: Firebase Auth user exists: ${user.uid} (${user.email})');
    debugPrint('getCurrentUserModel: Attempting to load user document from Firestore...');

    // If user is currently registering, wait briefly then try again
    if (_registeringUserIds.contains(user.uid)) {
      debugPrint('getCurrentUserModel: User ${user.uid} is currently registering, waiting...');
      await Future.delayed(const Duration(milliseconds: 500));
      if (_registeringUserIds.contains(user.uid)) {
        debugPrint('getCurrentUserModel: Still registering, returning null');
        return null;
      }
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    
    // CRITICAL FIX from code review: Ensure user doc exists before queries
    // This prevents Firestore rules circular dependency issues on Android cold-start
    // Use cacheAndServer (cache first, then server) to allow gRPC channel to establish naturally
    
    int maxRetries = 3;
    DateTime? startTime;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          debugPrint('getCurrentUserModel: Retry attempt $attempt/$maxRetries after ${attempt}s delay...');
          await Future.delayed(Duration(seconds: attempt));
        }
        
        debugPrint('getCurrentUserModel: Attempting Firestore query (attempt ${attempt + 1})...');
        startTime = DateTime.now();
        
        // For Android: use default behavior (cache first, then server)
        // This prevents "Channel shutdownNow" errors by not forcing immediate server connection
        // Note: Source.cacheAndServer doesn't exist in cloud_firestore 5.4.4+
        // Omitting source parameter uses default behavior: try cache first, then server
        DocumentSnapshot userDoc;
        if (kIsWeb) {
          // Web: always use server for consistency
          userDoc = await userRef
              .get(GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 15));
        } else {
          // Android: use default behavior (no source specified = cache first, then server)
          // This is equivalent to the non-existent Source.cacheAndServer
          // If this is a retry after unavailable error, force server source to bypass cache
          final useServerSource = attempt > 0;
          if (useServerSource) {
            debugPrint('getCurrentUserModel: Retry attempt - forcing server source to bypass cache');
            userDoc = await userRef
                .get(GetOptions(source: Source.server))
                .timeout(const Duration(seconds: 15));
          } else {
            userDoc = await userRef
                .get()
                .timeout(const Duration(seconds: 15));
          }
        }
        
        final elapsed = DateTime.now().difference(startTime);
        
        // If doc doesn't exist, create minimal user doc to satisfy Firestore rules
        if (!userDoc.exists) {
          debugPrint('getCurrentUserModel: User document does not exist for ${user.uid} - creating...');
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
            debugPrint('getCurrentUserModel: Created user document');
            // Re-fetch the newly created doc from server to ensure we have the latest
            userDoc = await userRef.get(GetOptions(source: Source.server));
          } catch (e) {
            debugPrint('getCurrentUserModel: Failed to create user doc: $e');
            return null;
          }
        }

        final data = userDoc.data();
        if (data == null) {
          debugPrint('getCurrentUserModel: User document has no data');
          return null;
        }
        
        debugPrint('getCurrentUserModel: Successfully loaded user data in ${elapsed.inMilliseconds}ms');
        return UserModel.fromJson(data as Map<String, dynamic>);
      } on TimeoutException {
        final elapsed = startTime != null ? DateTime.now().difference(startTime!) : const Duration(seconds: 0);
        debugPrint('getCurrentUserModel: Firestore query timeout after ${elapsed.inMilliseconds}ms (attempt ${attempt + 1})');
        if (attempt == maxRetries - 1) {
          debugPrint('getCurrentUserModel: ⚠ ALL RETRY ATTEMPTS FAILED - TIMEOUT');
          return null;
        }
      } catch (e, stackTrace) {
        final errorStr = e.toString().toLowerCase();
        final errorCode = e is FirebaseException ? e.code : 'unknown';
        debugPrint('getCurrentUserModel: Firestore error (attempt ${attempt + 1}/$maxRetries):');
        debugPrint('  Error: $e');
        debugPrint('  Error code: $errorCode');
        debugPrint('  Error type: ${e.runtimeType}');
        
        if (errorStr.contains('unavailable') || errorCode == 'unavailable') {
          debugPrint('getCurrentUserModel: ⚠ Firestore unavailable error detected');
          debugPrint('  Possible causes:');
          debugPrint('    - API key restrictions blocking Firestore API');
          debugPrint('    - Firestore API not enabled in Google Cloud Console');
          debugPrint('    - Network connectivity issues');
          debugPrint('    - App Check enforcement blocking requests');
          debugPrint('    - Firestore service temporarily down');
          
          if (attempt < maxRetries - 1) {
            debugPrint('getCurrentUserModel: Will retry (attempt ${attempt + 1}/$maxRetries) after ${attempt + 1}s delay...');
            // On last retry before giving up, try forcing server source to bypass cache
            if (attempt == maxRetries - 2 && !kIsWeb) {
              debugPrint('getCurrentUserModel: Last retry - will try forcing server source to bypass cache issues');
            }
          } else {
            debugPrint('getCurrentUserModel: ⚠ All retries exhausted - Firestore unavailable');
            debugPrint('  Stack trace: $stackTrace');
            return null;
          }
        } else {
          debugPrint('getCurrentUserModel: Non-unavailable error: $e');
          debugPrint('  Error code: $errorCode');
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
      debugPrint('=== AUTH SERVICE: SIGN IN START ===');
      debugPrint('Email: $email');
      debugPrint('Current user before sign in: ${_auth.currentUser?.uid ?? "null"}');
      debugPrint('Firebase Auth instance: ${_auth.app.name}');
      debugPrint('Firebase project ID: ${_auth.app.options.projectId}');
      
      // REMOVED: Network connectivity test - Firebase SDK handles this internally
      // REMOVED: signOut() before signIn() - Unusual pattern that can cause race conditions
      // Firebase Auth handles existing sessions automatically, no need to clear before sign-in
      
      debugPrint('AuthService: Calling Firebase signInWithEmailAndPassword...');
      debugPrint('AuthService: Email (trimmed): "${email.trim()}"');
      debugPrint('AuthService: Password length: ${password.length}');
      
      // Check Firebase Auth settings
      debugPrint('AuthService: Firebase Auth settings:');
      debugPrint('  - App name: ${_auth.app.name}');
      debugPrint('  - Project ID: ${_auth.app.options.projectId}');
      final apiKey = _auth.app.options.apiKey ?? '';
      if (apiKey.isNotEmpty) {
        debugPrint('  - API Key: ${apiKey.substring(0, 10)}...');
        debugPrint('  - Full API Key: $apiKey');
        debugPrint('  - NOTE: This is the ANDROID API key (different from web key)');
        debugPrint('  - If this times out, check restrictions for THIS key in Google Cloud Console');
      } else {
        debugPrint('  - API Key: NULL (this is a problem!)');
      }
      
      // Direct call to Firebase Auth - let it throw actual errors
      debugPrint('AuthService: Calling Firebase signInWithEmailAndPassword...');
      final startTime = DateTime.now();
      
      try {
        // Call Firebase Auth directly with a reasonable timeout
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            throw TimeoutException(
              'Firebase Auth sign-in timed out after 20 seconds',
              const Duration(seconds: 20),
            );
          },
        );
        
        final elapsed = DateTime.now().difference(startTime);
        debugPrint('AuthService: ✓ Firebase Auth succeeded in ${elapsed.inMilliseconds}ms');
        return _handleSignInSuccess(userCredential);
      } on TimeoutException catch (e) {
        debugPrint('=== TIMEOUT: Firebase Auth hung ===');
        debugPrint('Error: $e');
        // Check if Firebase is actually initialized
        try {
          final app = _auth.app;
          debugPrint('Firebase app name: ${app.name}');
          debugPrint('Firebase project ID: ${app.options.projectId}');
          debugPrint('Firebase API key: ${app.options.apiKey?.substring(0, 10) ?? "null"}...');
        } catch (e) {
          debugPrint('Cannot access Firebase app: $e');
        }
        rethrow;
      } on FirebaseAuthException catch (e) {
        debugPrint('=== FIREBASE AUTH ERROR ===');
        debugPrint('Code: ${e.code}');
        debugPrint('Message: ${e.message}');
        debugPrint('Full: $e');
        rethrow;
      } on PlatformException catch (e) {
        debugPrint('=== PLATFORM EXCEPTION (Native Android) ===');
        debugPrint('Code: ${e.code}');
        debugPrint('Message: ${e.message}');
        debugPrint('Details: ${e.details}');
        debugPrint('Full: $e');
        rethrow;
      } catch (e, stackTrace) {
        debugPrint('=== UNEXPECTED ERROR ===');
        debugPrint('Type: ${e.runtimeType}');
        debugPrint('Error: $e');
        debugPrint('Stack: $stackTrace');
        rethrow;
      }
    } on TimeoutException {
      debugPrint('AuthService: TimeoutException caught');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('=== AUTH SERVICE: SIGN IN ERROR ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw _handleAuthError(e);
    }
  }

  // Helper method to handle successful sign-in
  UserModel? _handleSignInSuccess(UserCredential userCredential) {
    if (userCredential.user == null) {
      debugPrint('AuthService: ERROR - Sign in succeeded but no user returned');
      throw Exception('Sign in succeeded but no user returned');
    }
    
    debugPrint('=== AUTH SERVICE: SIGN IN SUCCESS ===');
    debugPrint('User ID: ${userCredential.user!.uid}');
    debugPrint('Email: ${userCredential.user!.email}');
    
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
      debugPrint('=== REGISTRATION START ===');
      debugPrint('Email: $email');
      debugPrint('Display Name: $displayName');
      debugPrint('Invitation Code provided: ${familyId != null && familyId!.isNotEmpty}');
      if (familyId != null && familyId.isNotEmpty) {
        debugPrint('Invitation Code: "$familyId"');
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
        debugPrint('🔒 IMMEDIATELY marked user $userId as registering - preventing auto-creation');
        debugPrint('  Registration flag set BEFORE any document operations');
        // CRITICAL: Do NOT call getCurrentUserModel() here as it will auto-create
        // a user document with a new familyId before we process the invitation code!
        // We'll create the user document ourselves after verifying the family exists.
        
        // If familyId is provided, verify it exists BEFORE creating any user document
        String? finalFamilyId;
        bool isJoiningExistingFamily = false;
        
        debugPrint('=== REGISTRATION START ===');
        debugPrint('Email: $email');
        debugPrint('Display Name: $displayName');
        debugPrint('Invitation Code provided: ${familyId != null && familyId!.isNotEmpty}');
        if (familyId != null && familyId.isNotEmpty) {
          debugPrint('Invitation Code: "$familyId"');
        }
        
        if (familyId != null && familyId.isNotEmpty) {
          // Clean the familyId (remove whitespace, but keep case as UUIDs are case-sensitive)
          final cleanFamilyId = familyId.trim();
          
          debugPrint('=== REGISTRATION WITH FAMILY ID ===');
          debugPrint('Provided familyId: "$familyId"');
          debugPrint('Cleaned familyId: "$cleanFamilyId"');
          debugPrint('Length: ${cleanFamilyId.length}');
          debugPrint('Character codes: ${cleanFamilyId.codeUnits}');
          
          // Try multiple methods to verify the family exists
          bool familyExists = false;
          DocumentSnapshot? foundUserDoc;
          
          // Method 1: Query by familyId (preferred method)
          try {
            debugPrint('Method 1: Querying users collection by familyId...');
            final familyCheck = await _firestore
                .collection('users')
                .where('familyId', isEqualTo: cleanFamilyId)
                .limit(1)
                .get(GetOptions(source: Source.server));
            
            debugPrint('Query result: ${familyCheck.docs.length} documents found');
            
            if (familyCheck.docs.isNotEmpty) {
              foundUserDoc = familyCheck.docs.first;
              familyExists = true;
              debugPrint('✓ Family found via query method');
            } else {
              debugPrint('✗ Query returned no results');
            }
          } catch (e) {
            debugPrint('✗ Query method failed: $e');
            debugPrint('This might indicate a missing Firestore index');
          }
          
          // Method 2: If query failed, try reading all users and checking manually
          if (!familyExists) {
            try {
              debugPrint('Method 2: Reading all users and checking manually...');
              final allUsers = await _firestore
                  .collection('users')
                  .limit(50)
                  .get(GetOptions(source: Source.server));
              
              debugPrint('Total users in database: ${allUsers.docs.length}');
              
              for (var doc in allUsers.docs) {
                final data = doc.data();
                final existingFamilyId = data['familyId'] as String?;
                
                debugPrint('  Checking user ${doc.id}:');
                debugPrint('    Email: ${data['email']}');
                debugPrint('    familyId in DB: "$existingFamilyId"');
                debugPrint('    familyId length: ${existingFamilyId?.length ?? 0}');
                debugPrint('    Looking for: "$cleanFamilyId"');
                debugPrint('    Looking for length: ${cleanFamilyId.length}');
                debugPrint('    Codes match (==): ${existingFamilyId == cleanFamilyId}');
                debugPrint('    Codes match (compareTo): ${existingFamilyId?.compareTo(cleanFamilyId) ?? -999}');
                
                // Also check character by character
                if (existingFamilyId != null && existingFamilyId.length == cleanFamilyId.length) {
                  bool allMatch = true;
                  for (int i = 0; i < existingFamilyId.length; i++) {
                    if (existingFamilyId[i] != cleanFamilyId[i]) {
                      debugPrint('    Character mismatch at position $i: "${existingFamilyId[i]}" (${existingFamilyId.codeUnitAt(i)}) vs "${cleanFamilyId[i]}" (${cleanFamilyId.codeUnitAt(i)})');
                      allMatch = false;
                      break;
                    }
                  }
                  debugPrint('    Character-by-character match: $allMatch');
                }
                
                if (existingFamilyId != null && existingFamilyId == cleanFamilyId) {
                  foundUserDoc = doc;
                  familyExists = true;
                  debugPrint('✓ Family found via manual check!');
                  break;
                }
              }
              
              if (!familyExists) {
                debugPrint('✗ Manual check found no matching familyId');
                debugPrint('Summary: Searched ${allUsers.docs.length} users, none had familyId matching "$cleanFamilyId"');
              }
            } catch (e) {
              debugPrint('✗ Manual check method failed: $e');
            }
          }
          
          // Method 3: If still not found, wait a moment and retry (in case of timing issue)
          if (!familyExists) {
            debugPrint('Method 3: Waiting 2 seconds and retrying query (timing issue check)...');
            await Future.delayed(const Duration(seconds: 2));
            
            try {
              final retryCheck = await _firestore
                  .collection('users')
                  .where('familyId', isEqualTo: cleanFamilyId)
                  .limit(1)
                  .get(GetOptions(source: Source.server));
              
              debugPrint('Retry query result: ${retryCheck.docs.length} documents found');
              
              if (retryCheck.docs.isNotEmpty) {
                foundUserDoc = retryCheck.docs.first;
                familyExists = true;
                debugPrint('✓ Family found on retry!');
              }
            } catch (e) {
              debugPrint('✗ Retry query failed: $e');
            }
          }
          
          if (familyExists && foundUserDoc != null) {
            // Valid familyId - user is joining an existing family
            final foundData = foundUserDoc.data() as Map<String, dynamic>;
            debugPrint('=== FAMILY VERIFIED ===');
            debugPrint('Found user ID: ${foundUserDoc.id}');
            debugPrint('Found user email: ${foundData['email']}');
            debugPrint('Found user familyId: "${foundData['familyId']}"');
            debugPrint('FamilyId matches: ${foundData['familyId'] == cleanFamilyId}');
            
            finalFamilyId = cleanFamilyId;
            isJoiningExistingFamily = true;
            debugPrint('✓ User will join existing family: $finalFamilyId');
            debugPrint('  Continuing to create user document with this familyId...');
          } else {
            // Invalid familyId - throw error instead of creating new family
            debugPrint('=== ERROR: FAMILY NOT FOUND ===');
            debugPrint('Invalid family invitation code: "$cleanFamilyId"');
            debugPrint('No users found with this familyId using any method');
            
            // Delete the user account that was just created
            try {
              await userCredential.user!.delete();
              debugPrint('Deleted user account after invalid familyId');
            } catch (e) {
              debugPrint('Error deleting user account after invalid familyId: $e');
            }
            throw Exception('Invalid family invitation code. Please check the code and try again.\n\nCode provided: "$cleanFamilyId"\n\nIf you copied the code correctly, this might indicate the family no longer exists or there was an error.');
          }
        } else {
          // No familyId provided, create new one (user is creating a new family)
          finalFamilyId = const Uuid().v4();
          isJoiningExistingFamily = false;
          debugPrint('User is creating new family: $finalFamilyId');
        }
        
        // Check if this is the first user in the family (family creator gets Admin role)
        // Only check this if NOT joining an existing family
        debugPrint('=== DETERMINING ROLES ===');
        debugPrint('isJoiningExistingFamily: $isJoiningExistingFamily');
        debugPrint('finalFamilyId: $finalFamilyId');
        
        final List<String> roles;
        if (isJoiningExistingFamily) {
          // Joining existing family - no roles (not Admin)
          roles = [];
          debugPrint('✓ User joining existing family - no roles assigned');
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
            debugPrint('Checked for existing family members: found ${existingFamilyMembers.docs.length}');
          } catch (e) {
            debugPrint('Error checking for existing family members (assuming creator): $e');
            // If query fails, assume user is creator (safe default for new family)
            isFamilyCreator = true;
          }
          
          roles = isFamilyCreator ? ['admin'] : [];
          debugPrint('User creating new family - isFamilyCreator: $isFamilyCreator, roles: $roles');
        }
        
        // CRITICAL: Check if user document was auto-created by getCurrentUserModel()
        // This can happen if auth state changes trigger getCurrentUserModel() before
        // we finish processing the invitation code
        debugPrint('=== CHECKING FOR EXISTING DOCUMENT ===');
        debugPrint('User ID: ${userCredential.user!.uid}');
        final existingDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get(GetOptions(source: Source.server));
        debugPrint('Document exists: ${existingDoc.exists}');
        
        if (existingDoc.exists) {
          final existingData = existingDoc.data();
          final existingFamilyId = existingData?['familyId'] as String?;
          debugPrint('⚠️ WARNING: User document already exists!');
          debugPrint('  This suggests getCurrentUserModel() was called before registration completed.');
          debugPrint('  Existing familyId: "$existingFamilyId"');
          debugPrint('  Intended familyId: "$finalFamilyId"');
          
          if (existingFamilyId != null && existingFamilyId != finalFamilyId) {
            debugPrint('  ⚠️ CONFLICT DETECTED: User document has wrong familyId!');
            debugPrint('  This is the root cause - auto-created document overwrote invitation code.');
            debugPrint('  Fixing by updating to correct familyId...');
          }
        } else {
          debugPrint('✓ User document does not exist yet (good - no auto-creation happened)');
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
              debugPrint('Error parsing createdAt string: $e');
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

        debugPrint('=== USER DOCUMENT CREATED/UPDATED ===');
        debugPrint('User ID: ${userCredential.user!.uid}');
        debugPrint('Family ID: $finalFamilyId (${isJoiningExistingFamily ? "JOINING EXISTING" : "NEW FAMILY"})');
        debugPrint('Roles: $roles');
        debugPrint('Email: $email');
        
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
            debugPrint('✓ Verification attempt $attempt: Document familyId = "$verifyFamilyId"');
            if (verifyFamilyId != finalFamilyId) {
              debugPrint('  ⚠️ VERIFICATION FAILED on attempt $attempt: Document was overwritten!');
              debugPrint('  Expected: "$finalFamilyId"');
              debugPrint('  Found: "$verifyFamilyId"');
              debugPrint('  Something is overwriting the document - fixing again...');
              
              // Use set() with merge: false to completely overwrite
              await _firestore.collection('users').doc(userCredential.user!.uid).set({
                'uid': userCredential.user!.uid,
                'email': email,
                'displayName': displayName,
                'createdAt': userModel.createdAt.toIso8601String(),
                'familyId': finalFamilyId, // CORRECT familyId
                'roles': roles,
              }, SetOptions(merge: false));
              
              debugPrint('  ✓ Fixed on attempt $attempt (using set with merge: false)');
              
              // If this is the last attempt, log a warning
              if (attempt == maxAttempts) {
                debugPrint('  ⚠️ WARNING: Document keeps getting overwritten after $maxAttempts attempts!');
                debugPrint('  This suggests getCurrentUserModel() is being called repeatedly.');
              }
            } else {
              debugPrint('  ✓ Verification passed on attempt $attempt: familyId is correct');
              verified = true;
              break; // Success, no need to retry
            }
          }
        }
        
        if (!verified) {
          debugPrint('⚠️⚠️⚠️ CRITICAL: Could not verify correct familyId after $maxAttempts attempts!');
          debugPrint('  The document keeps getting overwritten by something.');
          debugPrint('  This is a race condition that needs to be fixed.');
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
            debugPrint('⚠️ FINAL CHECK: Document was overwritten! Fixing...');
            debugPrint('  Expected: "$finalFamilyId"');
            debugPrint('  Found: "$foundFamilyId"');
            await _firestore.collection('users').doc(userCredential.user!.uid).update({
              'familyId': finalFamilyId,
              'roles': roles,
            });
            debugPrint('✓ Fixed overwritten document');
            
            // Verify the fix worked
            await Future.delayed(const Duration(milliseconds: 200));
            final verifyFix = await _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .get(GetOptions(source: Source.server));
            final verifyFamilyId = verifyFix.data()?['familyId'] as String?;
            if (verifyFamilyId == finalFamilyId) {
              debugPrint('✓✓ Fix verified: familyId is now correct');
            } else {
              debugPrint('⚠️ Fix verification failed: still "$verifyFamilyId"');
            }
          } else {
            debugPrint('✓ Final check passed: familyId is correct');
          }
        }
        
        // CRITICAL: Keep the registration flag active for a bit longer
        // This prevents getCurrentUserModel() from being called immediately after
        // and potentially overwriting the document
        debugPrint('🔒 Keeping registration flag active for 2 more seconds to prevent overwrites...');
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
            debugPrint('⚠️ PRE-REMOVE CHECK: Document still has wrong familyId!');
            debugPrint('  Expected: "$finalFamilyId"');
            debugPrint('  Found: "$preRemoveFamilyId"');
            debugPrint('  Fixing one more time...');
            await _firestore.collection('users').doc(userCredential.user!.uid).set({
              'uid': userCredential.user!.uid,
              'email': email,
              'displayName': displayName,
              'createdAt': userModel.createdAt.toIso8601String(),
              'familyId': finalFamilyId,
              'roles': roles,
            }, SetOptions(merge: false));
            debugPrint('  ✓ Fixed before removing registration flag');
          } else {
            debugPrint('✓ Pre-remove check passed: familyId is correct');
          }
        }
        
        // Now remove from registering set - registration is complete
        _registeringUserIds.remove(userId);
        debugPrint('🔓 Removed user $userId from registering set');

        return userModel;
      }
      return null;
    } catch (e) {
      // Remove from registering set on error
      if (userId != null) {
        _registeringUserIds.remove(userId);
        debugPrint('🔓 Removed user $userId from registering set (error occurred)');
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
      debugPrint('AuthService: Signing out user');
      await _auth.signOut();
      debugPrint('AuthService: Sign out complete');
      // Give Firebase a moment to update auth state
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('AuthService: Error during sign out: $e');
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
    if (user == null) throw Exception('User not logged in');

    // Clean the familyId (remove whitespace, but keep case as UUIDs are case-sensitive)
    final cleanFamilyId = familyId.trim();
    
    if (cleanFamilyId.isEmpty) {
      throw Exception('Family ID cannot be empty');
    }

    // Verify the family exists (check if at least one user has this familyId)
    // Note: Firestore queries are case-sensitive, so we need exact match
    try {
      debugPrint('Attempting to join family with code: $cleanFamilyId');
      debugPrint('User ID: ${user.uid}');
      
      final familyCheck = await _firestore
          .collection('users')
          .where('familyId', isEqualTo: cleanFamilyId)
          .limit(1)
          .get();
      
      debugPrint('Query result: ${familyCheck.docs.length} documents found');
      
      if (familyCheck.docs.isNotEmpty) {
        final foundUser = familyCheck.docs.first;
        debugPrint('Found user with this familyId: ${foundUser.id}');
        debugPrint('User data: ${foundUser.data()}');
      }
      
      if (familyCheck.docs.isEmpty) {
        // Debug: Let's check what familyIds actually exist
        debugPrint('No exact match found for familyId: $cleanFamilyId');
        debugPrint('Checking all users to see what familyIds exist...');
        
        try {
          final allUsers = await _firestore
              .collection('users')
              .limit(10)
              .get();
          
          debugPrint('Total users checked: ${allUsers.docs.length}');
          for (var doc in allUsers.docs) {
            final data = doc.data();
            final familyId = data['familyId'] as String?;
            debugPrint('User ${doc.id}: familyId = $familyId');
          }
        } catch (e) {
          debugPrint('Error checking all users: $e');
        }
        
        // Get current user's familyId to see the format
        final currentUserDoc = await _firestore.collection('users').doc(user.uid).get();
        if (currentUserDoc.exists) {
          final currentData = currentUserDoc.data();
          final currentFamilyId = currentData?['familyId'] as String?;
          debugPrint('Current user familyId: $currentFamilyId');
        } else {
          debugPrint('Current user document does not exist');
        }
        
        throw Exception('Invalid family invitation code. Please check the code and try again.\n\nCode provided: $cleanFamilyId');
      }

      // Check if user is already in this family
      final currentUserDoc = await _firestore.collection('users').doc(user.uid).get();
      if (currentUserDoc.exists) {
        final currentData = currentUserDoc.data();
        final currentFamilyId = currentData?['familyId'] as String?;
        if (currentFamilyId == cleanFamilyId) {
          throw Exception('You are already a member of this family.');
        }
        
        // User is in a different family - allow them to switch
        if (currentFamilyId != null && currentFamilyId.isNotEmpty) {
          debugPrint('User is switching from family $currentFamilyId to $cleanFamilyId');
        }
      }

      // Update user's familyId (this will switch them to the new family)
      await _firestore.collection('users').doc(user.uid).update({
        'familyId': cleanFamilyId,
      });
      
      debugPrint('Successfully joined family: $cleanFamilyId');
    } catch (e) {
      if (e.toString().contains('Invalid family invitation code') || 
          e.toString().contains('already a member')) {
        rethrow;
      }
      debugPrint('Error joining family: $e');
      throw Exception('Error joining family: $e');
    }
  }
  
  // Get family invitation code (returns the family ID)
  // If user doesn't have a familyId, creates one automatically
  Future<String?> getFamilyInvitationCode() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    // First, ensure user document exists (getCurrentUserModel will create it if needed)
    final currentUserModel = await getCurrentUserModel();
    if (currentUserModel == null) {
      throw Exception('Unable to load user information');
    }
    
    // Verify the familyId from Firestore directly (not from cache)
    debugPrint('=== GETTING FAMILY INVITATION CODE ===');
    debugPrint('User ID: ${user.uid}');
    debugPrint('UserModel familyId: ${currentUserModel.familyId}');
    
    // Read directly from Firestore to ensure we have the latest value
    final userDoc = await _firestore.collection('users').doc(user.uid).get(GetOptions(source: Source.server));
    if (userDoc.exists) {
      final docData = userDoc.data();
      final docFamilyId = docData?['familyId'] as String?;
      debugPrint('Firestore document familyId: "$docFamilyId"');
      debugPrint('FamilyId from model matches document: ${currentUserModel.familyId == docFamilyId}');
      
      if (docFamilyId != null && docFamilyId.isNotEmpty) {
        return docFamilyId;
      }
    } else {
      debugPrint('WARNING: User document does not exist in Firestore!');
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
    if (user == null) throw Exception('User not logged in');
    
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
      final List<String> roles = isFamilyCreator ? ['admin'] : [];
      
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
      throw Exception('User document exists but has no data');
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
    if (user == null) throw Exception('User not logged in');
    
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
      throw Exception('Invitation code cannot be empty');
    }
    // Remove any whitespace - keep original case since UUIDs are case-sensitive
    final cleanCode = invitationCode.trim();
    if (cleanCode.isEmpty) {
      throw Exception('Invalid invitation code');
    }
    await joinFamily(cleanCode);
  }

  /// Directly update the current user's familyId to match another user's family
  /// This is useful for fixing familyId mismatches caused by auto-creation issues
  /// WARNING: This bypasses validation - use with caution
  Future<void> updateFamilyIdDirectly(String familyId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final cleanFamilyId = familyId.trim();
    if (cleanFamilyId.isEmpty) {
      throw Exception('Family ID cannot be empty');
    }

    debugPrint('updateFamilyIdDirectly: Updating familyId for user ${user.uid}');
    debugPrint('  New familyId: "$cleanFamilyId"');
    
    // Get current familyId for logging
    final currentDoc = await _firestore.collection('users').doc(user.uid).get();
    final currentData = currentDoc.data();
    final currentFamilyId = currentData?['familyId'] as String?;
    debugPrint('  Current familyId: "$currentFamilyId"');

    // Verify the target family exists (at least one user has this familyId)
    final familyCheck = await _firestore
        .collection('users')
        .where('familyId', isEqualTo: cleanFamilyId)
        .limit(1)
        .get(GetOptions(source: Source.server));

    if (familyCheck.docs.isEmpty) {
      debugPrint('  ⚠️ WARNING: No users found with familyId "$cleanFamilyId"');
      debugPrint('  This family may not exist. Proceeding anyway as requested...');
    } else {
      final foundUser = familyCheck.docs.first;
      final foundData = foundUser.data();
      debugPrint('  ✓ Found family with user: ${foundData['email'] ?? foundUser.id}');
    }

    // Update the familyId
    await _firestore.collection('users').doc(user.uid).update({
      'familyId': cleanFamilyId,
    });

    debugPrint('  ✓ FamilyId updated successfully');
    
    // Verify the update
    final verifyDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get(GetOptions(source: Source.server));
    final verifyFamilyId = verifyDoc.data()?['familyId'] as String?;
    
    if (verifyFamilyId == cleanFamilyId) {
      debugPrint('  ✓✓ Verification passed: familyId is now "$verifyFamilyId"');
    } else {
      debugPrint('  ⚠️ Verification failed: expected "$cleanFamilyId", got "$verifyFamilyId"');
      throw Exception('FamilyId update verification failed');
    }
  }

  /// Get familyId for a specific user by email (useful for finding Kate's familyId)
  /// Returns null if user not found
  Future<String?> getFamilyIdByEmail(String email) async {
    try {
      debugPrint('getFamilyIdByEmail: Looking for user with email: $email');
      
      // Query users by email
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get(GetOptions(source: Source.server));

      if (query.docs.isEmpty) {
        debugPrint('  No user found with email: $email');
        return null;
      }

      final userDoc = query.docs.first;
      final data = userDoc.data();
      final familyId = data['familyId'] as String?;
      final displayName = data['displayName'] as String?;
      
      debugPrint('  Found user: ${displayName ?? userDoc.id}');
      debugPrint('  FamilyId: "$familyId"');
      
      return familyId;
    } catch (e) {
      debugPrint('getFamilyIdByEmail: Error: $e');
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
      debugPrint('Error getting user model: $e');
      return null;
    }
  }

  // Get family members
  Future<List<UserModel>> getFamilyMembers() async {
    try {
      final currentUserModel = await getCurrentUserModel();
      if (currentUserModel == null || currentUserModel.familyId == null) {
        debugPrint('getFamilyMembers: No current user model or familyId');
        return [];
      }

      debugPrint('getFamilyMembers: Querying for familyId: "${currentUserModel.familyId}"');
      debugPrint('getFamilyMembers: Current user ID: ${currentUserModel.uid}');
      debugPrint('getFamilyMembers: Current user email: ${currentUserModel.email}');
      
      QuerySnapshot snapshot;
      try {
        snapshot = await _firestore
            .collection('users')
            .where('familyId', isEqualTo: currentUserModel.familyId)
            .get(GetOptions(source: Source.server));
      } catch (e) {
        debugPrint('getFamilyMembers: Query failed with error: $e');
        debugPrint('getFamilyMembers: This might be a permission issue or missing index');
        
        // Fallback: Try to get all users and filter manually (less efficient but works)
        debugPrint('getFamilyMembers: Attempting fallback method (get all users and filter)...');
        try {
          final allUsersSnapshot = await _firestore
              .collection('users')
              .limit(100)
              .get(GetOptions(source: Source.server));
          
          debugPrint('getFamilyMembers: Retrieved ${allUsersSnapshot.docs.length} total users');
          
          final matchingUsers = allUsersSnapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final docFamilyId = data['familyId'] as String?;
            final matches = docFamilyId == currentUserModel.familyId;
            if (matches) {
              debugPrint('  Found match: ${data['displayName']} (${doc.id}), familyId: "$docFamilyId"');
            }
            return matches;
          }).toList();
          
          debugPrint('getFamilyMembers: Fallback found ${matchingUsers.length} matching members');
          
          return matchingUsers
              .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
              .toList();
        } catch (fallbackError) {
          debugPrint('getFamilyMembers: Fallback method also failed: $fallbackError');
          return [];
        }
      }

      debugPrint('getFamilyMembers: Found ${snapshot.docs.length} members');
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('  - ${data['displayName']} (${doc.id}), familyId: "${data['familyId']}"');
      }

      return snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('getFamilyMembers: Unexpected error: $e');
      debugPrint('getFamilyMembers: Stack trace: $stackTrace');
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
      debugPrint('getFamilyCreator: Index error, falling back to in-memory sort: $e');
      
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
    if (currentUser == null) throw Exception('User not logged in');
    
    // Check if current user is Admin or family creator
    final currentUserModel = await getCurrentUserModel();
    if (currentUserModel == null) {
      throw Exception('User not found');
    }
    
    final familyCreator = await getFamilyCreator();
    final isCreator = familyCreator?.uid == currentUser.uid;
    final isAdmin = currentUserModel.isAdmin();
    
    if (!isCreator && !isAdmin) {
      throw Exception('Only the family creator or Admins can update relationships');
    }
    
    // Verify target user is in the same family
    final targetUserDoc = await _firestore.collection('users').doc(userId).get();
    if (!targetUserDoc.exists) {
      throw Exception('User not found');
    }
    
    final targetUserData = targetUserDoc.data();
    if (targetUserData == null) {
      throw Exception('User data not found');
    }
    
    final targetFamilyId = targetUserData['familyId'] as String?;
    if (targetFamilyId != currentUserModel.familyId) {
      throw Exception('Cannot update relationships for users outside your family');
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
        debugPrint('Automatically set reciprocal relationship: ${currentUserModel.displayName} -> $requiredRelationship');
      }
    }
  }
  
  // Role management methods (Admin only)
  
  /// Assign roles to a user (Admin only)
  Future<void> assignRoles(String userId, List<String> roles) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');
    
    // Check if current user is Admin
    final currentUserModel = await getCurrentUserModel();
    if (currentUserModel == null || !currentUserModel.isAdmin()) {
      throw Exception('Only Admins can assign roles');
    }
    
    // Verify target user is in the same family
    final targetUserDoc = await _firestore.collection('users').doc(userId).get();
    if (!targetUserDoc.exists) {
      throw Exception('User not found');
    }
    
    final targetUserData = targetUserDoc.data();
    if (targetUserData == null) {
      throw Exception('User data not found');
    }
    
    final targetFamilyId = targetUserData['familyId'] as String?;
    if (targetFamilyId != currentUserModel.familyId) {
      throw Exception('Cannot assign roles to users outside your family');
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
    if (user == null) throw Exception('User not logged in');
    
    // Get displayName from Firebase Auth
    String displayName = user.displayName ?? '';
    
    debugPrint('AuthService.updateDisplayNameFromAuth: Firebase Auth displayName: $displayName');
    debugPrint('AuthService.updateDisplayNameFromAuth: Firebase Auth email: ${user.email}');
    
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
            debugPrint('AuthService.updateDisplayNameFromAuth: Using Firestore displayName: $displayName');
          }
        }
      } catch (e) {
        debugPrint('AuthService.updateDisplayNameFromAuth: Error reading Firestore: $e');
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
      debugPrint('AuthService.updateDisplayNameFromAuth: Using email-derived name: $displayName');
    }
    
    // If still empty, use a default
    if (displayName.isEmpty) {
      throw Exception('No displayName available. Please set it manually.');
    }
    
    // Update both Firestore and Firebase Auth
    await _firestore.collection('users').doc(user.uid).update({
      'displayName': displayName,
    });
    
    debugPrint('AuthService.updateDisplayNameFromAuth: Updated Firestore displayName to $displayName');
    
    // Always update Firebase Auth (even if it's already set, to ensure sync)
    try {
      await user.updateDisplayName(displayName);
      debugPrint('AuthService.updateDisplayNameFromAuth: Updated Firebase Auth displayName to $displayName');
    } catch (e) {
      debugPrint('Error updating Firebase Auth displayName: $e');
      // Continue even if this fails - Firestore is updated
    }
  }

  /// Self-assign admin role (one-time use for first user/family creator)
  /// This bypasses the admin check to allow the first user to become admin
  Future<void> selfAssignAdminRole() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');
    
    // Get current user document
    final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    if (!userDoc.exists) {
      throw Exception('User document not found. Please use "Fix User Document" first.');
    }
    
    final userData = userDoc.data();
    if (userData == null) {
      throw Exception('User data not found');
    }
    
    // Get current roles
    final currentRoles = <String>[];
    if (userData['roles'] != null) {
      if (userData['roles'] is List) {
        currentRoles.addAll((userData['roles'] as List).map((e) => e.toString().toLowerCase()));
      }
    }
    
    // Add admin role if not already present
    if (!currentRoles.contains('admin')) {
      currentRoles.add('admin');
      await _firestore.collection('users').doc(currentUser.uid).update({
        'roles': currentRoles,
      });
    } else {
      throw Exception('You already have the Admin role');
    }
  }

  /// Re-authenticate the current user with their password
  /// Required before sensitive operations like account deletion
  Future<void> reauthenticateUser(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');
    if (user.email == null) throw Exception('User email is missing');

    try {
      // Create credential with email and password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      
      // Re-authenticate
      await user.reauthenticateWithCredential(credential);
      debugPrint('User re-authenticated successfully');
    } catch (e) {
      debugPrint('Error re-authenticating user: $e');
      if (e is FirebaseAuthException) {
        if (e.code == 'wrong-password') {
          throw Exception('Incorrect password');
        } else if (e.code == 'user-mismatch') {
          throw Exception('User mismatch');
        } else if (e.code == 'user-not-found') {
          throw Exception('User not found');
        } else if (e.code == 'invalid-credential') {
          throw Exception('Invalid credentials');
        } else if (e.code == 'invalid-email') {
          throw Exception('Invalid email');
        } else if (e.code == 'too-many-requests') {
          throw Exception('Too many requests. Please try again later.');
        }
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
    if (user == null) throw Exception('No user logged in');

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
        debugPrint('AuthService.deleteCurrentUserAccount: Some Firestore deletions failed: $e');
        // Continue to delete Auth account even if Firestore deletions fail
      }
    }

    // Always delete the Firebase Auth account, even if Firestore deletions failed
    try {
      await user.delete();
      debugPrint('AuthService.deleteCurrentUserAccount: User ${user.uid} deleted from Auth');
    } catch (e) {
      debugPrint('AuthService.deleteCurrentUserAccount: Error deleting Auth account: $e');
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        throw Exception('This operation requires recent authentication. Please re-enter your password.');
      }
      rethrow; // This is critical, so rethrow
    }
  }

  /// Delete all data for a specific user
  Future<void> deleteUserData(String userId, String? familyId) async {
    // Delete user document
    try {
      await _firestore.collection('users').doc(userId).delete();
      debugPrint('AuthService.deleteUserData: Deleted user document for $userId');
    } catch (e) {
      debugPrint('AuthService.deleteUserData: Error deleting user document: $e');
      // Continue even if this fails - we'll still delete the auth account
    }

    // Delete user's family collections if they have a familyId
    if (familyId != null) {
      try {
        await deleteFamilyData(familyId);
      } catch (e) {
        debugPrint('AuthService.deleteUserData: Error deleting family data: $e');
        // Continue even if this fails
      }
    }

    // Also delete old user-specific collections (backward compatibility)
    try {
      final oldPath = 'families/$userId';
      await deleteCollectionRecursive(oldPath);
      debugPrint('AuthService.deleteUserData: Deleted old user path $oldPath');
    } catch (e) {
      debugPrint('AuthService.deleteUserData: Error deleting old user path: $e');
      // Continue even if this fails
    }
  }

  /// Delete all data for a family
  Future<void> deleteFamilyData(String familyId) async {
    try {
      final familyPath = 'families/$familyId';
      await deleteCollectionRecursive(familyPath);
      debugPrint('AuthService.deleteFamilyData: Deleted family data for $familyId');
    } catch (e) {
      debugPrint('AuthService.deleteFamilyData: Error deleting family collections: $e');
      // Continue to try deleting wallet document
    }

    // Delete family wallet document if it exists
    try {
      await _firestore.collection('families').doc(familyId).delete();
      debugPrint('AuthService.deleteFamilyData: Deleted family wallet document');
    } catch (e) {
      debugPrint('AuthService.deleteFamilyData: Could not delete family wallet document: $e');
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
                debugPrint('AuthService.deleteCollectionRecursive: Deleted $subcollectionPath (${subSnapshot.docs.length} docs)');
              }
            } catch (e) {
              debugPrint('AuthService.deleteCollectionRecursive: Error deleting $subcollection: $e');
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
        debugPrint('AuthService.deleteCollectionRecursive: Deleted $collectionPath (${snapshot.docs.length} docs)');
      }
    } catch (e) {
      debugPrint('AuthService.deleteCollectionRecursive: Error deleting $collectionPath: $e');
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
        debugPrint('AuthService.deleteUserNotifications: No notifications to delete');
        return;
      }

      // Firestore batch limit is 500 operations
      final batchSize = 500;
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
      debugPrint('AuthService.deleteUserNotifications: Deleted ${notificationsSnapshot.docs.length} notifications');
    } catch (e) {
      debugPrint('AuthService.deleteUserNotifications: Error deleting notifications: $e');
      // Continue even if this fails - notifications are not critical
    }
  }

  /// Complete database reset - delete current user and all their data
  /// WARNING: This will sign out the user and delete everything!
  Future<void> resetDatabaseForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    final userModel = await getCurrentUserModel();
    final familyId = userModel?.familyId;
    final userId = user.uid;

    // Delete all user data
    await deleteUserData(userId, familyId);
    
    // Delete notifications
    await deleteUserNotifications();

    // Delete the Firebase Auth account
    await user.delete();
    
    debugPrint('AuthService.resetDatabaseForCurrentUser: Complete reset completed for $userId');
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
      return Exception(message);
    }
    // If it's already an Exception, return it
    if (error is Exception) {
      return error;
    }
    return Exception(error.toString());
  }
}

