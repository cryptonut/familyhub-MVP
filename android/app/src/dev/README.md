# Dev Environment Setup

## Firebase Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click the gear icon ⚙️ → **Project settings**
4. Scroll to **Your apps** section
5. Click **Add app** → **Android**
6. Register with:
   - **Package name**: `com.example.familyhub_mvp.dev`
   - **App nickname**: FamilyHub Dev (optional)
7. Download `google-services.json`
8. Place it in this directory: `android/app/src/dev/google-services.json`

## Notes

- Dev environment uses separate Firebase app registration
- Data is prefixed with `dev_` in Firestore
- Logging is always enabled
- Crash reporting is disabled

