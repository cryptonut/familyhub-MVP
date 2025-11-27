# CRITICAL FIX: reCAPTCHA Causing Login Timeout

## Root Cause Identified ✅

**Logcat shows**: `"Logging in as Simoncase78@gmail.com with empty reCAPTCHA token"`

This is causing the 30-second login timeout. Firebase Auth is trying to verify reCAPTCHA but the token is empty, causing the authentication to hang indefinitely.

## Immediate Fix Required

### Option 1: Disable reCAPTCHA in Firebase Console (RECOMMENDED)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Navigate to **Authentication** > **Settings** (gear icon)
4. Scroll to **reCAPTCHA provider** section
5. **DISABLE** reCAPTCHA for email/password authentication
6. Click **Save**

### Option 2: Verify API Key Restrictions

Even with reCAPTCHA disabled, ensure API key allows Identity Toolkit API:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **APIs & Services** > **Credentials**
4. Find API Key: `AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4` (Android key)
5. Click to edit
6. Under **API restrictions**, ensure **Identity Toolkit API** is enabled
7. Click **Save**

## Why This Happens

Firebase Auth on Android uses reCAPTCHA to prevent abuse. When:
- reCAPTCHA is enabled but token generation fails
- Network issues prevent reCAPTCHA verification
- API key restrictions block reCAPTCHA endpoints
- SafetyNet/Play Integrity issues

The authentication hangs waiting for reCAPTCHA verification that never completes.

## After Fixing

1. **Disable reCAPTCHA** in Firebase Console (Authentication > Settings)
2. **Verify API key** allows Identity Toolkit API
3. **Rebuild app**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```
4. **Test login** - should complete in 2-5 seconds (not 30s timeout)

## Expected Result

✅ Login completes quickly (2-5 seconds)
✅ No "empty reCAPTCHA token" in logcat
✅ No 30-second timeout
✅ User successfully authenticates

## If Still Timing Out

Check logcat for:
1. "empty reCAPTCHA token" → reCAPTCHA still enabled
2. "DEVELOPER_ERROR" → OAuth client or SHA-1 mismatch
3. "API key restrictions" → Identity Toolkit API not enabled
4. Network errors → Check network_security_config.xml

## Files Modified

- ✅ `lib/services/auth_service.dart` - Updated error messages to highlight reCAPTCHA issue
- ✅ `android/app/google-services.json` - Already in place with correct config

## Next Steps

1. **Disable reCAPTCHA in Firebase Console** (most important!)
2. Run `flutter clean && flutter pub get && flutter run`
3. Test login - should work immediately

