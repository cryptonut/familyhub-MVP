# google-services.json File Location

## Path to Store the File

### Full Absolute Path:
```
C:\Users\simon\OneDrive\Desktop\familyhub-MVP\android\app\google-services.json
```

### Relative Path (from project root):
```
android/app/google-services.json
```

## Instructions

1. **Download** `google-services.json` from Firebase Console:
   - Go to: https://console.firebase.google.com/project/family-hub-71ff0/settings/general
   - Scroll to "Your apps" section
   - Find Android app: `com.example.familyhub_mvp`
   - Click gear icon or app name
   - Click "Download google-services.json"

2. **Replace** the existing file:
   - Copy the downloaded file
   - Paste it to: `android/app/google-services.json`
   - **Overwrite** the existing file

3. **Verify** the new file has OAuth clients:
   - Open the file
   - Look for `"oauth_client"` - should NOT be empty `[]`
   - Should have entries like:
     ```json
     "oauth_client": [
       {
         "client_id": "...",
         "client_type": 3
       }
     ]
     ```

4. **Rebuild** the app:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Current File Status

The current `google-services.json` has:
- ❌ Empty `oauth_client: []` array
- ✅ Correct API key: `YOUR_FIREBASE_API_KEY`
- ✅ Correct package name: `com.example.familyhub_mvp`

The empty `oauth_client` is likely causing the authentication timeout.

