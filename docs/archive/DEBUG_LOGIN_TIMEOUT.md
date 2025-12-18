# Debug Login Timeout Issue

## Quick Fix Steps

Since the GitHub release/qa branch works fine, this is likely a **build cache issue**.

### Step 1: Clean Build
```bash
flutter clean
flutter pub get
flutter run --flavor dev --dart-define=FLAVOR=dev
```

### Step 2: If Still Failing - Check Build Type
The working APK might be a **release** build. Try:
```bash
flutter build apk --flavor dev --dart-define=FLAVOR=dev --release
```

Then install the APK manually.

### Step 3: Check Device Logs
Connect device and check logs:
```bash
# On Windows, use Flutter's built-in logging
flutter run --flavor dev --dart-define=FLAVOR=dev --verbose
```

Look for:
- "empty reCAPTCHA token" messages
- Network errors
- Firebase initialization errors
- Timeout messages

### Step 4: Compare Builds
The GitHub release/qa APK that works - was it:
- Debug or Release build?
- Built with `flutter build apk` or `flutter run`?
- Installed via ADB or manually?

### Step 5: Rebuild from Scratch
If cache clean doesn't work:
```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run --flavor dev --dart-define=FLAVOR=dev
```

## Most Likely Cause

Since code is identical to working branch, this is **99% a build cache issue**. The clean build should fix it.

