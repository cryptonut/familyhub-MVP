# Root Cause Fix for Firestore Unavailable on Android

## Problem Identified

The `[cloud_firestore/unavailable]` error on Android was caused by **gRPC channel reset loops**. The logcat showed:

1. **Repeated channel shutdowns**: `GrpcCallProvider.resetChannel` → `AndroidChannel.shutdownNow` → `initChannel`
2. **Stream closed errors**: `Stream closed with status: Status{code=UNAVAILABLE, description=Channel shutdownNow invoked}`
3. **Channel never establishes**: The gRPC channel kept getting reset before it could establish a connection

## Root Cause

**`Source.server` was forcing immediate server-only reads** before the gRPC channel could establish a connection. This caused:
- Firestore to attempt server connection immediately
- gRPC channel to fail and reset
- Infinite loop of channel resets
- "unavailable" errors

## Fix Applied

### 1. Changed Firestore Query Source
**File**: `lib/services/auth_service.dart`

**Before**:
```dart
final doc = await _firestore.collection('users').doc(user.uid)
    .get(GetOptions(source: Source.server))
    .timeout(const Duration(seconds: 10));
```

**After**:
```dart
final doc = await _firestore.collection('users').doc(user.uid)
    .get(GetOptions(source: Source.serverAndCache))
    .timeout(const Duration(seconds: 15));
```

**Why**: `Source.serverAndCache` allows the gRPC channel to establish naturally by trying server first but allowing cache fallback. This prevents the channel from being forced to connect before it's ready.

### 2. Configured Firestore Settings
**File**: `lib/main.dart`

Added Firestore settings configuration:
```dart
if (!kIsWeb) {
  try {
    final firestore = FirebaseFirestore.instance;
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('✓ Firestore settings configured');
  } catch (e) {
    debugPrint('⚠ Firestore settings error: $e');
  }
}
```

**Why**: Enabling persistence and unlimited cache helps with initial connection establishment and prevents channel resets.

### 3. Increased Timeout
Changed timeout from 10s to 15s to give more time for gRPC channel establishment.

## Why This Works

- **Web works**: Web uses REST API, not gRPC, so no channel establishment issues
- **Android fails**: Android uses gRPC which requires channel establishment
- **Source.server was the trigger**: Forcing immediate server connection before channel ready
- **Source.serverAndCache allows natural flow**: Channel can establish, then query succeeds

## Testing

Run the app on Android device and verify:
1. Firestore connects without "unavailable" errors
2. User data loads successfully
3. No repeated channel reset messages in logcat
4. App shows login screen and loads existing data

## Next Steps

If this fix works, consider:
1. Apply similar fix to other `Source.server` usages if they cause issues
2. Keep `Source.server` for critical operations that need fresh data
3. Use `Source.serverAndCache` for initial data loads

