# Test MainActivity Logging - Step by Step Guide

## Purpose
Verify that MainActivity.kt code is executing and the app verification workaround is working.

## Prerequisites
- App is built and installed (or building now)
- Device connected via USB
- ADB access (or use Flutter's built-in log viewing)

## Step 1: Clear Logcat

**Option A: Using ADB (if available)**
```powershell
adb logcat -c
```

**Option B: Using Flutter**
The logs will be visible in the Flutter run output.

## Step 2: Start App Fresh

1. **Completely close** the app if it's already running
2. **Start the app** fresh (not hot reload)
3. **Wait 5 seconds** for initialization

## Step 3: Capture Logs

### Option A: Using Flutter Run Output

If you ran `flutter run --flavor dev`, the logs should appear in the terminal. Look for:

```
═══════════════════════════════════════
MainActivity CLASS LOADED
═══════════════════════════════════════
```

```
═══════════════════════════════════════
MainActivity.onCreate() CALLED
═══════════════════════════════════════
```

```
═══════════════════════════════════════
✓✓✓ SUCCESS: App verification disabled - reCAPTCHA bypass enabled ✓✓✓
═══════════════════════════════════════
```

### Option B: Using ADB Logcat

**Find ADB path** (usually in Android SDK):
```powershell
# Common locations:
# C:\Users\<username>\AppData\Local\Android\Sdk\platform-tools\adb.exe
# Or check: flutter doctor -v
```

**Capture MainActivity logs**:
```powershell
# Replace path with your actual ADB path
& "C:\Users\simon\AppData\Local\Android\Sdk\platform-tools\adb.exe" logcat -s MainActivity:* *:E | Select-String -Pattern "MainActivity|reCAPTCHA|empty.*token"
```

**Or capture all logs and filter**:
```powershell
& "C:\Users\simon\AppData\Local\Android\Sdk\platform-tools\adb.exe" logcat -d | Select-String -Pattern "MainActivity|reCAPTCHA|empty.*token|═══════" | Select-Object -First 100
```

### Option C: Using Android Studio Logcat

1. Open Android Studio
2. Connect device
3. Open Logcat panel
4. Filter by: `MainActivity` or `tag:MainActivity`
5. Look for the markers: `═══════════════════════════════════════`

## Step 4: What to Look For

### ✅ Success Indicators

1. **Class Loading** (should appear immediately):
   ```
   MainActivity CLASS LOADED
   ```

2. **onCreate Called** (should appear on app start):
   ```
   MainActivity.onCreate() CALLED
   ```

3. **App Verification Disabled** (should appear within 3 seconds):
   ```
   ✓✓✓ SUCCESS: App verification disabled - reCAPTCHA bypass enabled ✓✓✓
   ```

4. **No reCAPTCHA Errors** (when attempting login):
   - Should NOT see: "empty reCAPTCHA token"
   - Login should complete in < 5 seconds

### ❌ Failure Indicators

1. **No MainActivity Logs**:
   - If you see NO logs with "MainActivity" tag
   - **Problem**: Code not executing or not compiled
   - **Next Step**: Check build output, verify MainActivity.kt is in the build

2. **Failed to Disable**:
   ```
   ✗✗✗ FAILED to disable app verification ✗✗✗
   ```
   - **Problem**: Firebase not initialized or method unavailable
   - **Next Step**: Check Firebase initialization timing

3. **Still See reCAPTCHA Error**:
   - If you see "empty reCAPTCHA token" after seeing success message
   - **Problem**: Workaround not effective or timing issue
   - **Next Step**: Check Firebase Auth initialization order

## Step 5: Test Authentication

After verifying MainActivity logs appear:

1. **Attempt login** with test credentials
2. **Monitor logs** for:
   - "empty reCAPTCHA token" (should NOT appear)
   - Login completion (should be < 5 seconds)
   - Any timeout errors

## Step 6: Compare with release/qa

If MainActivity logs appear but authentication still fails:

1. Build release/qa version:
   ```powershell
   flutter run --flavor qa --release -d RFCT61EGZEH
   ```

2. Capture logs from release/qa
3. Compare:
   - Do MainActivity logs appear in both?
   - Are there any differences in timing?
   - Are there differences in Firebase initialization?

## Troubleshooting

### No Logs Appear

**Check 1: Is MainActivity.kt in the build?**
```powershell
# Check if MainActivity.class exists in the APK
# (Requires unzip or Android Studio APK Analyzer)
```

**Check 2: Are logs being filtered?**
- Try unfiltered logcat: `adb logcat *:V`
- Check Flutter run output (not just errors)

**Check 3: Is the app actually using MainActivity?**
- Verify AndroidManifest.xml references `.MainActivity`
- Check if there are flavor-specific MainActivity files

### Logs Appear But Workaround Fails

**Check 1: Firebase Initialization Timing**
- Review `lib/main.dart` - when is Firebase initialized?
- Is it before or after MainActivity.onCreate()?

**Check 2: Method Availability**
- Check Firebase Auth version in `build.gradle.kts`
- Verify `setAppVerificationDisabledForTesting` exists in that version

**Check 3: SHA-1 Configuration**
- Verify SHA-1 for `com.example.familyhub_mvp.dev` is in Firebase Console
- Check if there's a separate Android app entry for dev flavor

## Expected Timeline

When app starts:
- **0ms**: MainActivity class loaded (companion object init)
- **~100ms**: MainActivity.onCreate() called
- **~200ms**: First disableAppVerification() attempt
- **~700ms**: Retry 1 (500ms delay)
- **~1700ms**: Retry 2 (1500ms delay)
- **~3200ms**: Retry 3 (3000ms delay)
- **Within 3 seconds**: Should see "SUCCESS: App verification disabled"

When login attempted:
- **0ms**: Login button pressed
- **~100ms**: Firebase signInWithEmailAndPassword called
- **< 5 seconds**: Login completes (no reCAPTCHA delay)

## Next Steps Based on Results

### If MainActivity Logs Appear AND Workaround Succeeds:
✅ **Problem Solved** - Workaround is working
- Proceed to configure reCAPTCHA properly for long-term solution
- Can keep workaround for development

### If MainActivity Logs Appear BUT Workaround Fails:
⚠️ **Timing or Configuration Issue**
- Check Firebase initialization order
- Verify SHA-1 for dev flavor
- Review API key restrictions

### If MainActivity Logs DON'T Appear:
❌ **Build/Compilation Issue**
- Verify MainActivity.kt is compiled
- Check for flavor-specific overrides
- Review build.gradle.kts configuration
- Compare with release/qa build process

## Quick Test Command

If you have ADB available, run this after starting the app:

```powershell
# One-liner to check for MainActivity logs
& "C:\Users\simon\AppData\Local\Android\Sdk\platform-tools\adb.exe" logcat -d | Select-String -Pattern "═══════|MainActivity.*CALLED|SUCCESS.*disabled|FAILED.*disable" | Select-Object -First 20
```

This will show:
- Class loading
- onCreate() calls
- Success/failure of app verification disable

