# App Check Debug Token Setup Guide

## Step 1: Run Your App in Debug Mode

1. Connect your device via USB
2. Run the app in debug mode:
   ```bash
   flutter run --flavor qa
   ```
   Or use your IDE's debug run button

## Step 2: Capture the Debug Token

The app will automatically log the debug token. You can capture it in two ways:

### Option A: From Flutter Logs (Easiest)
1. Look in your IDE's console/log output
2. Search for: `🔑 APP CHECK DEBUG TOKEN`
3. Copy the token value (the long string after "Token:")

### Option B: From ADB Logcat
1. Open a terminal
2. Run:
   ```bash
   adb logcat | grep -i "AppCheck\|debug token"
   ```
3. Look for the token in the output
4. Copy the token value

### Option C: Full Logcat Search
1. Run:
   ```bash
   adb logcat -d > logcat.txt
   ```
2. Open `logcat.txt` in a text editor
3. Search for: "APP CHECK DEBUG TOKEN" or "Token:"
4. Copy the token value

## Step 3: Register Token in Firebase Console

1. **Go to Firebase Console**
   - https://console.firebase.google.com/
   - Select your project: **family-hub-71ff0**

2. **Navigate to App Check**
   - Click **"App Check"** in the left sidebar
   - Click on your Android app: **com.example.familyhub_mvp.test** (or your dev flavor)

3. **Open Debug Tokens**
   - Click **"Manage debug tokens"** button
   - This opens the dialog you're seeing

4. **Add the Token**
   - Click **"Add debug token"** button
   - **Name**: Enter a descriptive name (e.g., "Samsung Device - Dev Build" or "My Development Device")
   - **Value**: Paste the token you copied from Step 2
     - ⚠️ **Replace the placeholder** `00000000-0000-4000-A00000000000` with your actual token
   - Click **"Save"**

## Step 4: Verify Token is Registered

1. After saving, you should see your token in the list
2. The token will be active immediately (no wait time needed)
3. Restart your app to use the registered token

## Step 5: Test Authentication

1. Close and restart your app
2. Try logging in
3. Authentication should work now (if App Check was the issue)

## Troubleshooting

### Token Not Appearing in Logs?
- Make sure you're running in **debug mode** (not release)
- Check that App Check initialization succeeded (look for "✓ App Check initialized")
- Try the logcat methods above

### Token Invalid/Not Working?
- Verify you copied the **entire token** (it's a long string)
- Make sure you're using the correct Firebase project
- Check that the app package name matches in Firebase Console

### Still Getting Authentication Errors?
- App Check may not be the issue
- Check:
  - SHA-1 fingerprint is registered in Firebase Console
  - API key restrictions allow Identity Toolkit API
  - Google account is added to device (for Play Services)

## What the Token Looks Like

The debug token is a UUID format string, for example:
```
a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

It will appear in logs like:
```
Token: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

## Important Notes

- **Debug tokens only work in debug builds**
- **Each device/build may generate a different token**
- **Tokens don't expire** (unlike production App Check tokens)
- **You can register multiple tokens** (useful for team development)

## Next Steps After Setup

Once debug token is registered:
1. ✅ App Check will work in debug builds
2. ✅ Authentication should work (if App Check was blocking it)
3. ✅ You can test all Firebase features with App Check enabled

For production builds, you'll use Play Integrity (already configured in code).

