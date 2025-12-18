# Final Action Plan - Login Fix

## ✅ Completed
1. **reCAPTCHA disabled** in Firebase Console
2. **google-services.json** restored to `android/app/`
3. **Build cleaned** - ready for fresh rebuild
4. **Error messages** updated with better diagnostics

## ⚠️ CRITICAL: Verify API Key Restrictions

**This is the most likely remaining issue if login still times out.**

### Check API Key: `YOUR_FIREBASE_API_KEY`

**Direct Link**: https://console.cloud.google.com/apis/credentials/key/9051bc3a-7e93-4179-8f3f-00e62f7ef924?project=family-hub-71ff0

**Steps**:
1. Go to the link above (or navigate manually)
2. Look for **"API restrictions"** section
3. Must have **"Restrict key"** selected (not "Don't restrict key")
4. In the API list, **MUST include**:
   - ✅ **Identity Toolkit API** (CRITICAL for login)
   - ✅ Cloud Firestore API
   - ✅ Other Firebase APIs
5. If "Identity Toolkit API" is missing, **ADD IT**
6. Click **Save**

### Why This Matters

If the API key is restricted but doesn't include "Identity Toolkit API", Firebase Auth cannot authenticate users, causing the 30-second timeout.

## Rebuild and Test

```bash
flutter pub get
flutter run
```

## Expected Result

✅ Login completes in 2-5 seconds
✅ No timeout
✅ User successfully authenticates

## If Still Timing Out

Capture a new logcat after testing:
```bash
adb logcat -d > new-test-after-fixes.logcat
```

Then check the logcat for:
1. Any new error messages
2. API key restriction errors
3. Network errors
4. OAuth client errors

## Summary

- ✅ reCAPTCHA: DISABLED
- ⚠️ API Key: **VERIFY Identity Toolkit API is enabled**
- ✅ google-services.json: In place
- ✅ Build: Cleaned and ready

**Next**: Verify API key restrictions, then rebuild and test!

