# Root Cause: Why Firestore Works on Chrome But Not Android

## The Pattern
- ✅ **Chrome (Web)**: Firestore works fine
- ❌ **Android**: Firestore unavailable/timeout
- ✅ **Chrome (Web)**: Firebase Auth works
- ✅ **Android**: Firebase Auth works (after fixing API key)

## Root Cause Analysis

### Different API Keys
- **Web API Key**: `AIzaSyC_WWJtrIRRMvRyjMe7WaeYQ0veE9cs-Mw` (works)
- **Android API Key**: `YOUR_FIREBASE_API_KEY` (Firestore fails)

### Most Likely Cause
The **Android API key** (`YOUR_FIREBASE_API_KEY`) might not have:
1. **Cloud Firestore API enabled** in Google Cloud Console
2. **Cloud Firestore API** in the API restrictions list (even though we added it, it might not be enabled)

## How to Check

### Step 1: Verify Cloud Firestore API is Enabled
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **APIs & Services** > **Enabled APIs**
4. Search for **"Cloud Firestore API"**
5. **If it's NOT in the list** → Click **"+ ENABLE APIS AND SERVICES"** → Search "Cloud Firestore API" → Click **Enable**

### Step 2: Verify API Key Has Firestore API
1. Google Cloud Console → **APIs & Services** > **Credentials**
2. Find API key: **YOUR_FIREBASE_API_KEY**
3. Click on it
4. Check **"API restrictions"**:
   - Should include **"Cloud Firestore API"** in the list
   - If it's not there, add it

### Step 3: Test After Changes
1. Wait 2-3 minutes for changes to propagate
2. Rebuild app: `flutter clean && flutter pub get && flutter run`
3. Check logs - should see diagnostic messages showing which API key is used

## Why This Happens

**Web** uses a different API key that has Firestore API enabled.
**Android** uses a different API key that might not have Firestore API enabled.

Even though we added "Cloud Firestore API" to the API restrictions, the API itself might not be **enabled** in the project.

## The Fix

**Enable Cloud Firestore API** in Google Cloud Console (not just add it to restrictions).

This is different from adding it to API key restrictions - the API must be **enabled** for the project first.

