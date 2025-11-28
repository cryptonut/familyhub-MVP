# CRITICAL: Check API Key APPLICATION Restrictions

## The Issue

Login times out silently (30s) with no error. This typically means the API key is being **silently rejected** due to **APPLICATION restrictions**, not API restrictions.

## API Key Has TWO Types of Restrictions

### 1. API Restrictions (Which APIs Can Be Called)
- ✅ You already checked this
- Identity Toolkit API is enabled
- This is NOT the issue

### 2. APPLICATION Restrictions (Which Apps Can Use the Key) ⚠️
- **THIS IS LIKELY THE ISSUE**
- If set, the key can ONLY be used by apps matching the package name + SHA-1
- If SHA-1 doesn't match, the key is **silently rejected** (no error, just timeout)

## How to Check APPLICATION Restrictions

### Step 1: Go to Google Cloud Console
1. Visit: https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0
2. Find the **Android API key**: `YOUR_FIREBASE_API_KEY` (get from Firebase Console)
3. Click to **Edit**

### Step 2: Check "Application restrictions"
Look for a section called **"Application restrictions"** (NOT "API restrictions")

**If it says "None"**:
- ✅ No restrictions - this is NOT the issue
- Move to next potential cause

**If it says "Android apps"**:
- ⚠️ **THIS IS LIKELY THE ISSUE**
- Check if it includes:
  - Package name: `com.example.familyhub_mvp`
  - SHA-1 certificate: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`

**If SHA-1 is missing or different**:
1. Click "Add an item" or edit
2. Add SHA-1: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`
3. Click **Save**

**OR** temporarily set to "None" to test if this is the issue

## Verify SHA-1 from Your Debug Keystore

To confirm the SHA-1 is correct, get it from your actual keystore:

### Windows:
```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Look for "SHA1:" in the output. It should match: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`

### If SHA-1 is Different:
1. Get the actual SHA-1 from the command above
2. Add it to Firebase Console (Project Settings > Your Apps > Android app)
3. Add it to Google Cloud Console (API key APPLICATION restrictions)
4. Download new `google-services.json` from Firebase
5. Replace `android/app/google-services.json`

## Also Verify in Firebase Console

1. Go to: https://console.firebase.google.com/project/family-hub-71ff0/settings/general
2. Find your Android app
3. Check "SHA certificate fingerprints"
4. Must include: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`
5. If missing, click "Add fingerprint" and add it

## After Fixing

1. **Rebuild**: `flutter clean && flutter pub get && flutter run`
2. **Test login** - should complete in 2-5 seconds
3. **Capture new logcat** if still issues

## Why This Causes Silent Timeout

When APPLICATION restrictions are set but SHA-1 doesn't match:
- The API key is rejected **before** the request reaches Firebase
- No error is returned (silent rejection)
- The SDK waits for a response that never comes
- After 30s, it times out

This is different from API restrictions, which would return an error immediately.

