# Complete reCAPTCHA Key Setup - Step by Step

## Current Status
- **Key Name:** FamilyHub Android reCAPTCHA Key
- **Key ID:** 6LeprxosAAAAACXWuPlrlx0zOyM3GpJOVhBHvJ5e
- **Status:** Incomplete ❌
- **Issue:** "No assessments were created this month" - key has never been used

## What "Incomplete" Means

The key exists but:
- Hasn't been properly configured
- Hasn't had tokens requested yet
- Firebase Auth can't use it because it's not activated

## How to Complete the Setup

### Step 1: Click "View instructions" under "Android app" Integration
This will show you how to integrate the key into your Android app.

### Step 2: Configure the Key for Your App
You need to:
1. **Add package name:** `com.example.familyhub_mvp.dev` (for dev flavor)
2. **Add SHA-1 fingerprint:** `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
3. **Enable package name verification**

### Step 3: Request Tokens (Execute)
The key needs to actually be used (tokens requested) before it becomes "Active". This happens when:
- Your app makes its first authentication request
- Firebase Auth tries to use the key
- The key generates a token

## Alternative: Disable reCAPTCHA for Email/Password

If you don't want to use reCAPTCHA for email/password authentication:

1. Go to **Firebase Console** → **Authentication** → **Settings**
2. Find **reCAPTCHA** section
3. **Disable** reCAPTCHA for email/password authentication
4. This tells Firebase "don't use reCAPTCHA for email/password"

This is simpler and may be what you want if reCAPTCHA is only needed for SMS/phone auth.

## Why This Fixes the Timeout

**Current situation:**
- Firebase Auth tries to use reCAPTCHA
- Key is incomplete/not configured
- Can't generate token
- Result: "empty reCAPTCHA token" → 30-second timeout

**After fixing:**
- Key is complete and configured
- OR reCAPTCHA is disabled for email/password
- Firebase Auth can proceed without reCAPTCHA
- Result: Login works in 2-5 seconds

## Recommendation

**For development/testing:** Disable reCAPTCHA for email/password in Firebase Console (simpler, faster)

**For production:** Complete the key configuration properly (more secure)

