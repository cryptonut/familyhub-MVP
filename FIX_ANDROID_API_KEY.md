# Fix Android API Key Restrictions (Proper Solution)

## The Real Problem

You have **TWO different API keys**:
- **Web API Key**: `AIzaSyC_WWJtrIRRMvRyjMe7WaeYQ0veE9cs-Mw` (works fine)
- **Android API Key**: `YOUR_FIREBASE_API_KEY` (blocked by restrictions)

Chrome works because it uses the web key. Android fails because its key has restrictions.

## Proper Solution: Fix Android API Key Restrictions

### Step 1: Find the Android API Key in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **APIs & Services** > **Credentials**
4. Find API key: **YOUR_FIREBASE_API_KEY**
   - (It might show as truncated: "AIzaSyDLZ3...")
5. Click on it to open details

### Step 2: Check "Application restrictions"

Look at **"Application restrictions"**:

**If it says "None":**
- ✅ No restrictions - this is fine

**If it says "Android apps":**
- Check if your package name is listed: `com.example.familyhub_mvp`
- If it's NOT listed, that's why Android is blocked!

**If it says "HTTP referrers" or "IP addresses":**
- This is wrong for Android - Android apps can't use HTTP referrer restrictions
- This will block all Android requests

### Step 3: Fix Application Restrictions

**Option A: For Development (Recommended)**
1. Click **"Edit API key"** (pencil icon)
2. Under "Application restrictions", select **"None"**
3. Click **"Save"**

**Option B: For Production (More Secure)**
1. Click **"Edit API key"** (pencil icon)
2. Under "Application restrictions", select **"Android apps"**
3. Click **"Add an item"**
4. Enter:
   - **Package name**: `com.example.familyhub_mvp`
   - **SHA-1 certificate fingerprint**: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
5. Click **"Save"**

### Step 4: Check "API restrictions"

Look at **"API restrictions"**:

**If it says "Don't restrict key":**
- ✅ No restrictions - this is fine

**If it lists specific APIs:**
- Check if **"Identity Toolkit API"** is in the list
- If **"Identity Toolkit API"** is NOT listed, that's why auth fails!

**To fix:**
1. Click **"Edit API key"** (pencil icon)
2. Under "API restrictions":
   - **For development**: Select **"Don't restrict key"**
   - **For production**: Make sure **"Identity Toolkit API"** is in the list
3. Click **"Save"**

### Step 5: Wait and Test

1. Wait 1-2 minutes for changes to propagate
2. Rebuild app: `flutter clean && flutter pub get && flutter run`
3. Try login on Android

## Why This Happens

Firebase creates separate API keys for each platform:
- Web apps get one API key
- Android apps get another API key (from `google-services.json`)
- iOS apps get yet another API key

Each key can have different restrictions. The Android key had restrictions that blocked it, while the web key didn't.

## Production Best Practices

For production, you should:
1. **Application restrictions**: Set to "Android apps" with your package name + SHA-1
2. **API restrictions**: List only the APIs you need (Identity Toolkit API, Firestore API, etc.)

This is more secure than removing all restrictions, but requires proper configuration.

## Verify It's Fixed

After fixing, the logs should show:
- `AuthService: Firebase Auth call succeeded in Xms` (instead of timing out)
- Login should work on Android

