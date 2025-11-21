# Regenerate google-services.json Fix

## Issue
The `google-services.json` file may contain an old/restricted API key reference even though the current API key in GCP Console is unrestricted. This is a known Firebase console bug.

## Current API Key
- Key in google-services.json: `AIzaSyDLZ3mdwyumvm_oXPWBAUtANQBSlbFizyk`
- This key should have no restrictions and Cloud Firestore API enabled

## Fix Steps (8 steps)

1. **Go to Firebase Console:**
   - https://console.firebase.google.com/project/family-hub-71ff0/settings/general

2. **Delete Android App:**
   - Scroll to "Your apps" section
   - Find your Android app (`com.example.familyhub_mvp`)
   - Click the three-dot menu (⋮) next to it
   - Click "Delete app"
   - ⚠️ **Don't panic** - this only removes the registration, NOT your data

3. **Re-add Android App:**
   - Click "Add app" → "Android" (or the Android icon)

4. **Enter Package Name:**
   - Package name: `com.example.familyhub_mvp`
   - Click "Register app"

5. **Add SHA-1 (if prompted):**
   - If it asks for SHA-1, you can add your debug SHA-1 or skip and add later
   - To get SHA-1: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`

6. **Download google-services.json:**
   - Click "Download google-services.json"
   - Save the file

7. **Replace Old File:**
   - Copy the new `google-services.json` to `android/app/`
   - Replace the existing file

8. **Clean and Rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run --debug -d RFCT61EGZEH
   ```

## Expected Result
Firebase will generate a fresh `google-services.json` with the correct unrestricted Android API key reference, and the `[cloud_firestore/unavailable]` error should disappear.

## Note
This addresses the Firebase console bug where `google-services.json` doesn't update when API key restrictions are changed after initial generation.

