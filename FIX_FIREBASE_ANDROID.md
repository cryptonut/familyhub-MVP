# Fix Firebase Android Connection Issues

## Problem
Your app is launching but Firebase services are failing with `DEVELOPER_ERROR`. This is because your debug SHA-1 fingerprint is not registered in Firebase Console.

## Solution: Add SHA-1 Fingerprint to Firebase

### Your Debug SHA-1 Fingerprint:
```
BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C
```

### Steps to Fix:

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/
   - Select your project: **family-hub-71ff0**

2. **Navigate to Project Settings**
   - Click the gear icon ⚙️ next to "Project Overview"
   - Select **Project settings**

3. **Add SHA-1 Fingerprint**
   - Scroll down to **Your apps** section
   - Find your Android app: `com.example.familyhub_mvp`
   - Click **Add fingerprint** (or the pencil icon to edit)
   - Paste your SHA-1: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
   - Click **Save**

4. **Download Updated google-services.json** (Optional)
   - After adding the SHA-1, you may need to download a new `google-services.json`
   - However, the existing one should work once the SHA-1 is registered
   - If you download a new one, replace `android/app/google-services.json`

5. **Rebuild and Reinstall the App**
   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

## Why This Happens

Firebase requires SHA-1 fingerprints to verify that your app is authorized to use Firebase services. This is a security measure to prevent unauthorized access.

## Additional Notes

- **Debug vs Release**: This SHA-1 is for debug builds. For release builds, you'll need to add your release keystore's SHA-1 separately.
- **Multiple Devices**: If you're testing on multiple computers/devices, each may have a different debug keystore SHA-1. Add all of them.
- **Wait Time**: After adding the SHA-1, it may take a few minutes for Firebase to propagate the changes.

## Verify It's Working

After adding the SHA-1 and rebuilding:
- The `DEVELOPER_ERROR` should disappear
- Firebase services (Auth, Firestore) should connect successfully
- You should see successful connection logs instead of errors

## If Issues Persist

1. **Check Package Name**: Ensure your package name in Firebase Console matches `com.example.familyhub_mvp`
2. **Check google-services.json**: Verify it's in `android/app/google-services.json`
3. **Check Build Configuration**: Ensure Google Services plugin is applied in `android/app/build.gradle.kts`
4. **Clear App Data**: Uninstall the app from your device and reinstall
5. **Check Internet Connection**: Ensure your device has internet connectivity

