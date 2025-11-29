# Fix: Package Name Mismatch Error

## The Problem

You're trying to upload a **dev APK** (`com.example.familyhub_mvp.dev`) to Firebase App Distribution, but you're currently viewing the **prod app's** App Distribution page (which is registered for `com.example.familyhub_mvp`).

## Quick Fix (2 Options)

### Option 1: Create Dev Firebase App (Recommended)

This allows you to have separate App Distribution pages for each environment.

1. **Create Dev Firebase App:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select project: **family-hub-71ff0**
   - Click ⚙️ **Project settings**
   - Scroll to **Your apps** section
   - Click **Add app** → **Android**
   - Register with:
     - **Package name**: `com.example.familyhub_mvp.dev` ⚠️ **Must match exactly!**
     - **App nickname**: FamilyHub Dev
   - Click **Register app**
   - Download `google-services.json`
   - Place it at: `android/app/src/dev/google-services.json` (replace existing if needed)
   - Copy the **App ID** (format: `1:559662117534:android:XXXXX`)
   - Update `lib/config/dev_config.dart` with the new App ID

2. **Upload to Dev App Distribution:**
   - In Firebase Console, go to **App Distribution**
   - Look for the app dropdown at the top (next to "App Distribution")
   - Select **FamilyHub Dev** (or the dev app you just created)
   - Now upload your dev APK - it should work!

### Option 2: Upload to Correct App (If Dev App Already Exists)

If you already created the dev Firebase app:

1. In Firebase Console → **App Distribution**
2. Look for the app dropdown at the top (next to "App Distribution")
3. Select **FamilyHub Dev** (or the app with package name `com.example.familyhub_mvp.dev`)
4. Upload your dev APK

## Verify You Have All 3 Apps

Check Firebase Console → Project settings → Your apps:

- ✅ **Dev**: `com.example.familyhub_mvp.dev`
- ✅ **QA**: `com.example.familyhub_mvp.test` (create if missing)
- ✅ **Prod**: `com.example.familyhub_mvp` (already exists)

## After Fixing

Once you have all 3 apps set up:

- **Dev APK** → Upload to **Dev app's** App Distribution
- **QA APK** → Upload to **QA app's** App Distribution  
- **Prod APK** → Upload to **Prod app's** App Distribution

Each app has its own App Distribution page, tester groups, and releases.

