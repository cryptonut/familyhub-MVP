# Fix Auth Error for Dev App

The dev app uses a different package name (`com.example.familyhub_mvp.dev`) and has its own Firebase app. Here's what to check:

## ✅ Checklist

### 1. Verify Dev Firebase App Exists

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Click ⚙️ **Project settings**
4. Scroll to **Your apps** section
5. **Verify you have a dev app registered:**
   - Package name: `com.example.familyhub_mvp.dev`
   - App ID: `1:559662117534:android:7b3b41176f0d550ee7c18f`

**If missing:** Create it (see FIREBASE_MULTI_ENV_SETUP.md)

### 2. Enable Email/Password Authentication for Dev App

**Important:** Each Firebase app needs authentication enabled separately.

1. Go to **Authentication** > **Sign-in method**
2. Ensure **Email/Password** is **ENABLED**
3. This setting applies to ALL apps in the project, so if it's enabled, it works for dev too

### 3. Register SHA-1 Fingerprint for Dev App

**Critical:** The dev app needs its own SHA-1 fingerprint registered.

1. Go to **Project settings** > **Your apps**
2. Click on the **dev app** (`com.example.familyhub_mvp.dev`)
3. Scroll to **SHA certificate fingerprints**
4. **Add your SHA-1 fingerprint:**
   - Get it: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
   - Or use: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C` (if same debug keystore)
5. Click **Save**
6. **Wait 2-3 minutes** for propagation

### 4. Verify google-services.json for Dev

1. Check that `android/app/src/dev/google-services.json` exists
2. Verify it contains:
   - `package_name`: `com.example.familyhub_mvp.dev`
   - `mobilesdk_app_id`: `1:559662117534:android:7b3b41176f0d550ee7c18f`
3. If missing or incorrect, download it from Firebase Console

### 5. Check Firestore Rules (Already OK)

The current Firestore rules should work for dev app. They check:
- `request.auth != null` - Any authenticated user
- No package name restrictions

**No changes needed** unless you want dev-specific data isolation.

### 6. Check API Key Restrictions

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **APIs & Services** > **Credentials**
4. Find your API key: **AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4**
5. Under **Application restrictions**:
   - Either "None" is selected, OR
   - Android apps includes: `com.example.familyhub_mvp.dev`

## 🔍 Most Common Issues

### Issue 1: SHA-1 Not Registered for Dev App
**Symptom:** `DEVELOPER_ERROR` or `ConnectionResult{statusCode=DEVELOPER_ERROR}`

**Fix:** Add SHA-1 fingerprint to dev app in Firebase Console (step 3 above)

### Issue 2: Wrong google-services.json
**Symptom:** Auth works but Firestore fails, or vice versa

**Fix:** Ensure `android/app/src/dev/google-services.json` is for the dev app

### Issue 3: Email/Password Not Enabled
**Symptom:** `auth/operation-not-allowed` error

**Fix:** Enable Email/Password in Firebase Console > Authentication > Sign-in method

## 🧪 Test After Fixing

1. **Clean build:**
   ```powershell
   flutter clean
   flutter pub get
   ```

2. **Build dev flavor:**
   ```powershell
   flutter build apk --release --flavor dev --dart-define=FLAVOR=dev
   ```

3. **Install and test login**

## 📝 Note About Firestore Rules

The current Firestore rules are **shared across all apps** in the project. They work for:
- ✅ Dev app (`com.example.familyhub_mvp.dev`)
- ✅ QA app (`com.example.familyhub_mvp.test`)
- ✅ Prod app (`com.example.familyhub_mvp`)

**No rule changes needed** unless you want separate data isolation per environment.

If you want dev-specific data isolation, you'd need to:
1. Use the `firestorePrefix` from config (`dev_` for dev)
2. Update rules to check prefixes
3. Update all Firestore queries to use prefixes

But for now, **shared rules are fine** - all apps share the same Firestore database.

