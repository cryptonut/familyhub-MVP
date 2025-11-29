# Fix Dev App Auth Error - Step by Step

The auth error is likely due to one of these issues. Check them in order:

## ✅ Step 1: Publish Firestore Rules (CRITICAL)

The Firestore rules file is updated locally but **must be published in Firebase Console**.

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Click **Firestore Database** → **Rules** tab
4. Copy the complete rules from `firestore.rules` file
5. Paste into Firebase Console
6. Click **Publish**
7. Wait 1-2 minutes for propagation

**Without this, chess games and other features will fail with permission errors.**

## ✅ Step 2: Add SHA-1 to Dev App

The dev app needs its SHA-1 fingerprint registered.

1. Go to Firebase Console → **Project settings**
2. Find **Dev app**: `com.example.familyhub_mvp.dev`
3. Scroll to **SHA certificate fingerprints**
4. Click **Add fingerprint**
5. Paste: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
6. Click **Save**
7. Wait 2-3 minutes

## ✅ Step 3: Verify google-services.json

Make sure the dev `google-services.json` has the correct package name:

1. Open `android/app/src/dev/google-services.json`
2. Check `package_name` should be: `"com.example.familyhub_mvp.dev"`
3. Check `mobilesdk_app_id` should be: `"1:559662117534:android:7b3b41176f0d550ee7c18f"`

If wrong, download fresh from Firebase Console.

## ✅ Step 4: Clean Rebuild

After making changes:

```powershell
flutter clean
flutter pub get
flutter build apk --release --flavor dev --dart-define=FLAVOR=dev
```

## 🔍 About "Test apps" Screen

The "Test apps" screen you're seeing is **Firebase App Distribution** - it's for distributing APKs to testers, not for authentication.

- **"1 release"** = You've uploaded 1 APK to that app
- **"(pending)"** = The test app needs to accept an invitation or has a pending release

This screen doesn't affect authentication - it's just for APK distribution.

## 🎯 Most Likely Issue

**The Firestore rules haven't been published yet.** Even though the file is updated locally, Firebase Console still has the old rules without chess game permissions.

**Action:** Publish the rules in Firebase Console (Step 1 above).

