# Root Cause Fix: gRPC Channel Reset Loop from Race Condition

## Actual Root Cause Identified

The persistent `[cloud_firestore/unavailable]` error with `SecurityException: Unknown calling package name 'com.google.android.gms'` and `ConnectionResult{statusCode=DEVELOPER_ERROR}` is **NOT** caused by API key restrictions.

**The real root cause is a race condition:**
- Multiple widgets/services call `getCurrentUserModel()` simultaneously on app startup
- Each query tries to initialize the gRPC channel at the same time
- This causes the channel to reset in a loop: `initChannel -> shutdownNow -> initChannel -> shutdownNow`
- The channel never stabilizes, causing all Firestore queries to fail with "unavailable"

## Evidence from Logs

Looking at `app_run_logs.txt`, you can see:
- Multiple "Waiting for gRPC channel to initialize..." messages within milliseconds (lines 40, 44, 48, 55, 59, 63, 67, 71, 76)
- "Channel shutdownNow invoked" errors repeating
- All happening simultaneously, indicating concurrent queries

## The Fix (Implemented in Code)

### 1. Query Deduplication ✅
- If multiple calls to `getCurrentUserModel()` happen for the same user simultaneously, they now share the same query
- Only ONE Firestore query executes, others wait for the result

### 2. Result Caching ✅
- Results are cached so subsequent calls return immediately without querying Firestore
- Cache is cleared on sign out or when user changes

### 3. Synchronized Channel Initialization ✅
- Only ONE query initializes the gRPC channel at a time
- Other queries wait if channel initialization is in progress
- Recent channel initialization (within 2 seconds) is reused to avoid unnecessary delays

## Code Changes Made

**File: `lib/services/auth_service.dart`**

1. Added query deduplication:
   ```dart
   static final Map<String, Future<UserModel?>> _pendingUserModelQueries = <String, Future<UserModel?>>{};
   ```

2. Added result caching:
   ```dart
   static UserModel? _cachedUserModel;
   static String? _cachedUserId;
   ```

3. Added synchronized channel initialization:
   ```dart
   static bool _isInitializingChannel = false;
   static DateTime? _lastChannelInitTime;
   ```

4. Modified `getCurrentUserModel()` to:
   - Check cache first
   - Reuse in-progress queries
   - Track pending queries to prevent duplicates

5. Modified channel initialization to:
   - Wait if another query is initializing
   - Skip wait if channel was recently initialized

## Testing

After this fix:
1. **Rebuild the app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run --flavor dev
   ```

2. **Expected results:**
   - ✅ No more "Channel shutdownNow invoked" errors
   - ✅ No more multiple simultaneous "Waiting for gRPC channel" messages
   - ✅ Firestore queries succeed
   - ✅ User data loads successfully
   - ✅ Only ONE query executes even if multiple widgets call `getCurrentUserModel()`

3. **Check logs for:**
   - "Query already in progress for {uid}, waiting for existing query..." (indicates deduplication working)
   - "Returning cached user model for {uid}" (indicates caching working)
   - "gRPC channel recently initialized, skipping wait" (indicates synchronization working)
   - No repeated "Channel shutdownNow" errors

## Why This Fixes the Issue

**Before:**
- Widget A calls `getCurrentUserModel()` → starts gRPC channel init
- Widget B calls `getCurrentUserModel()` → starts another gRPC channel init
- Widget C calls `getCurrentUserModel()` → starts yet another gRPC channel init
- All three try to use the channel → channel resets → unavailable error

**After:**
- Widget A calls `getCurrentUserModel()` → starts gRPC channel init
- Widget B calls `getCurrentUserModel()` → waits for Widget A's query
- Widget C calls `getCurrentUserModel()` → waits for Widget A's query
- Widget A completes → all three get the same result → channel stable → success

## Additional Benefits

1. **Performance**: Cached results return instantly
2. **Reduced Firestore reads**: Only one query per user session
3. **Stability**: No more channel reset loops
4. **Cost**: Fewer Firestore operations = lower costs

## If Issues Persist

If you still see errors after this fix, check:

1. **Network connectivity**: Ensure device has internet
2. **Firestore rules**: Verify rules allow reading user documents
3. **Firebase project**: Ensure project is active and not suspended
4. **Logs**: Look for any new error patterns

But the race condition fix should resolve the "unavailable" errors you were seeing.
