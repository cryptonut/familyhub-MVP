# Action Required: Fix API Key Restrictions in Google Cloud Console

## ⚠️ CRITICAL: This Cannot Be Fixed in Code

The persistent Firestore unavailable error is caused by **API key configuration in Google Cloud Console**. This requires **manual changes** that only you (the human) can make.

## What Was Fixed in Code ✅

1. **Enhanced Error Diagnostics** - Error messages now clearly identify the root cause and provide fix instructions
2. **Better Logging** - Logs now show exactly what needs to be fixed
3. **Verification Script** - Created `scripts/verify_firebase_config.dart` to check configuration files

## What YOU Must Do (External Actions)

### Step 1: Enable Cloud Firestore API

**URL:** https://console.cloud.google.com/apis/library/firestore.googleapis.com?project=family-hub-71ff0

1. Click the link above (or navigate manually)
2. Click the **ENABLE** button
3. Wait for activation (usually instant)

### Step 2: Fix API Key Restrictions

**URL:** https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0

The API keys in your `google-services.json` are:
- `AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4`
- `AIzaSyDyevPyG6DAvW-0iJw-88ZymBtmkLi8k0M`

**For EACH API key:**

1. Click on the API key to edit it
2. **API Restrictions Section:**
   - Select **"Restrict key"**
   - Under **"API restrictions"**, click **"Select APIs"**
   - Ensure these are checked:
     - ✅ **Cloud Firestore API** (CRITICAL - this is likely missing!)
     - ✅ **Identity Toolkit API**
     - ✅ **Firebase Authentication API**
     - ✅ **Firebase Installations API**
   - Click **SAVE**

3. **Application Restrictions Section:**
   - **For dev environment (recommended):** Select **"None"** - no restrictions
   - **OR for production-like setup:** Select **"Android apps"**
     - Click **"ADD AN ITEM"**
     - Package name: `com.example.familyhub_mvp.dev`
     - SHA-1 certificate fingerprint: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
     - Click **DONE**
   - Click **SAVE**

### Step 3: Verify OAuth Client

**URL:** https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0

1. Click on **"OAuth 2.0 Client IDs"** in the left sidebar
2. Find the Android client with ID: `559662117534-pd7lihihfu9k46l0328bat6vhobs9cc0`
3. Verify:
   - Package name: `com.example.familyhub_mvp.dev`
   - SHA-1 certificate fingerprint: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
4. If SHA-1 doesn't match, click **EDIT** and update it

### Step 4: Configure OAuth Consent Screen

**URL:** https://console.cloud.google.com/apis/credentials/consent?project=family-hub-71ff0

1. Ensure OAuth consent screen is configured:
   - App name: Any name (e.g., "FamilyHub")
   - User support email: Your email
   - Developer contact email: Your email
2. Click through all steps and click **SAVE**
3. Wait 5-10 minutes for changes to propagate

### Step 5: Wait for Changes to Propagate

- API key changes: **1-2 minutes**
- OAuth client changes: **5-10 minutes**
- API enablement: **Usually instant**

### Step 6: Rebuild and Test

```bash
flutter clean
flutter pub get
flutter run --flavor dev
```

## How to Verify the Fix Worked

After making changes and rebuilding:

1. **Check logs** - You should see:
   - ✅ No `SecurityException: Unknown calling package name` errors
   - ✅ No `ConnectionResult{statusCode=DEVELOPER_ERROR}` errors
   - ✅ No `[cloud_firestore/unavailable]` errors
   - ✅ Firestore queries succeed
   - ✅ User data loads successfully

2. **Run verification script:**
   ```bash
   dart scripts/verify_firebase_config.dart
   ```

## Why This Is The Root Cause

The error `SecurityException: Unknown calling package name 'com.google.android.gms'` with `DEVELOPER_ERROR` occurs when:

1. Google Play Services tries to validate your API key
2. The API key either:
   - Doesn't have "Cloud Firestore API" in its API restrictions, OR
   - Has application restrictions that don't match your app's package + SHA-1
3. Google Play Services rejects the request **before** it reaches Firestore
4. Firestore then returns "unavailable" because the underlying service call failed

This is a **configuration issue**, not a code issue. The code changes ensure you get clear error messages pointing to the exact fix needed.

## Detailed Instructions

For step-by-step instructions with screenshots and more details, see:
- **`ROOT_CAUSE_FIX_API_KEY_RESTRICTIONS.md`** - Complete fix guide
- **`COMPLETE_FIX_SUMMARY.md`** - Summary of all changes

## Quick Reference

- **Enable Firestore API:** https://console.cloud.google.com/apis/library/firestore.googleapis.com?project=family-hub-71ff0
- **API Key Settings:** https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0
- **OAuth Consent Screen:** https://console.cloud.google.com/apis/credentials/consent?project=family-hub-71ff0

## If Issues Persist

1. Double-check the API key in logs matches the one in Google Cloud Console
2. Verify SHA-1 fingerprint matches exactly (no spaces, uppercase): `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
3. Ensure you're testing with the correct flavor: `flutter run --flavor dev`
4. Wait longer (up to 15 minutes) for changes to fully propagate
5. Check that you edited the correct API keys (there are 2 in google-services.json)
