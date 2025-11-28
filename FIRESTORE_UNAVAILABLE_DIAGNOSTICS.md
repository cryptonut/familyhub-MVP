# Firestore "Service Unavailable" Error Diagnostics

## Enhanced Error Logging

I've added enhanced error logging to help diagnose Firestore unavailable errors:

### What's New

1. **Detailed Error Information in `getCurrentUserModel()`:**
   - Logs error code, type, and full stack trace
   - Identifies possible causes of unavailable errors
   - Shows retry attempt numbers
   - On retry after unavailable error, forces server source to bypass cache

2. **Firestore Initialization Logging:**
   - Logs Firestore settings configuration
   - Shows API key being used (first 10 chars)
   - Displays project ID and app name
   - Reminds to verify Firestore API is enabled

### How to Read the Logs

When you see "service unavailable" errors, look for:

```
getCurrentUserModel: Firestore error (attempt X/3):
  Error: [cloud_firestore/unavailable] The service is currently unavailable
  Error code: unavailable
  Error type: FirebaseException
getCurrentUserModel: ⚠ Firestore unavailable error detected
  Possible causes:
    - API key restrictions blocking Firestore API
    - Firestore API not enabled in Google Cloud Console
    - Network connectivity issues
    - App Check enforcement blocking requests
    - Firestore service temporarily down
```

### Common Causes & Solutions

#### 1. API Key Restrictions
**Symptoms:** Unavailable errors on Android, Chrome works fine
**Solution:**
- Go to Google Cloud Console > APIs & Services > Credentials
- Find key: `YOUR_FIREBASE_API_KEY` (from google-services.json)
- Check "Application restrictions":
  - For dev: Set to "None"
  - For prod: Add Android package `com.example.familyhub_mvp` + SHA-1
- Under "API restrictions", ensure "Cloud Firestore API" is enabled
- Save and wait 1-2 minutes for propagation

#### 2. Firestore API Not Enabled
**Symptoms:** Consistent unavailable errors
**Solution:**
- Go to Google Cloud Console > APIs & Services > Library
- Search for "Cloud Firestore API"
- Click "Enable" if not already enabled
- Wait for activation

#### 3. App Check Enforcement
**Symptoms:** Unavailable after enabling App Check
**Solution:**
- Check if App Check is enforced in Firebase Console
- For development, use debug tokens
- Or temporarily disable App Check enforcement
- See `lib/main.dart` - App Check is currently disabled

#### 4. Network/Cache Issues
**Symptoms:** Intermittent unavailable, works after retry
**Solution:**
- The code now forces server source on retry to bypass cache
- Check device network connectivity
- Try clearing app data and reinstalling

### Retry Logic

The `getCurrentUserModel()` function now:
1. **First attempt:** Uses default behavior (cache first, then server)
2. **Retry attempts:** If unavailable error, forces `Source.server` to bypass cache
3. **Max retries:** 3 attempts with increasing delays (1s, 2s, 3s)
4. **Detailed logging:** Each attempt logs full error details

### What to Check in Logs

Look for these patterns:

```
✓ Firebase initialized successfully
✓ Firestore settings configured
  - API Key: AIzaSyDnHl... (Android key)
  - NOTE: Verify this key has Firestore API enabled
```

If you see unavailable errors after this, check:
1. Is the API key correct? (should match google-services.json)
2. Are API restrictions blocking Firestore?
3. Is Cloud Firestore API enabled in Google Cloud Console?
4. Is there a network issue on the device?

### Next Steps

1. **Run the app and watch logs:**
   ```bash
   flutter run --debug -d <android-device>
   ```

2. **Look for the enhanced error messages** showing:
   - Exact error code
   - Retry attempts
   - Whether it's forcing server source

3. **Share the logs** if issues persist, including:
   - Firebase initialization messages
   - getCurrentUserModel error details
   - Error codes and types

The enhanced logging should help pinpoint exactly why Firestore is unavailable.

