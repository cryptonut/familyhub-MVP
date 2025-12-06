# Check API Key Restrictions (Quick Guide)

## What is Google Cloud Console?

Google Cloud Console is where you manage your Firebase project's backend settings. It's the same project as Firebase, just a different interface.

## Quick Access

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. **OR** easier: In Firebase Console, click the gear icon ⚙️ next to "Project Overview"
3. Click **"Project settings"**
4. Scroll down and click **"Open in Google Cloud Console"** (if available)

## Check API Key Restrictions

1. In Google Cloud Console, go to **"APIs & Services"** > **"Credentials"** (left sidebar)
2. Find the API key that starts with: **YOUR_FIREBASE_API_KEY**
3. Click on it
4. Check **"API restrictions"**:
   - If it says **"Don't restrict key"** → ✅ Good, no restrictions
   - If it says **"Restrict key"** → Check that it includes:
     - ✅ Firebase Authentication API
     - ✅ Identity Toolkit API
     - ✅ Cloud Firestore API
5. Check **"Application restrictions"**:
   - If it says **"None"** → ✅ Good
   - If it says **"Android apps"** → Make sure it includes:
     - ✅ Package name: `com.example.familyhub_mvp`
     - ✅ SHA-1 fingerprint: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`

## If You Can't Access Google Cloud Console

**Alternative:** The timeout might be a network issue. Try:
1. **Different network** - Switch from WiFi to mobile data (or vice versa)
2. **Check device internet** - Open a browser on the device and visit google.com
3. **Restart device/emulator** - Sometimes helps with network issues
4. **Check firewall** - If on a corporate network, firewall might block Firebase

## Test Firebase Connectivity

The app now has retry logic (3 attempts). If all 3 attempts timeout, it's definitely a network or Firebase configuration issue.

