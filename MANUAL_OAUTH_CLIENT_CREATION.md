# Manually Create OAuth Client - Step by Step

## Why This is Needed

Firebase isn't auto-generating OAuth clients even after OAuth consent screen is configured. We need to manually create one.

## Step-by-Step Instructions

### Step 1: Get Your SHA-1 Fingerprint

Run this command in PowerShell:

```powershell
keytool -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Look for the **SHA1:** value and copy it. It should look like: `BB:7A:6A:5F:57:F1:00:00:ED:14:24:5C:6F:2...`

### Step 2: Create OAuth Client

1. **Go to**: https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0

2. **Click**: "+ Create Credentials" (top of page)

3. **Select**: "OAuth client ID"

4. **Application type**: Select **"Android"**

5. **Fill in the form**:
   - **Name**: `Family Hub Android Client` (or any name)
   - **Package name**: `com.example.familyhub_mvp`
   - **SHA-1 certificate fingerprint**: Paste the SHA1 value from Step 1

6. **Click**: "Create"

7. **Note the Client ID** that's generated (you'll see it in a popup)

### Step 3: Wait and Re-download

1. **Wait 2-3 minutes** for changes to propagate

2. **Go to Firebase Console**: https://console.firebase.google.com/project/family-hub-71ff0/settings/general

3. **Scroll to "Your apps"** section

4. **Find Android app**: `com.example.familyhub_mvp`

5. **Click gear icon** or app name

6. **Click "Download google-services.json"**

7. **Replace** `android/app/google-services.json` with the new file

### Step 4: Verify OAuth Client is Populated

Open the new `google-services.json` and check:

```json
"oauth_client": [
  {
    "client_id": "123456789-abc.apps.googleusercontent.com",
    "client_type": 3
  }
]
```

Should **NOT** be empty `[]`.

### Step 5: Rebuild and Test

```bash
flutter clean
flutter pub get
flutter run
```

Test authentication - should work now!

## Alternative: Enable Google Sign-In First

Sometimes enabling Google Sign-In in Firebase helps generate OAuth clients:

1. Go to [Firebase Console > Authentication > Sign-in method](https://console.firebase.google.com/project/family-hub-71ff0/authentication/providers)
2. Click on **"Google"** provider
3. **Enable** it (even if you're not using it)
4. Save
5. Wait 5 minutes
6. Re-download `google-services.json`

This might trigger Firebase to generate OAuth clients.

## If Still Empty After Manual Creation

If you manually create the OAuth client but it still doesn't appear in `google-services.json`:

1. **Check Google Cloud Console > Credentials** - verify the OAuth client exists
2. **Wait longer** (up to 10 minutes) for Firebase to sync
3. **Try removing and re-adding** the Android app in Firebase Console
4. **Contact Firebase support** if issue persists

The empty `oauth_client` is definitely the root cause of your authentication timeout.

