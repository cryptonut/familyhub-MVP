# Flavor Configuration Issue - Root Cause Found!

## The Problem

**You're running with `--flavor dev` but the working release/qa build uses `--flavor qa`!**

### Package Names:
- **dev flavor**: `com.example.familyhub_mvp.dev`
- **qa flavor**: `com.example.familyhub_mvp.test` ✅ (This is what works!)

### What Happened:
1. The working release/qa build uses **qa flavor** → package `com.example.familyhub_mvp.test`
2. You're testing with **dev flavor** → package `com.example.familyhub_mvp.dev`
3. These are **different Firebase apps** with different configurations!

## The Solution

### Option 1: Test with qa flavor (Quick Fix)
```bash
flutter run --flavor qa -d RFCT61EGZEH
```

This matches what the working release/qa build uses.

### Option 2: Configure Firebase for dev flavor (Proper Fix)

The `com.example.familyhub_mvp.dev` package needs:
1. **SHA-1 fingerprint** registered in Firebase Console
2. **App Check** configured (if using it)
3. **OAuth client** properly set up

**Steps:**
1. Go to Firebase Console > Project Settings
2. Find or add Android app with package: `com.example.familyhub_mvp.dev`
3. Add SHA-1: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
4. Download new `google-services.json` if needed
5. Replace `android/app/src/dev/google-services.json`

## Why This Matters

Each flavor uses a different package name, which Firebase treats as a **completely different app**. The dev flavor might not have the same Firebase configuration as the qa flavor.

## Recommendation

**Test with qa flavor first** to confirm it works, then we can configure dev flavor properly if needed.

