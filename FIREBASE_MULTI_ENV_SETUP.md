# Firebase Multi-Environment Setup Guide

This guide explains how to set up Firebase for Dev, Test, and Prod environments.

## Overview

Each environment needs its own Firebase app registration within the same Firebase project. This allows:
- Separate app IDs for each environment
- Data isolation (optional, via Firestore prefixes)
- Different tester groups in App Distribution
- Same Firebase project for easier management

## Step-by-Step Setup

### 1. Dev Environment

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Click ⚙️ **Project settings**
4. Scroll to **Your apps** section
5. Click **Add app** → **Android**
6. Register with:
   - **Package name**: `com.example.familyhub_mvp.dev`
   - **App nickname**: FamilyHub Dev (optional)
7. Click **Register app**
8. Download `google-services.json`
9. Place it at: `android/app/src/dev/google-services.json`
10. Copy the **App ID** (format: `1:559662117534:android:XXXXX`)
11. Update `lib/config/dev_config.dart` with the App ID

### 2. QA Environment

1. In Firebase Console → **Project settings** → **Your apps**
2. Click **Add app** → **Android**
3. Register with:
   - **Package name**: `com.example.familyhub_mvp.test` ⚠️ **Must match exactly!**
   - **App nickname**: FamilyHub QA (optional)
4. Click **Register app**
5. Download `google-services.json`
6. Place it at: `android/app/src/qa/google-services.json` ⚠️ **Must be in qa folder!**
7. Copy the **App ID** (format: `1:559662117534:android:XXXXX`)
8. Update `lib/config/qa_config.dart` with the App ID

### 3. Prod Environment

✅ **Already set up!**

- Package name: `com.example.familyhub_mvp`
- App ID: `1:559662117534:android:a59145c8a69587aee7c18f`
- Config file: `android/app/src/prod/google-services.json`

## ⚠️ CRITICAL: Separate Firebase Apps Required

**Each flavor MUST have its own Firebase app registered!**

Firebase App Distribution matches APKs to Firebase apps by package name. If you try to upload a dev APK (`com.example.familyhub_mvp.dev`) to a Firebase app registered for prod (`com.example.familyhub_mvp`), you'll get a package name mismatch error.

**You need 3 separate Firebase apps:**
1. **Dev app**: Package name `com.example.familyhub_mvp.dev`
2. **QA app**: Package name `com.example.familyhub_mvp.test`
3. **Prod app**: Package name `com.example.familyhub_mvp` ✅ (already exists)

Each app will have its own App ID and `google-services.json` file.

## Firebase App Distribution Groups

Create tester groups for each environment:

1. Go to **App Distribution** in Firebase Console
2. Click **Testers & Groups** tab
3. Create groups:
   - `dev-testers` → For developers
   - `qa-testers` → For QA and beta testers
   - `prod-testers` → For final validation

4. Add testers to each group as needed

## Updating Config Files

After getting the App IDs from Firebase:

1. **Dev**: Update `lib/config/dev_config.dart`:
   ```dart
   @override
   String get firebaseAppId => '1:559662117534:android:YOUR_DEV_APP_ID';
   ```

2. **QA**: Update `lib/config/qa_config.dart`:
   ```dart
   @override
   String get firebaseAppId => '1:559662117534:android:YOUR_QA_APP_ID';
   ```

## Verification

After setup, verify each environment:

```powershell
# Build dev
.\build_and_distribute.ps1 dev firebase-manual

# Build QA
.\build_and_distribute.ps1 qa firebase-manual

# Build prod
.\build_and_distribute.ps1 prod firebase-manual
```

Each build should use the correct `google-services.json` and App ID.

## Data Separation (Optional)

If you want separate Firestore data for each environment:

- **Dev**: Collections prefixed with `dev_` (e.g., `dev_families`, `dev_tasks`)
- **QA**: Collections prefixed with `test_` (e.g., `test_families`, `test_tasks`)
- **Prod**: No prefix (e.g., `families`, `tasks`)

The prefixes are configured in:
- `lib/config/dev_config.dart` → `firestorePrefix: 'dev_'`
- `lib/config/qa_config.dart` → `firestorePrefix: 'test_'`
- `lib/config/prod_config.dart` → `firestorePrefix: ''`

Update your Firestore queries to use `Config.current.firestorePrefix` when needed.

## Troubleshooting

### "google-services.json not found"

- Make sure the file is in the correct flavor directory
- Path should be: `android/app/src/{flavor}/google-services.json`

### "App ID mismatch"

- Verify the App ID in `google-services.json` matches the config file
- Check that you're using the correct flavor's `google-services.json`

### "Package name mismatch" (Error shown in screenshot)

**This error means you're trying to upload an APK to the wrong Firebase app.**

**Solution:**
1. Go to Firebase Console → Project settings → Your apps
2. Verify you have 3 separate Android apps registered:
   - Dev: `com.example.familyhub_mvp.dev`
   - QA: `com.example.familyhub_mvp.test`
   - Prod: `com.example.familyhub_mvp`
3. When uploading to App Distribution, make sure you're in the correct app's App Distribution page:
   - For dev APK → Select the **Dev app** in the App Distribution dropdown
   - For QA APK → Select the **QA app** in the App Distribution dropdown
   - For prod APK → Select the **Prod app** in the App Distribution dropdown

**How to switch apps in App Distribution:**
- Look for the app dropdown at the top of the App Distribution page (next to "App Distribution")
- Select the correct app for the flavor you're uploading

**Package names must match exactly:**
- Dev: `com.example.familyhub_mvp.dev`
- QA: `com.example.familyhub_mvp.test`
- Prod: `com.example.familyhub_mvp`

Make sure these match exactly in Firebase Console and `build.gradle.kts`.

