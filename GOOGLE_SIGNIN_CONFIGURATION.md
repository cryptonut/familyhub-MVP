# Google Sign-In Configuration - What to Enter

## What You're Seeing

You're on the "Configure provider (step 2 of 2)" page for Google Sign-In in Firebase.

## Important Note

**You're using Email/Password authentication, NOT Google Sign-In.**

You have two options:

### Option 1: Just Enable the Toggle (Simplest)

1. **Toggle "Enable" to ON** (switch on the right)
2. **Leave Web client ID and Web client secret EMPTY** - they will auto-populate
3. **Click "Save"**
4. Wait 5-10 minutes
5. Re-download `google-services.json` from Firebase Console

This might trigger Firebase to generate OAuth clients.

### Option 2: Skip This Entirely (Recommended)

Since you're using **Email/Password** (not Google Sign-In), you don't actually need to enable Google Sign-In.

Instead, **manually create the Android OAuth client** in Google Cloud Console:

1. Go to: https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0
2. Click "+ Create Credentials" > "OAuth client ID"
3. Select "Android"
4. Enter:
   - **Name**: `Family Hub Android`
   - **Package name**: `com.example.familyhub_mvp`
   - **SHA-1**: Get it with the command below
5. Click "Create"
6. Wait 2-3 minutes
7. Re-download `google-services.json`

## Get Your SHA-1 Fingerprint

Run this in PowerShell:

```powershell
keytool -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Look for **SHA1:** and copy that value.

## My Recommendation

**Skip enabling Google Sign-In** and instead:
1. Go directly to Google Cloud Console
2. Manually create Android OAuth client
3. This is more direct and will definitely create the OAuth client

The empty `oauth_client` array is the issue, and manually creating the OAuth client will fix it.

