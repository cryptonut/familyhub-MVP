# Formal Investigation: Authentication Timeout Issue

## Problem Statement
Login requests are timing out after 30 seconds. The GitHub release/qa branch works fine, indicating this is a code change issue, not a Firebase/API configuration problem.

## Investigation Findings

### 1. Recent Changes Analysis
**Modified Files:**
- `lib/main.dart` - Added CacheService initialization
- `lib/services/cache_service.dart` - NEW FILE - Uses Hive and `getApplicationDocumentsDirectory()`

### 2. Root Cause Identified

**Issue:** `CacheService.initialize()` calls `getApplicationDocumentsDirectory()` which can **block the main thread on Android**, especially on first run or when file system access is slow.

**Why This Affects Auth:**
- Even though CacheService is initialized in a `Future.microtask()`, if `getApplicationDocumentsDirectory()` blocks or takes too long, it can interfere with Firebase Auth's network operations
- On Android, accessing the application documents directory can require file system locks that block other I/O operations
- This is a known issue with `path_provider` on Android

### 3. Solution

**Fix:** Make CacheService initialization truly non-blocking and add proper error handling to prevent it from interfering with Firebase Auth.

**Changes Required:**
1. Add a lock to prevent multiple simultaneous initialization attempts
2. Make initialization completely fire-and-forget
3. Add better error handling to prevent exceptions from propagating
4. Ensure CacheService never blocks the main thread

## Implementation Plan

1. Update `CacheService.initialize()` to be truly non-blocking
2. Add initialization lock to prevent race conditions
3. Wrap file system operations in try-catch to prevent blocking
4. Test authentication flow to ensure no interference

