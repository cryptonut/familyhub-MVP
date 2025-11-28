# Test Firebase Auth with Timeout Fix

## What Was Fixed

I've added a **30-second timeout** to the Firebase `signInWithEmailAndPassword` call in `lib/services/auth_service.dart` to prevent indefinite hanging.

### Changes Made:
1. ✅ Added 30-second timeout wrapper to `signInWithEmailAndPassword`
2. ✅ Added periodic logging every 5 seconds to show progress
3. ✅ Enhanced error messages with specific troubleshooting steps
4. ✅ Better diagnostics for API key and configuration issues

## Your Current Configuration (from Google Cloud Console)

Based on the screenshots you shared:

✅ **API Key**: `YOUR_FIREBASE_API_KEY`
✅ **Application Restrictions**: Android apps
✅ **Package Name**: `com.example.familyhub_mvp` with SHA-1 registered
✅ **API Restrictions**: 24 APIs enabled, including **Identity Toolkit API** (critical for Firebase Auth)
⚠️ **OAuth 2.0 Client IDs**: None (empty - may need to check if this causes issues)

## How to Test

1. **Rebuild and run the app**:
   ```bash
   flutter clean
   flutter pub get
   flutter run --debug
   ```

2. **Try to sign in** with `lillycase08@gmail.com`

3. **Watch the logs** - you should now see:
   - `AuthService: Calling Firebase signInWithEmailAndPassword with 30s timeout...`
   - Every 5 seconds: `AuthService: Still waiting for Firebase response... (Xs elapsed)`
   - After 15 seconds: `AuthService: ⚠ This is taking longer than expected`
   - Either success or timeout after 30 seconds with detailed error message

## If It Still Times Out

Check these in order:

### 1. App Check Enforcement (Most Likely Issue)
Go to [Firebase Console > App Check](https://console.firebase.google.com/project/family-hub-71ff0/appcheck)
- Find your Android app: `com.example.familyhub_mvp`
- **Disable enforcement** for Firebase Authentication (toggle OFF)
- Wait 1-2 minutes for changes to propagate
- Try again

### 2. Verify Email/Password is Enabled
Go to [Firebase Console > Authentication > Sign-in method](https://console.firebase.google.com/project/family-hub-71ff0/authentication/providers)
- Ensure **Email/Password** is **Enabled**
- If not, enable it and save

### 3. Check OAuth Clients (If Still Failing)
The empty OAuth clients might be an issue. To fix:
1. Go to [Google Cloud Console > APIs & Services > Credentials](https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0)
2. Click **+ Create Credentials** > **OAuth client ID**
3. Select **Android** as application type
4. Enter package name: `com.example.familyhub_mvp`
5. Enter SHA-1 fingerprint (same one registered in API key)
6. Create and download fresh `google-services.json`
7. Replace `android/app/google-services.json`
8. Rebuild app

### 4. Network/Firewall Issues
- Try different network (WiFi vs mobile data)
- Check if device/emulator can reach `firebase.googleapis.com`
- Try on a different device/emulator

## Expected Log Output

**If working:**
```
AuthService: ✓ Firebase Auth succeeded in XXXms
=== AUTH SERVICE: SIGN IN SUCCESS ===
```

**If timing out:**
```
AuthService: Still waiting for Firebase response... (5s elapsed)
AuthService: Still waiting for Firebase response... (10s elapsed)
AuthService: Still waiting for Firebase response... (15s elapsed)
AuthService: ⚠ This is taking longer than expected
=== AUTH SERVICE: SIGN IN TIMEOUT ===
AuthService: Timeout after 30s
AuthService: This usually indicates:
  1. API key restrictions blocking Firebase Authentication API
  2. Missing or incorrect OAuth client in google-services.json
  3. Network/firewall blocking Firebase endpoints
  4. Firebase Auth service issue
```

## Next Steps After Testing

Share the new logs with me so I can see:
1. Whether the timeout is triggered (30s)
2. What the periodic logs show
3. Any specific error messages
4. Whether it succeeds or fails

This will help identify the exact issue.

