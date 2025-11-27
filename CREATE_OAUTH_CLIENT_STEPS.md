# Create OAuth Client for Android

## What You're Seeing

The OAuth overview page shows: **"You haven't configured any OAuth clients for this project yet."**

This confirms the issue - no OAuth clients exist, which is why `oauth_client` is empty in `google-services.json`.

## What to Do

### Click "Create OAuth client" Button

1. **Click the blue "Create OAuth client" button** on the right side of the alert

2. **Select Application type**: Choose **"Android"**

3. **Fill in the details**:
   - **Name**: `Family Hub Android` (or any name)
   - **Package name**: `com.example.familyhub_mvp`
   - **SHA-1 certificate fingerprint**: Your debug SHA-1
     - Get it with: `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android`
     - Look for the "SHA1:" value

4. **Click "Create"**

### Alternative: Let Firebase Auto-Create

If you prefer to let Firebase handle it automatically:

1. **Go back to Firebase Console** instead
2. Go to [Firebase Console > Project Settings](https://console.firebase.google.com/project/family-hub-71ff0/settings/general)
3. Under "Your apps", find your Android app
4. Make sure SHA-1 is registered
5. Wait 5-10 minutes
6. Re-download `google-services.json`

Firebase will auto-create OAuth clients once the OAuth consent screen is configured (which you just did).

## Recommended Approach

**Option 1 (Easier)**: Wait for Firebase to auto-generate
- You just configured OAuth consent screen
- Firebase should auto-create OAuth clients within 5-10 minutes
- Just re-download `google-services.json` from Firebase Console

**Option 2 (Faster)**: Manually create OAuth client here
- Click "Create OAuth client"
- Select Android
- Enter package name and SHA-1
- Create it

## After Creating

1. Wait a few minutes
2. Go to Firebase Console
3. Download fresh `google-services.json`
4. Check if `oauth_client` is now populated
5. Rebuild app: `flutter clean && flutter pub get && flutter run`

