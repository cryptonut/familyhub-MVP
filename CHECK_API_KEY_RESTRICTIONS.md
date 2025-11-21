# Check API Key Restrictions (Chrome Works, Android Doesn't)

## The Problem
- ✅ Chrome login works
- ❌ Android app times out
- ✅ SHA-1 fingerprint registered
- ✅ App Check enforcement is OFF

**This strongly suggests API key restrictions in Google Cloud Console.**

## Step-by-Step: Check API Key Restrictions

### Step 1: Open Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Make sure you're in project: **family-hub-71ff0**
   - If not, click the project dropdown at the top and select it

### Step 2: Navigate to Credentials

1. In the left sidebar, click **"APIs & Services"**
2. Click **"Credentials"**
3. You'll see a list of API keys

### Step 3: Find Your API Key

Look for API key: **AIzaSyDLZ3mdwyumvm_oXPWBAUtANQBSlbFizyk**

(It might show as truncated like "AIzaSyDLZ3...")

### Step 4: Click on the API Key

Click on the API key name to open its details.

### Step 5: Check "Application restrictions"

Look for the **"Application restrictions"** section:

**If it says "None":**
- ✅ This is OK - no restrictions

**If it says "Android apps" or "HTTP referrers":**
- ⚠️ This might be the problem
- Check if your package name is listed: `com.example.familyhub_mvp`
- If your package name is NOT listed, that's the problem!

**To fix:**
1. Click **"Edit API key"** (pencil icon)
2. Under "Application restrictions", select **"None"** (for development)
   - OR add your package name if using "Android apps"
3. Click **"Save"**
4. Wait 1-2 minutes for changes to propagate

### Step 6: Check "API restrictions"

Look for the **"API restrictions"** section:

**If it says "Don't restrict key":**
- ✅ This is OK

**If it lists specific APIs:**
- ⚠️ Check if **"Identity Toolkit API"** is in the list
- If **"Identity Toolkit API"** is NOT in the list, that's the problem!

**To fix:**
1. Click **"Edit API key"** (pencil icon)
2. Under "API restrictions", select **"Don't restrict key"** (for development)
   - OR add **"Identity Toolkit API"** to the list
3. Click **"Save"**
4. Wait 1-2 minutes for changes to propagate

## Quick Test After Changes

1. Rebuild the app: `flutter clean && flutter pub get && flutter run`
2. Try login again on Android
3. Check logs for the new diagnostic messages

## Alternative: Create a New Unrestricted API Key (For Testing)

If you can't modify the existing key:

1. In Google Cloud Console > APIs & Services > Credentials
2. Click **"+ CREATE CREDENTIALS"** > **"API key"**
3. A new key will be created
4. **Don't add any restrictions** (for testing)
5. Copy the new API key
6. Update `lib/firebase_options.dart` with the new key
7. Rebuild and test

## What the Logs Will Show

After rebuilding, the logs will show:
- `AuthService: Starting Firebase Auth call (attempt 1)...`
- If it times out: detailed diagnostic messages
- If it succeeds: `AuthService: Firebase Auth call succeeded in Xms`

This will help pinpoint exactly where it's failing.

