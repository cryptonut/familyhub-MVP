# Critical: SHA-1 Must Match

## The Issue
Even though Cloud Firestore API is in the allowed list, if the **SHA-1 fingerprint doesn't match** in the "Android apps" restriction, Google will reject ALL requests from your Android app.

## What to Check Right Now

In Google Cloud Console > Credentials > Edit Android key:

### Expand "Android apps" Section
Click to expand and verify it shows:

**Package name:** `com.example.familyhub_mvp`
**SHA-1:** `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`

## If SHA-1 is Missing or Different

### Option 1: Add/Update SHA-1
1. Click "Add an item" or edit the existing entry
2. Enter package: `com.example.familyhub_mvp`
3. Enter SHA-1: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`
4. Click "Save"
5. Wait 2-3 minutes

### Option 2: Temporarily Remove Restriction (For Testing)
1. Select "None" for Application restrictions
2. Click "Save"
3. Test immediately
4. Once working, add back Android apps restriction

## Why This Matters
- ✅ API restrictions: Cloud Firestore API allowed
- ❌ Application restrictions: SHA-1 mismatch = ALL requests blocked
- Result: Firestore unavailable even though API is enabled

The application restriction is checked FIRST, before API restrictions. If the app doesn't match, the request is rejected before even checking which API it's calling.

## After Fixing
1. Save in Google Cloud Console
2. Wait 2-3 minutes
3. In app: Menu > "Refresh Session"
4. Sign back in
5. Firestore should work!

This is likely the final piece of the puzzle!

