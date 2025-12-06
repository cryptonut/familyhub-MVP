# Fix Firestore Unavailable Error

## The Real Problem
✅ **Firebase Auth works** - login succeeds in ~900ms
❌ **Firestore is unavailable** - can't load user data

## Error in Logs
```
[cloud_firestore/unavailable] The service is currently unavailable. 
This is a most likely a transient condition and may be corrected by retrying with a backoff.
```

## Possible Causes

### 1. Firestore Database Not Created
Firestore database might not exist in Firebase Console.

**Check:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Click **Firestore Database** in left sidebar
4. If you see "Create database" → **Click it and create the database**

### 2. Firestore API Not Enabled
Even though we added "Cloud Firestore API" to API key restrictions, the API might not be enabled in Google Cloud Console.

**Check:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **APIs & Services** > **Enabled APIs**
4. Search for "Cloud Firestore API"
5. If it's NOT enabled → **Click "Enable"**

### 3. Firestore Location/Region Issue
Firestore might be in a different region or not properly configured.

**Check:**
1. Firebase Console > Firestore Database
2. Check the database location/region
3. Make sure it's created and active

### 4. Network Issue with Firestore
The Android device might be blocking Firestore endpoints specifically.

**Test:**
- Try accessing Firestore from Chrome (web) - does it work?
- If web works but Android doesn't → network/firewall issue

## Quick Fix: Verify Firestore Database Exists

1. **Firebase Console** > **Firestore Database**
2. If database doesn't exist:
   - Click **"Create database"**
   - Choose **"Start in test mode"** (for development)
   - Select a location (choose closest to you)
   - Click **Enable**

3. **Wait 2-3 minutes** for database to initialize

4. **Rebuild app** and try again

## Why This Happens

The app logs you in (Firebase Auth works), but then tries to load your user data from Firestore. If Firestore is unavailable, you appear "logged in" but have no data, which is why you see an empty dashboard.

## Next Steps

1. **First**: Check if Firestore database exists in Firebase Console
2. **Second**: Enable Cloud Firestore API in Google Cloud Console
3. **Third**: Rebuild and test

The login timeout issue is **SOLVED** - Firebase Auth works! Now we just need to fix Firestore access.

