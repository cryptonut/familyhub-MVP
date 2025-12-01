# iOS Setup & Testing Plan - FamilyHub MVP

**Date:** December 1, 2025  
**Branch:** `develop`  
**Status:** Planning Phase

---

## 📋 Overview

This document outlines the complete plan to get FamilyHub MVP running on iOS devices for testing. The app currently has Android implementation complete, but iOS requires additional configuration.

---

## 🔍 Current iOS Implementation Review

### ✅ What's Already in Place

1. **Basic iOS Project Structure**
   - ✅ `ios/Runner/` directory exists
   - ✅ `AppDelegate.swift` configured
   - ✅ `Info.plist` exists with basic configuration
   - ✅ Xcode project files present
   - ✅ App icons configured (all sizes present)

2. **Flutter Dependencies**
   - ✅ All required packages support iOS
   - ✅ `device_calendar` - iOS compatible
   - ✅ `geolocator` - iOS compatible
   - ✅ `image_picker` - iOS compatible
   - ✅ `permission_handler` - iOS compatible
   - ✅ `firebase_core`, `firebase_auth`, `cloud_firestore` - iOS compatible

3. **Bundle Configuration**
   - ✅ Bundle ID: `com.example.familyhubMvp` (set in Info.plist)
   - ✅ Display Name: "Familyhub Mvp"

### ❌ What's Missing

1. **Firebase iOS Configuration**
   - ❌ `GoogleService-Info.plist` file missing
   - ❌ Firebase iOS app not registered in Firebase Console
   - ❌ `firebase_options.dart` has dummy values for iOS

2. **iOS Permissions (Info.plist)**
   - ❌ `NSCalendarsUsageDescription` - Required for calendar sync
   - ❌ `NSCalendarsWriteOnlyUsageDescription` - Required for calendar sync
   - ❌ `NSPhotoLibraryUsageDescription` - Required for photo uploads
   - ❌ `NSPhotoLibraryAddUsageDescription` - Required for saving photos
   - ❌ `NSCameraUsageDescription` - Required for camera access
   - ❌ `NSLocationWhenInUseUsageDescription` - Required for location sharing
   - ❌ `NSLocationAlwaysUsageDescription` - Optional, for background location
   - ❌ `NSMicrophoneUsageDescription` - Required for voice messages/video calls

3. **Xcode Project Configuration**
   - ❓ Signing & Capabilities not verified
   - ❓ Deployment target version not verified
   - ❓ CocoaPods dependencies not verified

4. **iOS-Specific Features**
   - ❓ Background modes (for calendar sync)
   - ❓ Push notification capabilities
   - ❓ App Transport Security settings

---

## 🎯 Implementation Plan

### Phase 1: Firebase iOS Setup (CRITICAL - Required First)

**Estimated Time:** 30-45 minutes

#### Step 1.1: Register iOS App in Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Click **Add app** → Select **iOS** icon
4. Register app with:
   - **Bundle ID**: `com.example.familyhubMvp` (must match Info.plist)
   - **App nickname**: "FamilyHub iOS" (optional)
   - **App Store ID**: Leave blank (for now)
5. Click **Register app**

#### Step 1.2: Download GoogleService-Info.plist
1. Download the `GoogleService-Info.plist` file
2. **DO NOT** add it to Xcode yet (we'll do this in Phase 2)
3. Save it temporarily (we'll place it in `ios/Runner/`)

#### Step 1.3: Update firebase_options.dart
1. Open `lib/firebase_options.dart`
2. Extract values from `GoogleService-Info.plist`:
   - `API_KEY` → `apiKey`
   - `GCM_SENDER_ID` → `messagingSenderId`
   - `PROJECT_ID` → `projectId`
   - `STORAGE_BUCKET` → `storageBucket`
   - `GOOGLE_APP_ID` → `appId`
   - `BUNDLE_ID` → `iosBundleId` (should match)
3. Update the `ios` section with real values
4. Update the `macos` section with same values (if needed)

**Expected Result:**
```dart
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSy...', // Real API key from GoogleService-Info.plist
  appId: '1:559662117534:ios:...', // Real App ID
  messagingSenderId: '559662117534',
  projectId: 'family-hub-71ff0',
  storageBucket: 'family-hub-71ff0.firebasestorage.app',
  iosBundleId: 'com.example.familyhubMvp',
);
```

---

### Phase 2: iOS Permissions Configuration

**Estimated Time:** 15-20 minutes

#### Step 2.1: Add Permission Descriptions to Info.plist

Open `ios/Runner/Info.plist` and add these keys **before** the closing `</dict>` tag:

```xml
<!-- Calendar Permissions -->
<key>NSCalendarsUsageDescription</key>
<string>FamilyHub needs access to your calendar to sync events between the app and your device calendar.</string>
<key>NSCalendarsWriteOnlyUsageDescription</key>
<string>FamilyHub needs write access to create and update calendar events on your device.</string>

<!-- Photo Library Permissions -->
<key>NSPhotoLibraryUsageDescription</key>
<string>FamilyHub needs access to your photos to upload images to events and photo albums.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>FamilyHub needs permission to save photos to your library.</string>

<!-- Camera Permission -->
<key>NSCameraUsageDescription</key>
<string>FamilyHub needs camera access to take photos for events and photo albums.</string>

<!-- Location Permissions -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>FamilyHub needs your location to share your whereabouts with family members and show your location on the map.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>FamilyHub needs your location in the background to provide real-time location sharing with family members.</string>

<!-- Microphone Permission -->
<key>NSMicrophoneUsageDescription</key>
<string>FamilyHub needs microphone access for voice messages and video calls with family members.</string>
```

**Why These Permissions:**
- **Calendar**: Required for `device_calendar` plugin (calendar sync feature)
- **Photos**: Required for `image_picker` plugin (photo uploads, event photos)
- **Camera**: Required for `image_picker` plugin (taking photos)
- **Location**: Required for `geolocator` plugin (location sharing feature)
- **Microphone**: Required for `record` plugin (voice messages) and `agora_rtc_engine` (video calls)

---

### Phase 3: Xcode Project Configuration

**Estimated Time:** 20-30 minutes

#### Step 3.1: Open Project in Xcode
```bash
cd ios
open Runner.xcworkspace
```
**Note:** Use `.xcworkspace`, NOT `.xcodeproj` (required for CocoaPods)

#### Step 3.2: Add GoogleService-Info.plist to Xcode
1. In Xcode, right-click on the **Runner** folder (blue icon)
2. Select **Add Files to "Runner"...**
3. Navigate to `ios/Runner/` directory
4. Select `GoogleService-Info.plist`
5. **IMPORTANT**: Check these options:
   - ✅ **Copy items if needed** (if file isn't already in Runner/)
   - ✅ **Add to targets: Runner** (should be checked by default)
6. Click **Add**

#### Step 3.3: Verify Signing & Capabilities
1. Select **Runner** project in left sidebar
2. Select **Runner** target
3. Go to **Signing & Capabilities** tab
4. **Team**: Select your Apple Developer account (or "Personal Team" for testing)
5. **Bundle Identifier**: Verify it's `com.example.familyhubMvp`
6. **Automatically manage signing**: ✅ Checked

**If you see signing errors:**
- For **testing only**: Use "Personal Team" (free, but apps expire after 7 days)
- For **production**: Need paid Apple Developer account ($99/year)

#### Step 3.4: Set Deployment Target
1. In **Signing & Capabilities** tab, check **Deployment Info**
2. **iOS Deployment Target**: Set to **13.0** or higher (recommended: **14.0**)
   - This should match minimum iOS version supported by Flutter plugins

#### Step 3.5: Verify CocoaPods Dependencies
1. In Terminal, navigate to `ios/` directory
2. Run:
   ```bash
   pod install
   ```
3. Wait for dependencies to install
4. If you see errors, run:
   ```bash
   pod repo update
   pod install
   ```

#### Step 3.6: Add Background Modes (Optional - for Calendar Sync)
1. In Xcode, select **Runner** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **Background Modes**
5. Check:
   - ✅ **Background fetch** (for periodic calendar sync)
   - ✅ **Background processing** (for workmanager tasks)

---

### Phase 4: Build & Test Configuration

**Estimated Time:** 15-20 minutes

#### Step 4.1: Verify Flutter iOS Setup
```bash
# From project root
flutter doctor
```

**Check for:**
- ✅ Xcode installed
- ✅ CocoaPods installed
- ✅ iOS toolchain configured

**If issues:**
```bash
# Install CocoaPods (if missing)
sudo gem install cocoapods

# Update Flutter
flutter upgrade

# Clean and get dependencies
flutter clean
flutter pub get
cd ios && pod install && cd ..
```

#### Step 4.2: Connect iOS Device
1. Connect iPhone/iPad via USB
2. Unlock device
3. Trust computer if prompted
4. In Xcode: **Window** → **Devices and Simulators**
5. Verify device appears and is trusted

#### Step 4.3: Select Device in Xcode
1. In Xcode toolbar, click device selector (next to "Runner")
2. Select your connected iOS device
3. If device is grayed out:
   - Device may need to be trusted
   - May need to enable "Developer Mode" on device (Settings → Privacy & Security → Developer Mode)

#### Step 4.4: Build & Run
**Option A: From Xcode**
1. Click **Play** button (▶️) in Xcode
2. Wait for build to complete
3. App should install and launch on device

**Option B: From Flutter CLI**
```bash
# From project root
flutter run -d <device-id>

# Or list devices first
flutter devices
flutter run
```

---

### Phase 5: Testing Checklist

**After successful build and install:**

#### 5.1: Basic App Functionality
- [ ] App launches without crashes
- [ ] Login screen appears
- [ ] Can create account / sign in
- [ ] Dashboard loads
- [ ] Navigation works (bottom nav bar)

#### 5.2: Permission Prompts
- [ ] Calendar permission prompt appears when accessing calendar sync
- [ ] Photo library permission prompt appears when selecting photos
- [ ] Camera permission prompt appears when taking photos
- [ ] Location permission prompt appears when accessing location features
- [ ] Microphone permission prompt appears when recording voice/video calls

#### 5.3: Feature Testing
- [ ] **Calendar**: Create event, view events, sync with device calendar
- [ ] **Tasks**: Create task, mark complete
- [ ] **Chat**: Send message, receive message
- [ ] **Photos**: Upload photo, view photos
- [ ] **Location**: Share location, view map
- [ ] **Calendar Sync**: Enable sync, import events from device calendar

#### 5.4: iOS-Specific Testing
- [ ] App works in portrait and landscape (if supported)
- [ ] App handles iOS keyboard properly
- [ ] App handles iOS navigation gestures (swipe back)
- [ ] Push notifications work (if configured)
- [ ] Background sync works (if configured)

---

## 🚨 Common Issues & Solutions

### Issue 1: "No GoogleService-Info.plist found"
**Solution:**
- Ensure file is in `ios/Runner/` directory
- Ensure file is added to Xcode project (blue icon, not red)
- Clean build: `flutter clean && cd ios && pod install && cd ..`

### Issue 2: "Signing for Runner requires a development team"
**Solution:**
- Go to Xcode → Runner target → Signing & Capabilities
- Select your Apple Developer account
- Or use "Personal Team" for testing (free, but 7-day expiration)

### Issue 3: "Failed to register bundle identifier"
**Solution:**
- Bundle ID might be taken
- Change bundle ID in Xcode: `com.example.familyhubMvp` → `com.yourname.familyhubMvp`
- Update `Info.plist` → `CFBundleIdentifier`
- Update Firebase Console with new bundle ID
- Download new `GoogleService-Info.plist`

### Issue 4: "CocoaPods not installed"
**Solution:**
```bash
sudo gem install cocoapods
cd ios
pod install
```

### Issue 5: "Permission denied" errors
**Solution:**
- Check `Info.plist` has all required permission descriptions
- Check permission descriptions are user-friendly (Apple may reject if too generic)
- Test on real device (simulator may not show all permission prompts)

### Issue 6: "Firebase initialization failed"
**Solution:**
- Verify `GoogleService-Info.plist` is correct
- Verify `firebase_options.dart` has real values (not "dummy")
- Check Firebase Console → iOS app is registered
- Clean build: `flutter clean && flutter pub get && cd ios && pod install && cd ..`

---

## 📝 Pre-Flight Checklist

Before starting iOS setup, ensure you have:

- [ ] **Mac computer** (required for iOS development)
- [ ] **Xcode installed** (latest version from App Store)
- [ ] **Apple ID** (for signing, free for testing)
- [ ] **iOS device** (iPhone/iPad) for testing, OR iOS Simulator
- [ ] **Firebase project access** (family-hub-71ff0)
- [ ] **Internet connection** (for CocoaPods, Firebase)

---

## 🎯 Success Criteria

iOS setup is complete when:

1. ✅ App builds successfully in Xcode
2. ✅ App installs on iOS device/simulator
3. ✅ App launches without crashes
4. ✅ Firebase authentication works
5. ✅ All permission prompts appear correctly
6. ✅ Core features (calendar, tasks, chat) work
7. ✅ Calendar sync can be enabled and works

---

## 📚 Additional Resources

- [Flutter iOS Setup](https://docs.flutter.dev/get-started/install/macos#ios-setup)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [CocoaPods Guide](https://guides.cocoapods.org/)

---

## 🔄 Next Steps After iOS Setup

1. **Test all features** on iOS device
2. **Compare behavior** with Android version
3. **Fix iOS-specific bugs** (if any)
4. **Optimize for iOS** (UI/UX adjustments)
5. **Test on multiple iOS versions** (if possible)
6. **Prepare for App Store** (if planning to publish)

---

**Document Status:** Ready for Implementation  
**Last Updated:** December 1, 2025

