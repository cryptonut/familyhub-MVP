# Alternative Fix: Download Fresh google-services.json

Since the app deletion didn't work (still shows "app already exists"), try this simpler approach:

## Option 1: Download Fresh google-services.json from Existing App (Easiest)

1. **Go to Firebase Console:**
   - https://console.firebase.google.com/project/family-hub-71ff0/settings/general

2. **Find Your Android App:**
   - Scroll to "Your apps" section
   - Find the Android app with package `com.example.familyhub_mvp`
   - Click on it or the gear icon

3. **Download google-services.json:**
   - Look for "Download google-services.json" button
   - Click it to download a fresh file
   - This should contain the current API key configuration

4. **Replace the file:**
   - Copy the downloaded file to `android/app/google-services.json`
   - Replace the existing file

5. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run --debug -d RFCT61EGZEH
   ```

## Option 2: Add SHA-1 to Existing App

If you want to ensure SHA-1 is properly registered:

1. Go to the Android app in Firebase settings
2. Click "Add fingerprint" or "Add SHA-1"
3. Get your debug SHA-1:
   ```bash
   keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
4. Copy the SHA-1 fingerprint (the one under "SHA1:")
5. Add it to Firebase
6. Download fresh google-services.json

## Option 3: Wait and Retry Deletion

Sometimes Firebase takes a moment to fully delete:
1. Wait 30-60 seconds
2. Refresh the page
3. Check if app is gone from "Your apps"
4. Then try adding again

## Why This Works

Even without deleting/re-adding, downloading a fresh `google-services.json` from the existing app registration should give you the current API key configuration, which may resolve the issue if the file was stale.

