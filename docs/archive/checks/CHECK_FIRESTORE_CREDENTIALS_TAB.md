# Check Firestore API Credentials Tab

## Great Find!

You're on the **Cloud Firestore API details page**. The "Credentials" tab at the bottom is exactly what we need!

## What to Do

### 1. Click the "Credentials" Tab
At the bottom of the page, click on **"Credentials"** (next to "Metrics", "Quotas", etc.)

This will show you:
- Which API keys have access to Cloud Firestore API
- Whether your Android key is listed
- If there are any credential issues

### 2. What to Look For

In the Credentials tab, you should see:
- Your Android key: `YOUR_FIREBASE_API_KEY`
- It should show as having access to Cloud Firestore API

If the Android key is **NOT** listed, or shows as restricted, that's the issue!

### 3. Alternative: Check from Credentials Page

You can also:
1. Go back to "Credentials" in the left sidebar
2. Click on the Android key to edit it
3. Look at "API restrictions" section
4. Make sure "Cloud Firestore API" is in the allowed list

## What This Will Tell Us

The Credentials tab on the API page shows a **reverse view**:
- Instead of "which APIs does this key allow?"
- It shows "which keys can access this API?"

This is perfect for confirming the Android key has Firestore access!

## Expected Result

If everything is correct, you should see:
- ✅ Android key listed in the Credentials tab
- ✅ Cloud Firestore API enabled for that key
- ✅ Then the "Refresh Session" in the app should work

Let me know what you see in the Credentials tab!

