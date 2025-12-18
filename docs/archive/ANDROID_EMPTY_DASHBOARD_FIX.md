# Android Empty Dashboard Fix

## The Problem

You're seeing:
- ✅ Family ID is now matching Kate and Lilly (fix worked!)
- ✅ Kate can see your account from Chrome
- ❌ You can't see Kate or Lilly from Android
- ❌ No wallet balance, jobs, or other data on Android
- ❌ No login screen - jumped straight to empty dashboard

## Root Cause

**Firebase Auth is working** (that's why no login screen - session persisted)
**Firestore is unavailable on Android** (that's why no data loads)

This creates an "authenticated but no data" state where:
1. App starts with persisted Auth session
2. AuthWrapper sees user is "logged in"
3. Shows dashboard immediately
4. But all Firestore calls fail with "unavailable"
5. Dashboard loads empty with no family members, wallet, jobs, etc.

## What I've Added

### 1. **Firestore Unavailable Detection**
- `AuthWrapper` now checks if Firestore is accessible on startup
- If `getCurrentUserModel()` returns null or times out, shows warning
- Dashboard detects Firestore unavailable errors and shows error state

### 2. **Clear Error Messages**
When Firestore is unavailable, you'll see:
- SnackBar: "Cannot load data from Firestore. Please sign out and sign back in."
- With a "Sign Out" button for quick action
- Orange/red warnings to make it obvious

### 3. **"Refresh Session" Menu Option**
- New menu item: "Refresh Session" (blue, with refresh icon)
- Forces sign out to clear persisted Auth session
- Allows you to sign back in with fresh session
- Located in the main menu (three dots)

### 4. **Better Timeout Handling**
- All Firestore calls now have 10-second timeouts
- Detects when Firestore is truly unavailable vs just slow
- Shows appropriate error messages

## How to Fix Your Current Situation

### Option 1: Use "Refresh Session" (Easiest)
1. Tap menu (three dots) in top right
2. Select "Refresh Session" (blue option)
3. Confirm sign out
4. Sign back in
5. This clears the persisted session and forces fresh Firestore connection

### Option 2: Use Logout
1. Tap menu > "Logout" (red option)
2. Sign back in
3. Same effect as Refresh Session

### Option 3: Fix the Root Cause (Firestore Unavailable)
The real issue is Firestore is unavailable on Android. Check:

1. **API Key Restrictions** (Most Likely)
   - Go to Google Cloud Console
   - Find key: `YOUR_FIREBASE_API_KEY`
   - Under "API restrictions", ensure **"Cloud Firestore API"** is enabled
   - Not just "Identity Toolkit API" (that's for Auth)
   - Both need to be enabled!

2. **Application Restrictions**
   - Should be "None" for development
   - Or "Android apps" with package `com.example.familyhub_mvp` + SHA-1

3. **Firestore API Enabled**
   - Google Cloud Console > APIs & Services > Library
   - Search "Cloud Firestore API"
   - Click "Enable" if not enabled

## Why Chrome Works But Android Doesn't

- **Chrome** uses web API key (`AIzaSyC_WWJtrIRRMvRyjMe7WaeYQ0veE9cs-Mw`) - Firestore API enabled
- **Android** uses Android API key (`YOUR_FIREBASE_API_KEY`) - Firestore API may not be enabled

They're different keys with different restrictions!

## Expected Behavior After Fix

Once Firestore is accessible on Android:
1. App starts
2. Auth session persists (no login screen)
3. **Firestore calls succeed**
4. Dashboard loads with:
   - ✅ Family members (Kate, Lilly, you)
   - ✅ Wallet balance
   - ✅ Jobs/tasks
   - ✅ All your data

## Quick Test

After enabling Cloud Firestore API on the Android key:
1. Use "Refresh Session" to sign out and back in
2. Dashboard should load with all data
3. You should see Kate and Lilly in family members
4. Wallet balance and jobs should appear

The enhanced error detection will now clearly show when Firestore is unavailable vs when it's working.

