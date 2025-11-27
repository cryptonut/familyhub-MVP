# Real Issue Diagnosis - Login Timeout

## What We Know
- ✅ reCAPTCHA is disabled
- ✅ Identity Toolkit API is enabled
- ❌ Login still times out after 30s
- ❌ No error returned, just silence

## The Real Problem

When `signInWithEmailAndPassword` is called but **never returns** (not even an error), it means the request is being **blocked or rejected silently** before reaching Firebase servers.

## Most Likely Causes (in order)

### 1. API Key APPLICATION Restrictions (NOT API Restrictions)
**This is different from API restrictions!**

The API key has TWO types of restrictions:
- **API restrictions**: Which APIs can be called (Identity Toolkit API)
- **APPLICATION restrictions**: Which apps can use the key (based on package name + SHA-1)

**Check this**:
1. Go to [Google Cloud Console Credentials](https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0)
2. Find the **Android API key**: `AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4`
3. Click to **Edit**
4. Look for **"Application restrictions"** section (NOT "API restrictions")
5. If it says **"Android apps"** with restrictions:
   - Must include package name: `com.example.familyhub_mvp`
   - Must include SHA-1: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`
6. If SHA-1 is missing or wrong, **ADD IT** or change to "Don't restrict"

**If APPLICATION restrictions are set but SHA-1 doesn't match, the key is silently rejected!**

### 2. OAuth Client Configuration Issue
Check Firebase Console > Project Settings > Your Apps > Android app:
- Package name: `com.example.familyhub_mvp`
- SHA-1: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`

If SHA-1 doesn't match, add it in Firebase Console.

### 3. google-services.json Not Included in Build
Even though the file exists, it might not be included in the build.

**Verify**:
```bash
flutter clean
flutter build apk --debug
```

Then check if `google-services.json` was processed:
- Look in `android/app/build/intermediates/merged_res/debug/values/values.xml`
- Should contain Firebase configuration

### 4. Network/Firewall Blocking
Less likely, but check if device can reach:
- `identitytoolkit.googleapis.com`
- `firebase.googleapis.com`

## Action Items

1. **Check API key APPLICATION restrictions** (most important!)
2. **Verify SHA-1 in Firebase Console** matches `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`
3. **Rebuild**: `flutter clean && flutter pub get && flutter run`
4. **Capture new logcat** after testing
5. **Check if google-services.json is in the built APK**

## How to Get SHA-1 from Device

If you need to verify the actual SHA-1 from the device:
```bash
# Debug keystore (default)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Or from running app
adb logcat | grep "SHA-1"
```

## Expected Fix

After fixing APPLICATION restrictions or SHA-1 mismatch, login should complete in 2-5 seconds instead of timing out.

