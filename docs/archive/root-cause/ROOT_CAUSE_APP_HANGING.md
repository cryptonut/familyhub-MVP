# Root Cause: App Hanging During Initialization

## Problem
The app builds successfully but hangs during startup. No Flutter/Dart logs appear in logcat, even though MainActivity is visible.

## Diagnosis
1. **App builds**: ✅ APK builds successfully
2. **App installs**: ✅ App installs on device
3. **MainActivity visible**: ✅ Native Android activity is running
4. **No Flutter logs**: ❌ Zero Flutter/Dart logs in logcat
5. **App hangs**: ❌ App never reaches `runApp()`

## Likely Hanging Points
Based on code analysis, the app could be hanging at:

1. **`Firebase.initializeApp()`** - Most likely
   - No timeout protection (was using 15 seconds)
   - Could hang indefinitely if:
     - API key restrictions block Firebase
     - Network issues
     - google-services.json missing/invalid
     - Firestore API not enabled

2. **`Hive.initFlutter()`** - Possible
   - File system operations
   - Could hang if storage permissions denied

3. **`setupServiceLocator()`** - Possible
   - Service registration
   - Could hang if dependency injection fails

## Fixes Applied
1. ✅ Added immediate `print()` statements at startup
2. ✅ Reduced Firebase init timeout to 10 seconds
3. ✅ Added timeout protection to Hive init (5 seconds)
4. ✅ Added timeout protection to service locator (5 seconds)
5. ✅ Added error handling to continue even if optional services fail

## Next Steps
1. Run the app and check for print statements in logcat
2. Identify which initialization step is hanging
3. Fix the root cause (likely API key restrictions or missing config)

## How to Check Logs
```bash
# Filter for our debug prints
adb logcat | grep -E "APP STARTING|Firebase|Hive|Service locator|TIMEOUT|FAILED"
```

Or in Android Studio logcat, filter by: `flutter` or `com.example.familyhub_mvp.dev`

