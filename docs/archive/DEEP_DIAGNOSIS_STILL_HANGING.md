# Deep Diagnosis - Still Hanging After Rebuild

## Current Status
- ✅ OAuth clients in google-services.json (2 clients)
- ✅ flutter clean and rebuild completed
- ✅ API key restrictions checked
- ❌ **Still timing out/hanging**

## Critical Checks Needed

### 1. Verify SHA-1 Fingerprint Matches

The OAuth client in google-services.json has SHA-1: `bb7a6a5f57f1dd0ded142a5c6f2614fd54c3c71c`

**Get your app's actual SHA-1:**
```powershell
# Method 1: From debug keystore
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# Method 2: From Gradle
cd android
./gradlew signingReport
```

**If SHA-1 doesn't match:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. APIs & Services > Credentials > OAuth 2.0 Client IDs
3. Find Android client or create new one
4. Add correct SHA-1 fingerprint
5. Re-download google-services.json from Firebase Console
6. Replace android/app/google-services.json
7. Run `flutter clean && flutter run` again

### 2. Verify OAuth Consent Screen is Configured

**CRITICAL**: OAuth clients won't work without consent screen configured.

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. **APIs & Services > OAuth consent screen**
3. Must be configured (even for internal/testing)
4. Required fields:
   - App name
   - User support email
   - Developer contact email
5. Click **Save and Continue** through all steps
6. Wait 5-10 minutes for changes to propagate

### 3. Check if google-services.json is Being Processed

Verify Gradle processed the file:
```powershell
# Check if processed
Test-Path "android\app\build\generated\res\google-services\debug\values\values.xml"

# If exists, check content
Get-Content "android\app\build\generated\res\google-services\debug\values\values.xml" | Select-String "oauth"
```

If OAuth not in processed file, Gradle didn't pick up the changes.

### 4. Verify Firebase Auth is Enabled

1. [Firebase Console](https://console.firebase.google.com/)
2. Project: **family-hub-71ff0**
3. **Authentication > Sign-in method**
4. **Email/Password** must be **Enabled**
5. If not enabled, enable it and save

### 5. Check App Check (May Block Requests)

1. Firebase Console > **App Check**
2. If enforcement is ON, temporarily disable for testing
3. Or add debug token for development

### 6. Verify API Key Has Correct Restrictions

Even if you checked, verify again:

1. [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Find: `YOUR_FIREBASE_API_KEY`
3. **API restrictions** must include:
   - ✅ **Identity Toolkit API** (CRITICAL)
   - ✅ **Firebase Authentication API**
4. **Application restrictions**:
   - Either "None" for testing
   - OR "Android apps" with correct package + SHA-1

### 7. Network/Firewall Issues

Check if device can reach Firebase:
```powershell
# Test connectivity
adb shell ping -c 3 identitytoolkit.googleapis.com
adb shell ping -c 3 securetoken.googleapis.com
```

### 8. Re-download google-services.json

Sometimes Firebase needs to regenerate with latest OAuth clients:

1. [Firebase Console](https://console.firebase.google.com/)
2. Project Settings > Your apps > Android
3. Click **Download google-services.json**
4. **Replace** android/app/google-services.json
5. Verify OAuth clients are still there
6. Run `flutter clean && flutter run`

### 9. Check Latest Logcat for Specific Errors

Capture new logcat during login attempt and look for:
- Specific Firebase error codes
- Network errors
- OAuth-related errors
- Any error before the timeout

## Most Likely Remaining Causes

1. **SHA-1 mismatch** - OAuth client SHA-1 doesn't match app's SHA-1
2. **OAuth consent screen not configured** - Required for OAuth to work
3. **API key still restricted** - Identity Toolkit API not enabled
4. **App Check blocking** - Enforcement enabled
5. **Network issue** - Device can't reach Firebase endpoints

## Next Steps

1. **Get SHA-1** and verify it matches OAuth client
2. **Check OAuth consent screen** is configured
3. **Capture new logcat** during login attempt
4. **Verify API key** has Identity Toolkit API enabled
5. **Check App Check** settings

## Quick Test Commands

```powershell
# Get SHA-1
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | Select-String "SHA1"

# Check if google-services processed
Test-Path "android\app\build\generated\res\google-services\debug\values\values.xml"

# Uninstall and reinstall
& 'C:\Users\simon\AppData\Local\Android\Sdk\platform-tools\adb.exe' uninstall com.example.familyhub_mvp
flutter run
```

