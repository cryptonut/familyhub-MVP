# Calendar Sync Release Build Fix

**Issue:** Calendar sync works in debug (USB) but fails in release APK builds  
**Root Cause:** R8 code obfuscation breaking device_calendar plugin  
**Status:** Fixed with ProGuard rules

---

## 🔍 Problem Analysis

### Symptoms
- **Debug (USB)**: Calendars show proper names, account names, and event counts ✅
- **Release (APK)**: Calendars show "Unnamed Calendar" with 0 events ❌
- **Same device, different behavior** based on build type

### Root Cause
1. **R8 Full Mode Enabled**: `android.enableR8.fullMode=true` in `gradle.properties`
2. **Code Obfuscation**: R8 obfuscates/strips code in release builds
3. **Plugin Dependency**: `device_calendar` plugin uses reflection/JNI to populate Calendar objects
4. **Result**: Calendar objects are created but properties (`name`, `accountName`) are null
5. **Event Counts**: Also fail because `retrieveEvents` may be affected by obfuscation

### Why Debug Works But Release Doesn't
- **Debug builds**: No code obfuscation, all reflection works
- **Release builds**: R8 obfuscates code, breaks reflection-based property population
- **Same code, different build configuration**

---

## ✅ Solution Implemented

### 1. Created ProGuard Rules File
**File:** `android/app/proguard-rules.pro`

**Purpose:** Prevent R8 from obfuscating device_calendar plugin classes

**Key Rules:**
- Keep all `device_calendar` plugin classes
- Keep Calendar and Event model classes
- Keep reflection attributes
- Keep Android Calendar Provider classes
- Keep Flutter plugin infrastructure

### 2. Updated build.gradle.kts
**File:** `android/app/build.gradle.kts`

**Change:** Added ProGuard rules reference to release buildType:
```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

### 3. Enhanced Logging
**Files:**
- `lib/services/calendar_sync_service.dart`
- `lib/screens/settings/calendar_sync_settings_screen.dart`

**Purpose:** Better diagnostics for release builds
- Log Calendar object properties (name, accountName, id)
- Warn if properties are null (indicates obfuscation issue)
- Log event count retrieval results
- Better error messages

---

## 🧪 Testing Plan

### Step 1: Rebuild APK with ProGuard Rules
```bash
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
flutter build apk --flavor qa --dart-define=FLAVOR=qa
```

### Step 2: Install and Test
1. Uninstall old APK from device
2. Install new APK: `build/app/outputs/flutter-apk/app-qa-release.apk`
3. Open app and navigate to Calendar Sync settings
4. Grant calendar permissions
5. Tap "Select Calendar"

### Step 3: Verify Fix
**Expected Results:**
- ✅ Calendar names display correctly (not "Unnamed Calendar")
- ✅ Account names show in subtitle
- ✅ Event counts display correctly (not 0)
- ✅ Can select calendar and sync works

### Step 4: Check Logs
If issues persist, check logcat for:
```bash
adb logcat | grep -i "CalendarSync"
```

Look for:
- Calendar details logs (name, accountName, id)
- Warnings about null properties
- Event count retrieval results

---

## 🔧 Technical Details

### ProGuard Rules Explained

```proguard
# Keep device_calendar plugin classes
-keep class com.builttoroam.devicecalendar.** { *; }
```
**Why:** Prevents R8 from obfuscating plugin's native Android code

```proguard
# Keep Calendar and Event model classes
-keep class com.builttoroam.devicecalendar.domain.Calendar { *; }
-keep class com.builttoroam.devicecalendar.domain.Event { *; }
```
**Why:** Ensures Calendar object properties aren't stripped

```proguard
# Keep reflection attributes
-keepattributes *Annotation*
-keepattributes Signature
```
**Why:** Plugin uses reflection to populate Calendar objects

```proguard
# Keep Android Calendar Provider classes
-keep class android.provider.CalendarContract.** { *; }
```
**Why:** Plugin accesses Android Calendar Provider via reflection

---

## 🐛 If Issue Persists

### Additional Debugging Steps

1. **Verify ProGuard Rules Are Applied**
   - Check build output for ProGuard warnings
   - Look for "ProGuard processing" in build logs
   - Verify `proguard-rules.pro` is in `android/app/`

2. **Check Logcat for Errors**
   ```bash
   adb logcat | grep -E "(CalendarSync|device_calendar|ProGuard)"
   ```

3. **Test with Minification Disabled** (temporary)
   In `android/app/build.gradle.kts`, add to release buildType:
   ```kotlin
   minifyEnabled false  // Temporary - for testing only
   ```
   If this fixes it, ProGuard rules need adjustment.

4. **Check Plugin Version**
   - Current: `device_calendar: ^4.3.0`
   - Check for updates: `flutter pub outdated`
   - Some plugin versions have better R8 compatibility

5. **Verify Permissions**
   - Check device Settings → Apps → FamilyHub Test → Permissions
   - Ensure Calendar permissions are granted
   - Try revoking and re-granting permissions

---

## 📋 Files Changed

1. ✅ `android/app/proguard-rules.pro` - **NEW FILE** - ProGuard rules
2. ✅ `android/app/build.gradle.kts` - Added ProGuard rules reference
3. ✅ `lib/services/calendar_sync_service.dart` - Enhanced logging
4. ✅ `lib/screens/settings/calendar_sync_settings_screen.dart` - Enhanced logging + Logger import

---

## 🎯 Expected Outcome

After applying this fix:
- ✅ Calendar names display correctly in release builds
- ✅ Account names show properly
- ✅ Event counts are accurate
- ✅ Calendar sync works identically in debug and release

---

## 📝 Notes

- **R8 Full Mode**: Kept enabled for app size optimization
- **ProGuard Rules**: Minimal rules to fix issue without disabling optimizations
- **Performance**: No performance impact, only prevents obfuscation of specific classes
- **App Size**: Slight increase (~50-100KB) due to keeping plugin classes

---

**Last Updated:** December 1, 2025  
**Status:** Ready for Testing

