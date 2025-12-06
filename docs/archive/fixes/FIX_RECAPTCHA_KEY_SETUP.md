# Fix reCAPTCHA Enterprise Key Setup - ROOT CAUSE

## The Problem

Your reCAPTCHA Enterprise key shows **"Incomplete"** status with the message:
> "Finish setting up your key: Request tokens To protect your site or app, finish setting up your key. Start by requesting tokens (executes)."

This is **THE ROOT CAUSE** of your authentication timeout. Firebase Auth is trying to use reCAPTCHA but the key isn't properly configured, causing it to hang waiting for tokens.

## Solution: Complete reCAPTCHA Key Setup

### Step 1: Request Tokens (Execute Actions)

1. **Click "View instructions"** under "Actions" in the Configuration section
2. **Or** click the "Start by requesting tokens (executes)" link in the Incomplete warning
3. This will show you how to integrate reCAPTCHA execute calls in your app

### Step 2: Complete Android App Integration

1. **Click "View instructions"** under "Android app" in the Integration section
2. Follow the instructions to:
   - Add your package name: `com.example.familyhub_mvp.test` (for qa flavor)
   - Add SHA-1 fingerprint: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
   - Configure the reCAPTCHA SDK in your app

### Step 3: Verify Backend Integration (If Needed)

If you have a backend that verifies reCAPTCHA tokens:
1. Click "View instructions" under "Backend"
2. Follow the server-side verification setup

## Why This Causes Authentication Timeout

1. Firebase Auth tries to use reCAPTCHA for verification
2. reCAPTCHA key is incomplete → can't generate tokens
3. Firebase Auth waits for reCAPTCHA token that never comes
4. **Result: 30-second timeout**

## After Completing Setup

1. **Wait 1-2 minutes** for changes to propagate
2. **Restart your app**
3. **Try authentication** - should work now

## Alternative: Disable reCAPTCHA for Email/Password Auth

If you don't want to use reCAPTCHA Enterprise:

1. Go to **Firebase Console** > **Authentication** > **Settings**
2. Find **reCAPTCHA provider** section
3. **Disable** reCAPTCHA for email/password authentication
4. This will make Firebase Auth skip reCAPTCHA entirely

## Current Status

- ✅ You've identified the root cause (incomplete reCAPTCHA key)
- ⚠️ Key needs to be completed OR reCAPTCHA needs to be disabled
- ✅ Once fixed, authentication should work immediately

