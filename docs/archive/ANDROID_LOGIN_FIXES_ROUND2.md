# Android Login Fixes - Round 2

Additional fixes based on runtime testing and error reports.

## Issues Fixed in Round 2

### 1. ✅ Source.cacheAndServer - Use Default Behavior Instead of Manual Fallback

**Problem:**
- Initial fix used manual cache-then-server fallback with try/catch
- User reported that `Source.cacheAndServer` was still being selected (likely from old code or caching)
- Manual fallback was more complex than needed

**Solution Applied:**
- Changed Android Firestore calls to omit `source` parameter entirely
- Firestore's default behavior (when no source is specified) is: try cache first, then server
- This is exactly what `Source.cacheAndServer` would do if it existed
- Simpler, more reliable, and uses the SDK's built-in behavior

**Code Change:**
```dart
// Before: Manual fallback with try/catch
try {
  userDoc = await userRef.get(GetOptions(source: Source.cache)).timeout(...);
  if (!userDoc.exists) {
    userDoc = await userRef.get(GetOptions(source: Source.server)).timeout(...);
  }
} catch (e) {
  userDoc = await userRef.get(GetOptions(source: Source.server)).timeout(...);
}

// After: Use default behavior
userDoc = await userRef.get().timeout(const Duration(seconds: 15));
```

**Files Changed:**
- `lib/services/auth_service.dart` (lines 59-75)

---

### 2. ✅ clearTasksTabIndex Called During Build - UI Crash Fix

**Problem:**
- `TasksScreen.initState()` was calling `appState.clearTasksTabIndex()` directly
- `clearTasksTabIndex()` calls `notifyListeners()` which triggers setState
- This happened during the build phase, causing "setState() or markNeedsBuild() called during build" error
- Same issue in `_onAppStateChanged()` callback

**Solution Applied:**
- Wrapped `appState.clearTasksTabIndex()` calls in `WidgetsBinding.instance.addPostFrameCallback()`
- This defers the state change until after the current build frame completes
- Prevents build-cycle violations

**Code Change:**
```dart
// Before: Called directly in initState
@override
void initState() {
  super.initState();
  appState.clearTasksTabIndex(); // ❌ setState during build
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadTasks(forceRefresh: true);
  });
}

// After: Deferred to post-frame
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    appState.clearTasksTabIndex(); // ✅ setState after build
    _loadTasks(forceRefresh: true);
  });
}
```

**Files Changed:**
- `lib/screens/tasks/tasks_screen.dart` (lines 55-65, 71-79)

---

### 3. ✅ Enhanced createdAt Parsing Error Handling

**Problem:**
- Initial fix handled Timestamp/String/DateTime but lacked error handling
- If DateTime.parse() failed on a malformed string, it would crash
- No logging to help debug schema issues

**Solution Applied:**
- Added try/catch around `DateTime.parse()` calls
- Added debug logging for unexpected types and parse failures
- Returns safe fallback (DateTime.now()) instead of crashing
- Applied to both `UserModel.fromJson()` and registration flow

**Code Change:**
```dart
DateTime parseCreatedAt(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      debugPrint('UserModel.fromJson: Error parsing createdAt string "$value": $e');
      return DateTime.now();
    }
  }
  debugPrint('UserModel.fromJson: Unexpected createdAt type: ${value.runtimeType}');
  return DateTime.now();
}
```

**Files Changed:**
- `lib/models/user_model.dart` (lines 71-77, added import for foundation)
- `lib/services/auth_service.dart` (registration flow already had error handling)

---

## Testing Status

### API Key Fix (User Action Required)
- ✅ User confirmed API key restrictions updated in Google Cloud Console
- Key `YOUR_FIREBASE_API_KEY` should now allow Android package `com.example.familyhub_mvp`
- Identity Toolkit API should be enabled

### Expected Results After These Fixes
1. ✅ No `Source.cacheAndServer` errors - using default Firestore behavior
2. ✅ No "setState during build" crashes in TasksScreen
3. ✅ No `createdAt` parsing errors - robust handling of Timestamp/String/DateTime
4. ✅ Firestore `[unavailable]` errors should disappear once API key is properly configured
5. ✅ Dashboard should load after successful login

---

## Next Steps

1. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run --debug -d <android-device>
   ```

2. **Monitor logs for:**
   - Firestore connection success (no more `[unavailable]` spam)
   - User document loading without Timestamp errors
   - No setState during build crashes
   - Successful dashboard load

3. **If Firestore still unavailable:**
   - Verify API key restrictions in Google Cloud Console
   - Check that Identity Toolkit API is enabled
   - Verify SHA-1 fingerprint is correct for the Android app
   - Check App Check settings (may need to disable for development)

---

## Files Modified in Round 2

- `lib/services/auth_service.dart` - Simplified Source usage to default behavior
- `lib/screens/tasks/tasks_screen.dart` - Fixed setState during build
- `lib/models/user_model.dart` - Enhanced error handling in createdAt parsing
- `ANDROID_LOGIN_FIXES_ROUND2.md` - This documentation

