# CRITICAL: API Key Fingerprint Mismatch

## The Problem

**The fingerprint in Google Cloud Console doesn't match your actual SHA-1!**

### What the Screenshot Shows:
- Fingerprint: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:24:50:6F`
- This appears to be **INCOMPLETE** (only 12 bytes instead of 20 bytes)

### What It Should Be:
- Based on `google-services.json`: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
- This is 20 bytes (full SHA-1)

## Critical Issues

1. **Fingerprint is Wrong/Incomplete**: The API key restrictions show a different fingerprint than what's in `google-services.json`
2. **Package Names May Be Missing**: Can't see full package names in screenshot - need to verify:
   - `com.example.familyhub_mvp` (base)
   - `com.example.familyhub_mvp.dev` (dev flavor)
   - `com.example.familyhub_mvp.test` (qa flavor)

## What to Check

1. **Verify all 3 package names are listed** in the Android restrictions table
2. **Verify the fingerprint matches** what's in `google-services.json`:
   - Should be: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
3. **If fingerprint is wrong**, update it in Google Cloud Console

## The Fix

1. Go to Google Cloud Console > API & Services > Credentials
2. Click on "Android key (auto created by Firebase)"
3. Under "Application restrictions" > "Android apps":
   - Verify all 3 package names are listed
   - Verify fingerprint is: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
   - If wrong, delete the incorrect entry and add the correct one
4. Save changes
5. Wait 2-3 minutes for propagation

## Why This Causes the Error

If the fingerprint in Google Cloud Console doesn't match your actual debug keystore, the API key is **silently rejected**. This causes:
- "empty reCAPTCHA token" errors
- 30-second timeouts
- No actual error message (silent rejection)

