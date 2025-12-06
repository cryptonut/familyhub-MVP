# Authentication Issue - Complete Documentation

## Problem Statement

**Issue:** Login times out after 30 seconds with "empty reCAPTCHA token" error on `develop` branch, but works perfectly on `release/qa` branch.

**Error in Logcat:**
```
I/FirebaseAuth(5777): Logging in as kalewis78@gmail.com with empty reCAPTCHA token
ERROR [AuthService] === TIMEOUT: Firebase Auth hung ===
```

**User Environment:**
- Physical device: Samsung SM-S906E (Android 16)
- `develop` branch: Fails via USB debugging
- `release/qa` branch: Works perfectly (APK installed on same device)

## What Works (release/qa)

- Login completes successfully
- No reCAPTCHA token errors
- Same MainActivity.kt workaround code exists
- Same SHA-1 fingerprints in Firebase Console
- Same google-services.json structure

## What Doesn't Work (develop)

- Login times out after 30 seconds
- "empty reCAPTCHA token" error in logcat
- MainActivity.kt workaround code exists but appears not to execute (no logs from MainActivity.onCreate() or disableAppVerification())
- Same SHA-1 fingerprints configured
- Same google-services.json structure

## Code Comparison

### MainActivity.kt
**Status:** IDENTICAL in both branches
- Both have `setAppVerificationDisabledForTesting(true)` workaround
- Both have retry logic with delays (500ms, 1500ms, 3000ms)
- Both have onResume() retry logic

### google-services.json
**Status:** Both dev and qa flavors have correct configuration
- Dev flavor: `com.example.familyhub_mvp.dev` → App ID: `1:559662117534:android:7b3b41176f0d550ee7c18f`
- QA flavor: `com.example.familyhub_mvp.test` → App ID: `1:559662117534:android:7b3b41176f0d550ee7c18f` (SAME app ID, different package)
- Both have OAuth clients configured
- Both have SHA-1 certificate hash: `bb7a6a5f57f1dd0ded142a5c6f2614fd54c3c71c`

### Firebase Console Configuration
**Status:** Verified correct
- SHA-1 fingerprint `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C` is present for:
  - `com.example.familyhub_mvp` (main app)
  - `com.example.familyhub_mvp.dev` (dev flavor)
  - `com.example.familyhub_mvp.test` (qa flavor)

### lib/main.dart
**Status:** Different between branches
- `develop` has CacheService initialization (non-blocking, with timeouts)
- `develop` has additional Firebase initialization logging
- Both disable App Check

### lib/services/auth_service.dart
**Status:** Similar timeout handling in both
- 30-second timeout
- Error messages about reCAPTCHA

## Attempted Fixes (All Failed)

### 1. MainActivity.kt Workaround
- **What:** Added `setAppVerificationDisabledForTesting(true)` in MainActivity.onCreate()
- **Result:** Code exists but doesn't appear to execute (no logs in logcat)
- **Why it might not work:** MainActivity logs may be filtered, or code not executing

### 2. Flutter Code Attempt
- **What:** Tried to call `auth.firebaseAuthSettings.setAppVerificationDisabledForTesting(true)` in lib/main.dart
- **Result:** Method may not exist in Flutter Firebase Auth package (needs verification)
- **Status:** Not tested/compiled yet

### 3. SHA-1 Fingerprint Configuration
- **What:** Verified SHA-1 is in Firebase Console for all apps
- **Result:** Already configured correctly
- **Conclusion:** Not the issue

### 4. reCAPTCHA Key Configuration
- **What:** Attempted to add SHA-1 to Google Cloud Console reCAPTCHA keys
- **Result:** No place to add SHA-1 in reCAPTCHA key configuration (keys are for SMS, not email/password)
- **Conclusion:** Wrong approach - reCAPTCHA keys don't need SHA-1

### 5. Firebase Console reCAPTCHA Settings
- **What:** Attempted to disable reCAPTCHA for email/password in Firebase Console
- **Result:** No toggle exists for email/password authentication (only for SMS/phone)
- **Conclusion:** Cannot disable reCAPTCHA for email/password in Firebase Console

### 6. CacheService Initialization
- **What:** Made CacheService initialization non-blocking with timeouts
- **Result:** Still fails
- **Conclusion:** Not the root cause

## Key Observations

1. **MainActivity logs missing:** No logs from MainActivity.onCreate() or disableAppVerification() in logcat, even though code exists
2. **Same code, different results:** Identical MainActivity.kt works in release/qa but not in develop
3. **Build type difference:** release/qa is release build (APK), develop is debug build (USB)
4. **OAuth client difference:** Dev and QA flavors use different OAuth client IDs but same app ID

## Unknowns / Questions for Investigation

1. **Why doesn't MainActivity.kt execute in develop?**
   - Is the Kotlin code being compiled?
   - Are logs being filtered?
   - Is there a build configuration difference?

2. **What's different about release/qa that makes it work?**
   - Build type (release vs debug)?
   - Firebase initialization timing?
   - OAuth client configuration?

3. **Is `setAppVerificationDisabledForTesting` available in Flutter?**
   - The method exists in native Android Firebase Auth
   - May not be exposed in Flutter Firebase Auth package
   - Needs verification

4. **Why does Firebase Auth require reCAPTCHA for email/password?**
   - This is unusual - reCAPTCHA is typically for phone/SMS auth
   - May indicate misconfiguration or Firebase project setting

## Files Modified (develop branch)

- `android/app/src/main/kotlin/com/example/familyhub_mvp/MainActivity.kt` - Workaround code added
- `lib/main.dart` - CacheService initialization, Firebase logging
- `lib/services/auth_service.dart` - Timeout handling, error messages
- `lib/services/notification_service.dart` - Fixed compilation errors
- `pubspec.yaml` - Updated firebase_auth to 5.7.0, vibration to 3.1.4

## Recommended Next Steps

1. **Verify MainActivity.kt is executing:**
   - Add simple Log.d() at start of onCreate() and verify it appears in unfiltered logcat
   - Check if Kotlin code is being compiled in debug builds

2. **Compare build configurations:**
   - Check if there's a difference in build.gradle.kts between branches
   - Verify ProGuard/R8 rules aren't stripping MainActivity code in debug

3. **Test Flutter method availability:**
   - Verify if `firebaseAuthSettings.setAppVerificationDisabledForTesting()` exists in Flutter package
   - If not, use platform channel to call native method

4. **Check OAuth client configuration:**
   - Verify OAuth client `559662117534-pd7lihihfu9k46l0328bat6vhobs9cc0` (dev flavor) is properly configured in Google Cloud Console
   - Compare with working OAuth client for qa flavor

5. **Firebase project settings:**
   - Check if there are any project-level settings that differ between environments
   - Verify API key restrictions allow Identity Toolkit API

## Current Status

**BLOCKED:** Cannot identify why identical code works in one branch but not the other. MainActivity workaround appears not to execute in develop branch, but reason is unknown.

---

**Documentation Date:** 2025-12-02  
**Branch:** develop  
**Issue:** Login timeout with "empty reCAPTCHA token"  
**Working Branch:** release/qa

