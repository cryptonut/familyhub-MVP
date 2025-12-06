# CRITICAL: Check Firestore Database Mode

## The App is Hanging After Login

The spinning circle after login means Firestore is failing to load user data. This is the **#1 most common cause** of "works on web, unavailable on Android."

## Immediate Action Required

**Visit this URL RIGHT NOW:**
```
https://console.firebase.google.com/project/family-hub-71ff0/firestore/data
```

## What to Look For

### Scenario 1: "Create database" button
- ✅ **This is the issue!**
- Click "Create database"
- **CRITICAL**: Choose **"Native mode"** (NOT Datastore mode)
- Select a location (e.g., us-central1)
- Create the database
- **Result**: Android will connect instantly

### Scenario 2: Shows "Datastore mode" at the top
- ⚠️ **This is the problem!**
- Android/iOS cannot connect to Datastore mode
- Web works because it falls back gracefully
- **No migration path exists** from Datastore to Native mode
- You'll need to create a NEW Firestore database in Native mode
- Existing Datastore data cannot be migrated

### Scenario 3: Shows existing data in Native mode
- If you see your data and it says "Native mode" or just shows data
- Then the issue is something else (API key, etc.)
- But this is unlikely given the symptoms

## Why This Causes "Works on Web, Unavailable on Android"

- **Android/iOS SDKs**: Cannot connect to Firestore in Datastore mode → instant "unavailable" error
- **Web SDK**: Falls back gracefully → works fine
- **Result**: Exact symptoms you're experiencing

## After Fixing Database Mode

1. The app should connect instantly
2. No code changes needed
3. Family data will load
4. All Firestore queries will work

## Next Steps

1. **Check the Firestore URL above RIGHT NOW**
2. Tell me what you see
3. If it's Datastore mode or needs creation, we'll fix it
4. If it's already Native mode, we'll investigate the API key issue

