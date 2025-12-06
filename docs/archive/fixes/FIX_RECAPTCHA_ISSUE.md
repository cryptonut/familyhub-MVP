# Fix reCAPTCHA Issue - Sign-In Hanging

## Problem
When clicking "Sign In", the app shows a spinning loading wheel and never completes. The logs show:
```
I/FirebaseAuth(19387): Logging in as simoncase78@gmail.com with empty reCAPTCHA token
```

This happens because Firebase Auth requires reCAPTCHA verification on Android, but your app's SHA-1 fingerprint isn't registered in Firebase Console.

## Solution: Register SHA-1 Fingerprint in Firebase

### Your SHA-1 Fingerprint (Already Found!)

Your debug SHA-1 fingerprint is:
```
BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C
```

**Copy this value** - you'll need it in the next step!

### Step 2: Add SHA-1 to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click the gear icon ⚙️ next to "Project Overview"
4. Select **Project settings**
5. Scroll down to **Your apps** section
6. Find your Android app: **com.example.familyhub_mvp**
7. Click **Add fingerprint** (or edit if one exists)
8. Paste your SHA-1 fingerprint (without spaces or colons, or with colons - both work)
9. Click **Save**

### Step 3: Wait and Test

- Wait 1-2 minutes for Firebase to process the change
- Restart your app (close completely and reopen)
- Try signing in again

## Alternative: Disable reCAPTCHA (Not Recommended for Production)

If you need a quick fix for development only:

1. Go to Firebase Console > Authentication > Settings
2. Look for "reCAPTCHA" or "App verification" settings
3. You may be able to disable it for development, but this is **NOT recommended** for production apps

## Why This Happens

Firebase Auth uses reCAPTCHA to prevent abuse. On Android, it requires the app's SHA-1 fingerprint to be registered so Firebase knows the app is legitimate. Without it, Firebase can't verify the app and the sign-in process hangs waiting for reCAPTCHA verification.

## Still Having Issues?

1. Make sure you're using the **debug** SHA-1 for development builds
2. For release builds, you'll need to add the **release** SHA-1 as well
3. Check that the package name matches: `com.example.familyhub_mvp`
4. Wait a few minutes after adding the fingerprint - Firebase needs time to propagate

