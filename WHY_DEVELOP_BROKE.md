# Why Develop Branch Has reCAPTCHA Issue But release/qa Works

## Root Cause

**The `release/qa` branch has a workaround that `develop` branch removed.**

### What Was Different

**release/qa branch:**
- `MainActivity.kt` contains `setAppVerificationDisabledForTesting(true)`
- This **disables reCAPTCHA verification** at the code level
- This is why login works on release/qa

**develop branch:**
- `MainActivity.kt` was simplified (workaround removed)
- No code-level reCAPTCHA bypass
- Firebase tries to use reCAPTCHA → "empty reCAPTCHA token" error

## The Fix

I've restored the `MainActivity.kt` code from `release/qa` branch that disables app verification.

This is a **temporary workaround** until reCAPTCHA is properly configured in Firebase Console.

## Long-Term Solution

1. Complete reCAPTCHA key setup in Google Cloud Console (add SHA-1 fingerprints)
2. OR properly configure reCAPTCHA in Firebase Console
3. Then remove the workaround from `MainActivity.kt`

## Why This Happened

When migrating from `release/qa` to `develop`, the workaround was removed thinking it was unnecessary. However, it was actually **required** because reCAPTCHA isn't properly configured in Firebase Console.

---

**Status:** ✅ Fixed - `MainActivity.kt` restored from `release/qa`

