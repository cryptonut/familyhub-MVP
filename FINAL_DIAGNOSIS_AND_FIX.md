# Final Diagnosis: Two Potential Root Causes

## Issue Summary
- Firestore works on web, fails on Android with `[cloud_firestore/unavailable]`
- User ID is correct (Auth works)
- No family data visible
- `google-services.json` has empty `oauth_client` array
- Cannot delete/re-add app (30-day grace period)

## Two Potential Root Causes

### Root Cause #1: Firestore Database Mode (Most Likely)
**Symptom**: Works on web, instant "unavailable" on Android
**Fix**: Check if Firestore is in Datastore mode instead of Native mode
1. Visit: https://console.firebase.google.com/project/family-hub-71ff0/firestore/data
2. If you see "Create database" → create in **Native mode**
3. If you see "Datastore mode" → need to create new Firestore in Native mode
4. **This is the #1 hidden gotcha** for "works on web, unavailable on Android"

### Root Cause #2: Empty oauth_client in google-services.json
**Symptom**: `oauth_client` array is empty `[]` (should contain OAuth client IDs tied to SHA-1)
**Issue**: Firebase console bug - SHA-1 fingerprints not written to google-services.json
**Fix Options**:
- **Option A**: Add SHA-1 to existing app in Firebase console
  1. Go to: https://console.firebase.google.com/project/family-hub-71ff0/settings/general
  2. Find Android app, click on it
  3. Click "Add fingerprint" or "Add SHA-1"
  4. Get debug SHA-1:
     ```bash
     keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
  5. Add the SHA-1 fingerprint
  6. Download fresh google-services.json
  7. Replace android/app/google-services.json

- **Option B**: Wait 30 days for deletion to be final, then re-add app
- **Option C**: Try the certificate validation workaround (we removed this earlier)

## Recommended Action Plan

**Step 1: Check Firestore Database Mode FIRST** (Quickest to verify)
- Visit the Firestore console URL above
- This is the most common cause of "works on web, unavailable on Android"
- Takes 30 seconds to check

**Step 2: If Firestore is in Native mode, then fix google-services.json**
- Add SHA-1 to existing app
- Download fresh google-services.json
- Replace and rebuild

## Why Both Could Be Issues
- Firestore database mode would cause instant "unavailable" on Android
- Empty oauth_client might cause certificate validation issues
- Both could be contributing to the problem

