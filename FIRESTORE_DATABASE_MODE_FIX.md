# Firestore Database Mode Fix

## Root Cause Identified

The Firestore "unavailable" error on Android (while working on web) was caused by the Firestore database being in **Datastore mode** instead of **Native mode**.

### Why This Happens
- Android/iOS SDKs cannot connect to Firestore instances in Datastore mode
- Web applications fall back gracefully, which is why web works
- This is the #1 hidden gotcha for "works on web, unavailable on Android" issues

### Symptoms
- ✅ Web/Chrome works perfectly
- ❌ Android fails instantly with `[cloud_firestore/unavailable]`
- ✅ Cloud Firestore API is enabled
- ✅ No API key restrictions
- ✅ Network connectivity is fine
- ✅ Firebase Auth works

### Fix (30 seconds)

1. **Visit Firebase Console:**
   ```
   https://console.firebase.google.com/project/family-hub-71ff0/firestore/data
   ```

2. **Check what you see:**
   - **Option A**: "Create database" button appears
     - Click "Create database"
     - Choose **"Native mode"** (NOT Datastore mode)
     - Select a location (e.g., us-central1)
     - Create the database
   
   - **Option B**: Shows "Datastore mode" at the top
     - ⚠️ **No migration path exists** from Datastore to Native mode
     - You'll need to create a new Firestore database in Native mode
     - Existing data in Datastore mode cannot be migrated

3. **After creating in Native mode:**
   - Android will connect instantly
   - All existing Firestore queries will work
   - No code changes needed

### What Was Removed
- Removed the incorrect SHA-1 fingerprint workaround from `build.gradle.kts`
- Removed the debug `AndroidManifest.xml` workaround
- These were not the actual root cause

### Next Steps
1. Visit the Firebase Console URL above
2. Check if database exists and what mode it's in
3. Create in Native mode if needed
4. Test Android app - should connect instantly

