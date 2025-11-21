# CRITICAL: Verify NEW API Key Settings

## Issue
Firestore is still showing `[cloud_firestore/unavailable]` even with the new `google-services.json` and new API key.

## New API Key
**AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4**

This is a DIFFERENT key from the old one (`AIzaSyDLZ3mdwyumvm_oXPWBAUtANQBSlbFizyk`).

## Action Required

**Verify the NEW API key settings:**

1. Go to: https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0

2. Find the API key: **AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4**
   - This is the key from the NEW app registration
   - It's different from the old key you showed me earlier

3. Check these settings:
   - **Application restrictions**: Should be "None"
   - **API restrictions**: Should be either:
     - "Don't restrict key" OR
     - "Restrict key" with "Cloud Firestore API" explicitly listed

4. If the new key has restrictions:
   - Click on the key
   - Set Application restrictions to "None"
   - Under API restrictions, ensure "Cloud Firestore API" is included
   - Save

5. Wait 2-3 minutes for settings to propagate

## Why This Matters

When you deleted and re-added the Android app, Firebase created a NEW API key. This new key might have:
- Different restrictions than the old one
- Cloud Firestore API not enabled
- Application restrictions set

The screenshot you showed earlier might have been for the OLD key, not this new one.

## After Verifying

Once you confirm the new API key has correct settings:
1. Wait 2-3 minutes for propagation
2. Try the app again
3. Check if Firestore connects

