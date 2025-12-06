# Complete reCAPTCHA Setup Guide

## Current Status

✅ **SHA-1 Fingerprint:** `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`  
✅ **Package Names:** Already configured in Google Cloud Console  
⚠️ **Key Status:** INCOMPLETE (needs SHA-1 added)

## Step-by-Step: Complete reCAPTCHA Key Setup

### Step 1: Go to Google Cloud Console

1. Open [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Navigate to **Security** → **reCAPTCHA**
4. Find **"FamilyHub Android reCAPTCHA Key"**
5. Click on it to open key details

### Step 2: Add SHA-1 Fingerprint

1. Click **"Edit key"** button (top right)
2. Scroll down to find **"Android app"** section or **"SHA-1 certificate fingerprints"**
3. If you see **"Add SHA-1 fingerprint"** button, click it
4. Paste: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
5. Click **"Update key"** or **"Save"**

### Step 3: If SHA-1 Section Not Visible

If you don't see SHA-1 fields on the Edit page:

1. Go back to key details page
2. Click **"Integration"** tab
3. Under **"Android app"**, click **"View instructions"**
4. Follow the instructions to add SHA-1 fingerprint
5. The instructions will show you exactly where to add it

### Step 4: Verify Package Names

Ensure these are listed (they should already be):
- `com.example.familyhub_mvp`
- `com.example.familyhub_mvp.dev`
- `com.example.familyhub_mvp.test`

### Step 5: Wait and Test

1. Wait **2-3 minutes** for changes to propagate
2. The key status should change from "Incomplete" to "Active"
3. Rebuild app: `flutter clean && flutter pub get && flutter run`
4. Test login - should work without "empty reCAPTCHA token" error

## Alternative: If You Want to Remove the Workaround

Once reCAPTCHA is properly configured:

1. Remove `setAppVerificationDisabledForTesting(true)` from `MainActivity.kt`
2. Restore the minimal `MainActivity.kt`:
   ```kotlin
   package com.example.familyhub_mvp
   import io.flutter.embedding.android.FlutterActivity
   
   class MainActivity : FlutterActivity() {
       // No workarounds needed - reCAPTCHA properly configured
   }
   ```

## Why This Works

- Firebase Auth automatically uses reCAPTCHA when keys are properly configured
- Adding SHA-1 fingerprint completes the key setup
- Firebase can then generate valid reCAPTCHA tokens
- No "empty reCAPTCHA token" errors

---

**Note:** The workaround in `MainActivity.kt` will continue to work until you complete this setup. Once reCAPTCHA keys are complete, you can remove the workaround for better security.

