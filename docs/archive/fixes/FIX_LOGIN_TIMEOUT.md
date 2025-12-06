# Fix Login Timeout Issue

## Problem
Firebase Auth sign-in is timing out after 15-30 seconds. The logs show:
- `AuthService: Calling Firebase signInWithEmailAndPassword...`
- `FirebaseAuth: Logging in as [email] with empty reCAPTCHA token`
- Then nothing for 30 seconds
- `=== AUTH SERVICE: SIGN IN TIMEOUT ===`

This indicates Firebase Auth is being called but never returns - a **Firebase configuration or network issue**.

## Solution: Check Firebase Console Settings

### 1. Disable App Check Enforcement (CRITICAL)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Go to **Build** > **App Check** (or search for "App Check")
4. Click on your Android app: **com.example.familyhub_mvp**
5. **Disable enforcement** for:
   - Firebase Authentication
   - Cloud Firestore
6. Click **Save**

**Why:** App Check enforcement blocks requests without valid tokens. Even with debug provider, enforcement can cause timeouts.

### 2. Verify Email/Password Authentication is Enabled

1. Go to **Authentication** > **Sign-in method**
2. Ensure **Email/Password** is **ENABLED**
3. If disabled, click it and toggle **Enable**

### 3. Check API Key Restrictions

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **APIs & Services** > **Credentials**
4. Find your API key: **AIzaSyDLZ3mdwyumvm_oXPWBAUtANQBSlbFizyk**
5. Click on it
6. Under **API restrictions**, ensure:
   - Either "Don't restrict key" is selected, OR
   - "Restrict key" includes:
     - Firebase Authentication API
     - Cloud Firestore API
     - Identity Toolkit API
7. Under **Application restrictions**, ensure:
   - Either "None" is selected, OR
   - Android apps includes your package: **com.example.familyhub_mvp**

### 4. Check Network Connectivity

1. Ensure device/emulator has internet access
2. Try accessing Firebase Console from the device browser
3. Check if other apps can access internet

### 5. Test with Firebase Console

1. Go to Firebase Console > Authentication > Users
2. Try to manually create a test user
3. If this fails, there's a Firebase project issue

## Quick Test

After making changes:
1. Restart the app completely
2. Try logging in again
3. Check logs for:
   - `✓ Firebase App Check initialized` (should appear)
   - `AuthService: Attempt 1/3...` (retry attempts)
   - `=== AUTH SERVICE: SIGN IN SUCCESS ===` (success)

## If Still Failing

The code now includes:
- ✅ Retry logic (3 attempts with exponential backoff)
- ✅ Shorter timeouts (15 seconds per attempt)
- ✅ Detailed error messages
- ✅ App Check initialization

If it still times out after checking all Firebase Console settings, the issue is likely:
- Network connectivity (device can't reach Firebase servers)
- Firewall/proxy blocking Firebase
- Firebase project configuration issue

Try:
1. Different network (WiFi vs mobile data)
2. Different device/emulator
3. Check if Firebase services are down: https://status.firebase.google.com/

