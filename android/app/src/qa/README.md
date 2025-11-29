# Test Environment Setup

## Firebase Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click the gear icon ⚙️ → **Project settings**
4. Scroll to **Your apps** section
5. Click **Add app** → **Android**
6. Register with:
   - **Package name**: `com.example.familyhub_mvp.test`
   - **App nickname**: FamilyHub Test (optional)
7. Download `google-services.json`
8. Place it in this directory: `android/app/src/test/google-services.json`

## Notes

- Test environment uses separate Firebase app registration
- Data is prefixed with `test_` in Firestore
- Logging is enabled for debugging
- Crash reporting is enabled to catch issues

