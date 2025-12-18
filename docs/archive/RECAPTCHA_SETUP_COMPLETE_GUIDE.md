# Complete reCAPTCHA Setup - Step by Step

## Current Status ✅

- ✅ **Code:** `MainActivity.kt` has workaround (works like `release/qa`)
- ✅ **SHA-1 Fingerprint:** `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
- ✅ **Package Names:** Already configured
- ⚠️ **Google Cloud Console:** Needs SHA-1 added to reCAPTCHA key

## What You Need to Do (Google Cloud Console)

I cannot access Google Cloud Console directly, but here are the exact steps:

### Step 1: Open reCAPTCHA Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Navigate to **Security** → **reCAPTCHA**
4. Find **"FamilyHub Android reCAPTCHA Key"**
5. Click on it

### Step 2: Add SHA-1 Fingerprint

**Option A: If you see "Edit key" button:**
1. Click **"Edit key"**
2. Look for **"SHA-1 certificate fingerprints"** section
3. Click **"Add SHA-1 fingerprint"**
4. Paste: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
5. Click **"Update key"**

**Option B: If you see "Integration" tab:**
1. Click **"Integration"** tab
2. Under **"Android app"**, click **"View instructions"**
3. Follow the instructions to add SHA-1 fingerprint
4. The instructions will show exactly where to add it

### Step 3: Verify Package Names

Ensure these are listed (should already be there):
- `com.example.familyhub_mvp`
- `com.example.familyhub_mvp.dev`
- `com.example.familyhub_mvp.test`

### Step 4: Wait and Test

1. Wait **2-3 minutes** for changes to propagate
2. Key status should change from "Incomplete" to "Active"
3. Rebuild app:
   ```bash
   flutter clean
   flutter pub get
   flutter run --flavor dev --dart-define=FLAVOR=dev
   ```
4. Test login - should work without errors

## What's Already Done in Code ✅

1. ✅ **MainActivity.kt** - Workaround restored (bypasses reCAPTCHA until keys are complete)
2. ✅ **Network Security Config** - Allows reCAPTCHA endpoints
3. ✅ **Firebase Auth** - Properly configured (handles reCAPTCHA automatically)
4. ✅ **SHA-1 Fingerprint** - Identified and ready to add

## After Completing Google Cloud Console Setup

Once you've added the SHA-1 fingerprint:

1. **Test login** - Should work immediately
2. **Optional:** Remove workaround from `MainActivity.kt` for better security:
   ```kotlin
   package com.example.familyhub_mvp
   import io.flutter.embedding.android.FlutterActivity
   
   class MainActivity : FlutterActivity() {
       // reCAPTCHA properly configured - no workaround needed
   }
   ```

## Why This Works

- Firebase Auth automatically uses reCAPTCHA when keys are properly configured
- Adding SHA-1 fingerprint completes the key setup
- Firebase can then generate valid reCAPTCHA tokens
- No "empty reCAPTCHA token" errors

---

**Note:** The app will work with the current workaround, but completing the Google Cloud Console setup is the proper long-term solution.

