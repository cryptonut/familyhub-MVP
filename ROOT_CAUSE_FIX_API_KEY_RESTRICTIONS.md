# Root Cause Fix: API Key Restrictions Causing Firestore Unavailable

## Root Cause Identified

The persistent `[cloud_firestore/unavailable]` error with `SecurityException: Unknown calling package name 'com.google.android.gms'` and `ConnectionResult{statusCode=DEVELOPER_ERROR}` indicates that:

**The API key restrictions in Google Cloud Console are blocking Firestore API access.**

## The Problem

1. **Application Restrictions**: The API key has application restrictions that don't match the app's package name + SHA-1 fingerprint
2. **API Restrictions**: The API key might not have "Cloud Firestore API" enabled in its API restrictions list
3. **API Not Enabled**: The Cloud Firestore API might not be enabled for the project in Google Cloud Console

## The Fix (Must Be Done in Google Cloud Console)

### Step 1: Enable Cloud Firestore API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Navigate to **APIs & Services** > **Library**
4. Search for **"Cloud Firestore API"**
5. Click on it and click **ENABLE** (if not already enabled)
6. Wait for activation (usually instant)

### Step 2: Fix API Key Restrictions

The API keys in `google-services.json` are:
- `AIzaSyDnHl...` (first key)
- `AIzaSyDyevPyG6DAvW-0iJw-88ZymBtmkLi8k0M` (second key)

For **dev environment** (`com.example.familyhub_mvp.dev`):

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0)
2. Find the API keys listed above
3. For each API key, click **Edit**:

   **API Restrictions:**
   - Select **"Restrict key"**
   - Under **"API restrictions"**, ensure these are enabled:
     - ✅ **Cloud Firestore API** (CRITICAL)
     - ✅ **Identity Toolkit API** (for Firebase Auth)
     - ✅ **Firebase Authentication API**
     - ✅ **Firebase Installations API**
   - Click **SAVE**

   **Application Restrictions (for dev/testing):**
   - Option A (Recommended for dev): Select **"None"** - no restrictions
   - Option B (Production-like): Select **"Android apps"**
     - Click **"ADD AN ITEM"**
     - Package name: `com.example.familyhub_mvp.dev`
     - SHA-1 certificate fingerprint: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
     - Click **DONE**
   - Click **SAVE**

### Step 3: Verify OAuth Client Configuration

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0)
2. Navigate to **OAuth 2.0 Client IDs**
3. Find the Android client for `com.example.familyhub_mvp.dev`:
   - Client ID: `559662117534-pd7lihihfu9k46l0328bat6vhobs9cc0`
4. Verify:
   - Package name: `com.example.familyhub_mvp.dev`
   - SHA-1: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
5. If SHA-1 doesn't match, update it or add it

### Step 4: Verify OAuth Consent Screen

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials/consent?project=family-hub-71ff0)
2. Ensure OAuth consent screen is configured:
   - App name: Set (any name)
   - User support email: Set
   - Developer contact email: Set
3. Click through all steps and **SAVE**
4. Wait 5-10 minutes for changes to propagate

### Step 5: Wait for Propagation

- API key changes: **1-2 minutes**
- OAuth client changes: **5-10 minutes**
- API enablement: **Usually instant**

### Step 6: Rebuild and Test

```bash
flutter clean
flutter pub get
flutter run --flavor dev
```

## Verification Checklist

After making changes, verify:

- [ ] Cloud Firestore API is enabled in Google Cloud Console
- [ ] API key has "Cloud Firestore API" in API restrictions
- [ ] API key has correct application restrictions (None for dev, or package+SHA-1)
- [ ] OAuth client has correct package name and SHA-1
- [ ] OAuth consent screen is configured
- [ ] Waited 5-10 minutes for changes to propagate
- [ ] Rebuilt app with `flutter clean`

## Expected Result

After fixing:
- ✅ No more `SecurityException: Unknown calling package name`
- ✅ No more `ConnectionResult{statusCode=DEVELOPER_ERROR}`
- ✅ Firestore queries succeed
- ✅ User data loads successfully

## If Still Failing

1. Check logs for the exact API key being used
2. Verify the API key in logs matches the one in Google Cloud Console
3. Double-check SHA-1 fingerprint matches exactly (no spaces, uppercase)
4. Ensure you're testing with the correct flavor (`--flavor dev`)
