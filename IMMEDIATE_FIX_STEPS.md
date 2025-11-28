# IMMEDIATE FIX - Authentication Timeout

## Problem
Login times out after 30 seconds on Android, even though OAuth clients are now in `google-services.json`.

## Root Cause
**The app was NOT rebuilt after `google-services.json` was updated.** Android Gradle caches the `google-services.json` file during build, so the old build still has the empty OAuth client array.

## Evidence
✅ `google-services.json` has 2 OAuth clients (verified)
❌ New logcat has 0 Flutter messages (app not rebuilt)
❌ No build directory exists (needs complete rebuild)

## Solution - Run These Commands

### Step 1: Complete Clean Rebuild
```bash
# Clean everything
flutter clean

# Get dependencies
flutter pub get

# Uninstall old app from device
adb uninstall com.example.familyhub_mvp

# Rebuild and run
flutter run
```

### Step 2: If Still Timing Out - Check API Key Restrictions

Go to [Google Cloud Console](https://console.cloud.google.com/):
1. **APIs & Services > Credentials**
2. Find API key: `YOUR_FIREBASE_API_KEY`
3. Click to edit
4. Under **API restrictions**:
   - Ensure **Identity Toolkit API** is enabled
   - OR set to "Don't restrict key" for testing
5. Click **Save**

### Step 3: Verify OAuth Clients in Google Cloud

1. **APIs & Services > Credentials > OAuth 2.0 Client IDs**
2. Verify Android client exists with:
   - Package: `com.example.familyhub_mvp`
   - SHA-1: `bb7a6a5f57f1dd0ded142a5c6f2614fd54c3c71c`
3. If missing, create it manually

### Step 4: Test After Rebuild

After running `flutter run`:
1. Attempt login
2. Should complete in 2-5 seconds
3. Should NOT see "Still waiting" messages
4. Should NOT timeout after 30s

## Why This Will Work

The OAuth client fix was **correct** - `google-services.json` has 2 OAuth clients. The issue is that Android Gradle needs to process this file during build. Without `flutter clean`, the old cached version is still used.

## If Still Failing After Rebuild

1. Check API key restrictions (most common)
2. Verify OAuth consent screen is configured
3. Re-download `google-services.json` from Firebase Console
4. Check Firebase Auth is enabled in Firebase Console
5. Temporarily disable App Check for testing

## Quick Command Summary

```bash
flutter clean && flutter pub get && adb uninstall com.example.familyhub_mvp && flutter run
```

Run this and test login again.

