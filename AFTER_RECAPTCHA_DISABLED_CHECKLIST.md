# After reCAPTCHA Disabled - Verification Checklist

## ✅ reCAPTCHA is Now Disabled

Good! You've disabled reCAPTCHA in Firebase Console. Now let's verify everything else is correct.

## If Login Still Times Out

Check these in order:

### 1. API Key Restrictions (MOST LIKELY ISSUE)

**Go to Google Cloud Console**:
1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Navigate to **APIs & Services** → **Credentials**
4. Find the **Android API key**: `AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4`
5. Click to **Edit**
6. Under **API restrictions**:
   - Must have **"Restrict key"** selected
   - Must include **"Identity Toolkit API"** in the list
   - Must include **"Cloud Firestore API"**
   - Should include Firebase-related APIs
7. Click **Save**

**If "Identity Toolkit API" is missing**, that's why login times out!

### 2. Verify google-services.json is in Build

Run a build and check:
```bash
flutter clean
flutter build apk --debug
```

Then verify the file was processed:
- Check `android/app/build/intermediates/merged_res/debug/values/values.xml`
- Should contain Firebase configuration

### 3. Check Latest Logcat

After disabling reCAPTCHA, capture a new logcat:
```bash
adb logcat -d > new-logcat-after-recaptcha.logcat
```

Look for:
- ✅ No "empty reCAPTCHA token" message
- ✅ Firebase Auth actually attempting connection
- ❌ Any new error messages
- ❌ API key restriction errors
- ❌ Network errors

### 4. Verify OAuth Client

In Google Cloud Console → Credentials → OAuth 2.0 Client IDs:
- Find Android client: `559662117534-2g5q5vot1gkodl6r1gstpu6prik7mivl`
- Verify package name: `com.example.familyhub_mvp`
- Verify SHA-1: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`

### 5. Test Network Connectivity

The app should be able to reach:
- `identitytoolkit.googleapis.com`
- `firebase.googleapis.com`
- `googleapis.com`

Check `android/app/src/main/res/xml/network_security_config.xml` - already configured ✅

## Expected Behavior After reCAPTCHA Disabled

✅ Login completes in 2-5 seconds
✅ No "empty reCAPTCHA token" in logcat
✅ Firebase Auth responds immediately
✅ User successfully authenticates

## If Still Timing Out

Most likely remaining cause: **API key restrictions blocking Identity Toolkit API**

Check the API key in Google Cloud Console and ensure "Identity Toolkit API" is enabled in the restrictions list.

## Quick Test

Run this to test immediately:
```bash
flutter clean
flutter pub get
flutter run
```

Then try logging in and capture a new logcat to see what's happening now that reCAPTCHA is disabled.

