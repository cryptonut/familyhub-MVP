# App Errors Analysis - Permission Denied & Developer Error
**Date:** December 12, 2025

## Errors Identified from Logs

### 1. Permission Denied Error
```
DEBUG [AuthService] Error code: permission-denied
```

**Root Cause:** Firestore security rules are checking `users/{userId}` but the app is accessing `dev_users/{userId}` (prefixed collection).

**Issue:** Firestore rules are static and match exact collection paths. With the `firestorePrefix` implementation, the app now uses:
- Dev: `dev_users`, `dev_families`
- QA: `test_users`, `test_families`  
- Prod: `users`, `families`

But the rules only match `users` and `families`.

### 2. Developer Error (GoogleApiManager)
```
DEVELOPER_ERROR: Unknown calling package name 'com.google.android.gms'
```

**Root Cause:** Google Play Services configuration issue, likely related to:
- SHA-1 certificate mismatch
- Package name mismatch in `google-services.json`
- OAuth client configuration issue

### 3. Calendar Service Warning
```
WARNING [CalendarService] getEvents: User not part of a family
```

**Root Cause:** User document exists but `familyId` is null or missing. This is expected if:
- User just logged in and hasn't joined/created a family
- User data migration didn't preserve `familyId`

## Solutions

### Fix 1: Update Firestore Rules for Prefixed Collections

Firestore rules need to match ALL possible collection paths. Since rules are static, we have two options:

**Option A: Add rules for each prefixed collection (Recommended)**
```javascript
// Users collection - handle both prefixed and unprefixed
match /users/{userId} {
  // ... existing rules ...
}

match /dev_users/{userId} {
  // Same rules as users
  allow read: if isAuthenticated() && request.auth.uid == userId;
  allow read: if isAuthenticated();
  allow write: if isAuthenticated() && request.auth.uid == userId;
  // ... etc
}

match /test_users/{userId} {
  // Same rules as users
  // ... same rules ...
}
```

**Option B: Use wildcard pattern (if supported)**
- Firestore rules don't support wildcards for collection names
- Must explicitly match each collection path

### Fix 2: Google Play Services Configuration

1. **Check SHA-1 Certificate:**
   ```bash
   keytool -list -v -keystore android/app/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

2. **Verify in Firebase Console:**
   - Go to Project Settings → Your Apps → Android App
   - Ensure SHA-1 is added
   - Ensure package name matches: `com.example.familyhub_mvp.dev`

3. **Check google-services.json:**
   - Verify package name matches
   - Verify it's the correct flavor file (`android/app/src/dev/google-services.json`)

### Fix 3: User Family ID Issue

The user not being part of a family is expected if they haven't joined/created one yet. However, we should:
- Ensure migration preserves `familyId` if it exists
- Handle null `familyId` gracefully in CalendarService

## Immediate Actions

1. **Update Firestore Rules** - Add rules for `dev_users` and `test_users` collections
2. **Verify Google Services Config** - Check SHA-1 and package name
3. **Test Login** - After rules are updated, test login flow

