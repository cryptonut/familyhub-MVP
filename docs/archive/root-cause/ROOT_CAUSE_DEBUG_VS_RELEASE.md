# Root Cause: Debug vs Release Build Issue

## Critical Finding from Logcat

**Line 80162**: `"Error getting App Check token; using placeholder token instead. Error: com.google.firebase.FirebaseException: No AppCheckProvider installed."`

**Line 80027**: `"Logging in as Simoncase78@gmail.com with empty reCAPTCHA token"`

**Line 99917**: `"TIMEOUT: Firebase Auth hung"`

## The Problem

1. **App Check is NOT initialized** in release/qa branch (it's commented out in `lib/main.dart`)
2. **Firebase Auth tries to get App Check token** → fails with "No AppCheckProvider installed"
3. **Firebase Auth falls back to reCAPTCHA** → fails with "empty reCAPTCHA token"
4. **30-second timeout** → authentication fails

## Why Release Build Works But Debug Build Fails

### Release Build (via App Installer):
- Uses **release signing key** (different SHA-1)
- May have different Firebase configuration
- App Check might not be enforced
- Network requests might be handled differently

### Debug Build (via USB):
- Uses **debug signing key** (SHA-1: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`)
- Firebase Auth tries to use App Check (even though it's disabled in code)
- App Check fails → falls back to reCAPTCHA → fails

## The Solution

### Option 1: Properly Initialize App Check (Recommended)
Enable App Check in `lib/main.dart` and ensure debug token is registered:

```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: AndroidProvider.debug,
  appleProvider: AppleProvider.debug,
);
```

Then register the debug token in Firebase Console.

### Option 2: Disable App Check Enforcement in Firebase Console
1. Go to Firebase Console > App Check
2. Set enforcement to **"Monitoring"** (not "Enforced")
3. This allows requests without App Check tokens

### Option 3: Ensure MainActivity Workaround Works
The `setAppVerificationDisabledForTesting(true)` should bypass reCAPTCHA, but it's not working. Need to verify:
- MainActivity.onCreate() is being called
- The workaround is executing successfully
- Firebase Auth is respecting the disabled verification

## Immediate Action

Since release/qa works via app installer, the issue is specific to **debug builds via USB**. The solution is to either:
1. Test with release build via USB: `flutter run --release --flavor qa -d RFCT61EGZEH`
2. OR properly configure App Check for debug builds
3. OR verify MainActivity workaround is working in debug builds

