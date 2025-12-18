# Timing Fix: Ensure MainActivity Workaround Completes Before Firebase Auth Access

## Problem Identified

The workaround code in `MainActivity.kt` IS executing and reporting SUCCESS, but Firebase Auth is still trying to use reCAPTCHA. This suggests a **timing issue**:

1. `Firebase.initializeApp()` is called in `main.dart`
2. `FirebaseAuth.instance` is accessed immediately after (line 142)
3. This **initializes Firebase Auth** before MainActivity workaround completes
4. Once Firebase Auth is initialized, the workaround can't change its settings

## Solution

Added a **500ms delay** before accessing `FirebaseAuth.instance` in `main.dart` to ensure MainActivity workaround completes first.

### Why 500ms?

MainActivity workaround retries at:
- 0ms (immediate)
- 500ms (first retry)
- 1500ms (second retry)
- 3000ms (third retry)

By waiting 500ms, we ensure at least the first retry completes before Firebase Auth is initialized.

## Changes Made

**File**: `lib/main.dart` (lines 139-145)

**Before**:
```dart
firebaseInitialized = true;
Logger.info('✓ Firebase initialized for Android/iOS platform', tag: 'main');

// Verify Firebase Auth is accessible
try {
  final auth = FirebaseAuth.instance;
```

**After**:
```dart
firebaseInitialized = true;
Logger.info('✓ Firebase initialized for Android/iOS platform', tag: 'main');

// CRITICAL: Wait for MainActivity.onCreate() to complete and disable app verification
// MainActivity runs the workaround to disable reCAPTCHA with retries at 500ms, 1500ms, 3000ms
// We need to ensure it completes before we access FirebaseAuth.instance (which initializes Auth)
if (!kIsWeb) {
  Logger.debug('Waiting for MainActivity workaround to complete (500ms delay)...', tag: 'main');
  await Future.delayed(const Duration(milliseconds: 500));
  Logger.debug('MainActivity workaround should have completed by now', tag: 'main');
}

// Verify Firebase Auth is accessible
try {
  final auth = FirebaseAuth.instance;
```

## Why This Should Work

1. **MainActivity.onCreate()** runs when the app starts (Android native)
2. **Workaround executes** immediately and at 500ms retry
3. **Flutter main()** runs after MainActivity is created
4. **500ms delay** ensures workaround completes before Firebase Auth initialization
5. **Firebase Auth** is initialized with app verification already disabled

## Testing

After this change:
1. Rebuild app: `flutter clean && flutter run --flavor dev`
2. Check logcat for:
   - "MainActivity.onCreate() CALLED"
   - "✓✓✓ SUCCESS: App verification disabled"
   - "Waiting for MainActivity workaround to complete (500ms delay)..."
   - "MainActivity workaround should have completed by now"
3. Test login - should complete in < 5 seconds without reCAPTCHA error

## If Still Failing

If authentication still fails:
1. Increase delay to 1500ms (second retry)
2. Or check if there's another place accessing FirebaseAuth.instance earlier
3. Compare with release/qa branch to see if there are other differences

