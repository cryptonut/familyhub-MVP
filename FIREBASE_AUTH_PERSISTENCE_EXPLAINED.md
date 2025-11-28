# Firebase Auth Persistence - Why You're Logged In Automatically

## The Key Insight

You noticed the app took you straight to the dashboard without login. This is actually **expected behavior** and reveals important information about the Firestore errors.

## How Firebase Auth Persistence Works

### 1. **Firebase Auth Stores Session Locally**
- When you log in, Firebase Auth stores your authentication token **locally on the device**
- This token is stored in secure storage (Android: SharedPreferences/KeyStore)
- The token persists across app restarts, uninstalls (sometimes), and device reboots
- This is **separate from Firestore** - it's just authentication state

### 2. **App Startup Flow**
```
App Starts
    ↓
Firebase Auth checks for persisted session
    ↓
Finds valid token → User is "logged in" from Auth perspective
    ↓
AuthWrapper sees user in authStateChanges stream
    ↓
Shows HomeScreen (dashboard) immediately
    ↓
Dashboard tries to load user data from Firestore
    ↓
Firestore calls fail with "unavailable" ❌
```

### 3. **Why This Matters for Firestore Errors**

The fact that you're automatically logged in tells us:

✅ **Firebase Auth is working** - The API key allows authentication
✅ **Session persistence is working** - Token is stored and restored
❌ **Firestore is failing** - But user data can't be loaded

This suggests:
- The Android API key (`YOUR_FIREBASE_API_KEY`) works for **Firebase Auth**
- But it's **blocked for Firestore** API calls
- Or Firestore API is not enabled for this key

## The Clue

The "service unavailable" errors happen when:
1. App starts with persisted Auth session
2. Dashboard loads and calls `getCurrentUserModel()`
3. `getCurrentUserModel()` tries to read from Firestore
4. Firestore returns "unavailable" because:
   - API key restrictions block Firestore API
   - Firestore API not enabled in Google Cloud Console
   - Network issues
   - App Check blocking (though it's disabled)

## What to Check

Since Auth works but Firestore doesn't:

### 1. Check API Key Restrictions
Go to Google Cloud Console > APIs & Services > Credentials
Find key: `YOUR_FIREBASE_API_KEY`

**Under "API restrictions":**
- Must include "Cloud Firestore API" (not just Identity Toolkit)
- Identity Toolkit API is for Auth
- Cloud Firestore API is for Firestore
- Both need to be enabled!

### 2. Check Application Restrictions
**Under "Application restrictions":**
- Should be "None" for development
- Or "Android apps" with package `com.example.familyhub_mvp` + SHA-1
- HTTP referrer restrictions will block Android

### 3. Verify Firestore API is Enabled
Go to Google Cloud Console > APIs & Services > Library
Search for "Cloud Firestore API"
Click "Enable" if not already enabled

## Enhanced Logging Added

I've added logging to show this flow:

```
AuthWrapper: User found - <uid>
AuthWrapper: Firebase Auth session persisted (user automatically logged in)
AuthWrapper: Email: <email>
AuthWrapper: Now attempting to load user data from Firestore...
getCurrentUserModel: Firebase Auth user exists: <uid> (<email>)
getCurrentUserModel: Attempting to load user document from Firestore...
getCurrentUserModel: Firestore error (attempt X/3): [cloud_firestore/unavailable]
```

This will help you see:
1. When Auth session is restored
2. When Firestore calls start
3. Exactly when/why Firestore fails

## Solution

The API key needs **both** APIs enabled:
- ✅ Identity Toolkit API (for Auth - already working)
- ❌ Cloud Firestore API (for Firestore - needs to be enabled)

Update the API key restrictions to include Cloud Firestore API, and the "unavailable" errors should disappear.

