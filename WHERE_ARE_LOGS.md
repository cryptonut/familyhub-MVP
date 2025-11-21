# Where to Find Logs

## Terminal Logs (Flutter)
The logs you see in the terminal when running `flutter run` are Flutter/Dart logs.

## Android Logcat (More Detailed)
Android has its own logging system that shows more detail, including Firebase SDK internal logs.

### Option 1: Use Android Studio
1. Open Android Studio
2. Connect your device
3. Go to **View** > **Tool Windows** > **Logcat**
4. Filter by: `flutter` or `FirebaseAuth`

### Option 2: Use ADB from Terminal
```bash
# See all logs
adb logcat

# Filter for Flutter/Firebase
adb logcat | grep -i "flutter\|firebase"

# Save logs to file
adb logcat > android_logs.txt
```

### Option 3: Use Flutter's Built-in Log Viewer
When running `flutter run`, press:
- `v` - verbose logging
- `V` - very verbose logging

## What to Look For
After our changes, look for:
- `AuthService: ✓ Firebase Auth succeeded` (success)
- `FirebaseAuthException` (actual Firebase error)
- Any errors from `FirebaseAuth` or `identitytoolkit`

The Android logcat will show Firebase SDK internal errors that Flutter logs might miss.

