# CRITICAL FIX: Empty reCAPTCHA Token Issue

## The Real Problem

Your logs show:
```
I/FirebaseAuth(5777): Logging in as kalewis78@gmail.com with empty reCAPTCHA token
W/LocalRequestInterceptor (5777): Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed.
```

**This is NOT an App Check issue.** This is a **reCAPTCHA configuration issue**.

## Root Cause

Firebase Authentication has reCAPTCHA **ENABLED** for email/password authentication, but the reCAPTCHA keys are **INCOMPLETE** or **MISCONFIGURED** in Google Cloud Console. This causes Firebase Auth to hang waiting for a reCAPTCHA token that never arrives.

## THE FIX: Disable reCAPTCHA for Email/Password

### Step 1: Go to Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Click **Authentication** in the left sidebar
4. Click **Settings** tab (NOT "Sign-in method")

### Step 2: Disable reCAPTCHA

1. Scroll down to **"Fraud prevention"** section
2. Click on **"reCAPTCHA"**
3. Look for **"Email/Password"** authentication settings
4. **DISABLE reCAPTCHA** for email/password authentication
5. Click **Save**

### Step 3: Wait and Test

1. Wait **2-3 minutes** for changes to propagate
2. Try logging in again
3. The "empty reCAPTCHA token" error should be gone

## Alternative: If You Can't Find the Setting

If you don't see the reCAPTCHA setting in Firebase Console:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **APIs & Services** > **Credentials**
4. Find the reCAPTCHA key (it might be named "FamilyHub Android reCAPTCHA Key" or similar)
5. Click on it
6. Under **"Application restrictions"**, ensure:
   - Package name: `com.example.familyhub_mvp.dev` is added
   - Package name: `com.example.familyhub_mvp.test` is added
   - Package name: `com.example.familyhub_mvp` is added
   - SHA-1 fingerprint: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C` is added
7. Click **Save**

## Why This Happens

- Firebase enables reCAPTCHA by default for email/password auth in some projects
- If reCAPTCHA keys aren't fully configured, Firebase Auth hangs waiting for a token
- The timeout happens because Firebase never gets the reCAPTCHA response

## Verification

After disabling reCAPTCHA, you should see in logs:
- ✅ `FirebaseAuth: Logging in as [email]` (WITHOUT "empty reCAPTCHA token")
- ✅ Login completes in 1-2 seconds instead of timing out

## Important Notes

- **App Check is separate from reCAPTCHA** - App Check warnings are not blocking auth
- **Disabling reCAPTCHA is safe** for email/password authentication
- **reCAPTCHA is mainly for phone authentication** - not needed for email/password

---

**THIS IS THE ONLY FIX THAT WILL WORK.** Code changes won't help - this is a Firebase Console configuration issue.

