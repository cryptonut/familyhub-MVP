# Final Diagnosis and Fix - Login Timeout

## What We've Verified
- ✅ reCAPTCHA is disabled
- ✅ Identity Toolkit API is enabled
- ✅ SHA-1 matches debug keystore: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
- ✅ google-services.json exists and is valid
- ❌ Login still times out after 30s with no error

## The Real Issue: Silent API Key Rejection

When `signInWithEmailAndPassword` hangs for 30s with **no error**, it means the API key is being **silently rejected** before the request reaches Firebase.

## Most Likely Cause: API Key APPLICATION Restrictions

The API key has **TWO separate restriction types**:

### 1. API Restrictions (Which APIs)
- ✅ You checked: Identity Toolkit API is enabled
- This is NOT the issue

### 2. APPLICATION Restrictions (Which Apps) ⚠️
- **THIS IS LIKELY THE ISSUE**
- Controls which apps can use the key based on package name + SHA-1
- If set incorrectly, key is **silently rejected** (no error, just timeout)

## How to Fix

### Step 1: Check API Key APPLICATION Restrictions

1. Go to: https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0
2. Find **Android API key**: `YOUR_FIREBASE_API_KEY` (get from Firebase Console)
3. Click **Edit**
4. Look for **"Application restrictions"** section (separate from "API restrictions")

**If "Application restrictions" is set to "Android apps"**:
- Must include package: `com.example.familyhub_mvp`
- Must include SHA-1: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
- If SHA-1 is missing or wrong, **ADD IT** or change to "None"

**To test quickly**: Temporarily set "Application restrictions" to **"None"** and test login

### Step 2: Verify OAuth Client in Firebase Console

1. Go to: https://console.firebase.google.com/project/family-hub-71ff0/settings/general
2. Find your Android app
3. Check "SHA certificate fingerprints"
4. Must include: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
5. If missing, click "Add fingerprint" and add it
6. Download new `google-services.json` if you added SHA-1

### Step 3: Verify google-services.json is in Build

Even though the file exists, verify it's included:

```bash
flutter clean
flutter build apk --debug
```

Check if Firebase config is in the build:
- Look in `android/app/build/intermediates/merged_res/debug/values/values.xml`
- Should contain `google_api_key` and other Firebase config

### Step 4: Rebuild and Test

```bash
flutter clean
flutter pub get
flutter run
```

## Why APPLICATION Restrictions Cause Silent Timeout

When APPLICATION restrictions are set but SHA-1 doesn't match:
1. App tries to use API key
2. Google Cloud silently rejects it (doesn't match restrictions)
3. No error returned to app
4. Firebase SDK waits for response that never comes
5. After 30s, times out

This is **different** from API restrictions, which would return an error immediately.

## Expected Result After Fix

✅ Login completes in 2-5 seconds
✅ No timeout
✅ User successfully authenticates

## If Still Timing Out

Capture a new logcat:
```bash
adb logcat -d > new-test-$(Get-Date -Format 'yyyy-MM-dd_HHmmss').logcat
```

Look for:
1. Any new error messages
2. Network errors
3. OAuth client errors
4. Firebase initialization errors

## Summary

**Most likely fix**: Check API key **APPLICATION restrictions** in Google Cloud Console and ensure SHA-1 `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C` is included, or set to "None" for testing.
