# Fix Android Login Timeout (Chrome Works, Android Doesn't)

## The Problem
- ✅ Chrome login works fine
- ❌ Android app times out on login
- ✅ SHA-1 fingerprint is registered
- ✅ Network connectivity is OK

This means the issue is **Android-specific**, not Firebase project configuration.

## Most Likely Cause: App Check Enforcement

Firebase App Check might be **enforcing** on Android but not on Web, blocking your Android app.

### Step 1: Check App Check Settings

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Click **"App Check"** in the left sidebar
4. Look for your Android app: **com.example.familyhub_mvp**
5. Check if **"Enforce"** is enabled (toggle should be OFF for development)

### Step 2: Disable App Check Enforcement (For Development)

1. In **App Check** page, find your Android app
2. If "Enforce" is ON, click it to turn it OFF
3. Save changes
4. Wait 1-2 minutes for changes to propagate
5. Try login again on Android

### Step 3: Verify App Check Provider

The app is using `AndroidProvider.debug` which should work, but if enforcement is ON, it will still block.

## Alternative: Check API Key Restrictions

Even though Chrome works, Android might be using a different API key path:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **"APIs & Services"** > **"Credentials"**
4. Find API key: **YOUR_FIREBASE_API_KEY**
5. Click on it
6. Check **"Application restrictions"**:
   - Should be **"None"** OR
   - Should include **"Android apps"** with your package name
7. Check **"API restrictions"**:
   - Should be **"Don't restrict key"** OR
   - Should include **"Identity Toolkit API"**

## Quick Test: Temporarily Disable App Check

If you want to test if App Check is the issue, we can temporarily disable it in code:

1. Open `lib/main.dart`
2. Comment out the App Check initialization (lines 143-165)
3. Rebuild and test

If login works → App Check enforcement is the issue
If login still fails → Different issue

## Other Possible Causes

1. **Android Network Security Config**: The device might be blocking Firebase endpoints
2. **Device Firewall/Proxy**: USB debugging might route through different network
3. **Firebase SDK Version**: Android SDK might have a bug (unlikely)

## Next Steps

1. **First**: Check App Check enforcement (most likely)
2. **Second**: Check API key restrictions
3. **Third**: Try disabling App Check in code temporarily
4. **Fourth**: Check device network settings

