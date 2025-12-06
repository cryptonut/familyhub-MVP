# Fix Login Timeout Issue

## Problem
Login request is timing out after 30 seconds. This is typically caused by Firebase reCAPTCHA being enabled but not working properly.

## Quick Fix Steps

### Step 1: Disable reCAPTCHA in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication** → **Settings** (gear icon at top right)
4. Scroll down to **reCAPTCHA provider** section
5. **DISABLE** reCAPTCHA for email/password authentication
6. Click **Save**
7. **Wait 1-2 minutes** for changes to propagate

### Step 2: Verify API Key Restrictions

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Navigate to **APIs & Services** → **Credentials**
4. Find your **Android API key** (the one used in `google-services.json`)
5. Click on it to edit
6. Under **API restrictions**, ensure these are enabled:
   - ✅ **Identity Toolkit API**
   - ✅ **Firebase Installations API**
   - ✅ **Firebase Cloud Messaging API**
7. Under **Application restrictions**, ensure your Android app is allowed:
   - Package name: `com.example.familyhub_mvp.dev` (for dev flavor)
   - SHA-1 fingerprint: (your app's SHA-1)

### Step 3: Check Network Connectivity

- Ensure your device has a stable internet connection
- Try switching between WiFi and mobile data
- Check if corporate/school networks are blocking Firebase endpoints

### Step 4: Verify OAuth Client Configuration

1. In Firebase Console → **Authentication** → **Settings**
2. Scroll to **Authorized domains**
3. Ensure your domain is listed (for web, if applicable)
4. For Android, verify `google-services.json` has correct OAuth client ID

### Step 5: Rebuild and Test

After making changes:

```bash
flutter clean
flutter pub get
flutter run --flavor dev --dart-define=FLAVOR=dev
```

## Alternative: Increase Timeout (Temporary Workaround)

If you need a temporary workaround while fixing reCAPTCHA, you can increase the timeout:

**File:** `lib/core/constants/app_constants.dart`

```dart
static const Duration authOperationTimeout = Duration(seconds: 60); // Increased from 30
```

**Note:** This is NOT a fix - it just gives more time. The root cause (reCAPTCHA) still needs to be addressed.

## Check Logcat for Detailed Errors

To see the exact error:

```bash
adb logcat | grep -i "recaptcha\|firebase\|auth"
```

Look for:
- `"empty reCAPTCHA token"` - This confirms reCAPTCHA is the issue
- `"Network request failed"` - Network connectivity issue
- `"API key not valid"` - API key restriction issue

## Most Common Cause

**90% of login timeouts are caused by reCAPTCHA being enabled but not properly configured.**

The fix is almost always:
1. Disable reCAPTCHA in Firebase Console
2. Wait 1-2 minutes
3. Try again

## Still Not Working?

If disabling reCAPTCHA doesn't work, check:

1. **Firebase Project Settings**
   - Verify you're using the correct Firebase project
   - Check `google-services.json` matches your project

2. **API Key Restrictions**
   - Ensure "Identity Toolkit API" is enabled
   - Check application restrictions allow your app

3. **Network/Firewall**
   - Corporate networks may block Firebase
   - Try from a different network

4. **App Configuration**
   - Verify `google-services.json` is in `android/app/`
   - Check package name matches Firebase configuration

## Need Help?

If the issue persists after following these steps:
1. Check logcat output for specific error messages
2. Verify Firebase Console settings match this guide
3. Test with a different Firebase project to isolate the issue

