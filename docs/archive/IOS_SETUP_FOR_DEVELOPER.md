# iOS Setup Instructions for Developer

**Project:** FamilyHub MVP  
**Branch:** `develop`  
**Date:** December 1, 2025

---

## 📋 Prerequisites

Before starting, ensure you have:
- ✅ Mac with macOS installed
- ✅ Xcode installed (latest version from App Store)
- ✅ Git installed
- ✅ Flutter installed (if not, see "Flutter Installation" section below)
- ✅ Apple Developer account (or use "Personal Team" for testing - free)

---

## 🚀 Step-by-Step Setup

### Step 1: Clone/Update the Repository

```bash
# If cloning fresh:
git clone https://github.com/cryptonut/familyhub-MVP.git
cd familyhub-MVP

# If repository already exists, pull latest:
git checkout develop
git pull origin develop
```

**Verify:** You should see `ios/Runner/GoogleService-Info.plist` file exists.

---

### Step 2: Install Flutter (If Not Already Installed)

```bash
# Check if Flutter is installed
flutter --version

# If not installed, install Flutter:
# 1. Download from: https://flutter.dev/docs/get-started/install/macos
# 2. Extract and add to PATH
# 3. Run: flutter doctor
```

**Verify Flutter Setup:**
```bash
flutter doctor
```

You should see:
- ✅ Flutter (Channel stable, version...)
- ✅ Xcode - develop for iOS
- ✅ CocoaPods - develop for iOS

---

### Step 3: Install CocoaPods (If Not Already Installed)

```bash
# Check if CocoaPods is installed
pod --version

# If not installed:
sudo gem install cocoapods

# Update CocoaPods repo (first time only)
pod repo update
```

---

### Step 4: Get Flutter Dependencies

```bash
# From project root
cd familyhub-MVP
flutter pub get
```

---

### Step 5: Install iOS Dependencies (CocoaPods)

```bash
cd ios
pod install
cd ..
```

**Expected Output:** Should see "Pod installation complete!" with no errors.

**If you see errors:**
```bash
# Try updating CocoaPods repo first
pod repo update
pod install

# If still errors, try cleaning:
rm -rf Pods Podfile.lock
pod install
```

---

### Step 6: Open Project in Xcode

```bash
cd ios
open Runner.xcworkspace
```

**⚠️ IMPORTANT:** Use `.xcworkspace`, NOT `.xcodeproj` (required for CocoaPods)

Xcode should open with the project.

---

### Step 7: Verify GoogleService-Info.plist is Added

1. In Xcode, look at the left sidebar (Project Navigator)
2. Find `GoogleService-Info.plist` under the `Runner` folder
3. It should have a **blue icon** (not red/grey)
4. If it's **red or missing**:
   - Right-click on `Runner` folder → "Add Files to Runner..."
   - Navigate to `ios/Runner/GoogleService-Info.plist`
   - Check "Copy items if needed" and "Add to targets: Runner"
   - Click "Add"

---

### Step 8: Configure Code Signing

1. In Xcode, click on **Runner** project (blue icon) in left sidebar
2. Select **Runner** target (under TARGETS)
3. Click **Signing & Capabilities** tab
4. Configure:
   - **Team**: Select your Apple Developer account
     - If you don't have one, select "Add an Account..." and sign in with Apple ID
     - For testing, you can use "Personal Team" (free, but apps expire after 7 days)
   - **Bundle Identifier**: Should be `com.example.familyhubMvp`
     - If it's different, change it to match exactly
   - **Automatically manage signing**: ✅ Check this box

**If you see signing errors:**
- Make sure you're signed in with an Apple ID in Xcode → Preferences → Accounts
- For testing, "Personal Team" is fine (free, but 7-day expiration)

---

### Step 9: Set Deployment Target

1. Still in **Signing & Capabilities** tab
2. Check **Deployment Info** section
3. **iOS Deployment Target**: Set to **13.0** or higher (recommended: **14.0**)

---

### Step 10: Verify Info.plist Permissions

1. In Xcode, navigate to `Runner` → `Info.plist`
2. Verify these keys exist (they should already be there):
   - `NSCalendarsUsageDescription`
   - `NSCalendarsWriteOnlyUsageDescription`
   - `NSPhotoLibraryUsageDescription`
   - `NSPhotoLibraryAddUsageDescription`
   - `NSCameraUsageDescription`
   - `NSLocationWhenInUseUsageDescription`
   - `NSLocationAlwaysUsageDescription`
   - `NSMicrophoneUsageDescription`

If any are missing, they need to be added (but they should already be configured).

---

### Step 11: Select Device/Simulator

1. In Xcode toolbar, click the device selector (next to "Runner")
2. Choose one of:
   - **Connected iOS Device** (if iPhone/iPad is connected)
   - **iOS Simulator** (e.g., "iPhone 15 Pro" or any available simulator)

**If no devices appear:**
- For Simulator: Xcode → Window → Devices and Simulators → Create a simulator
- For Physical Device: Connect via USB, unlock device, trust computer

---

### Step 12: Build and Run

**Option A: From Xcode**
1. Click the **Play button** (▶️) in Xcode toolbar
2. Wait for build to complete (first build may take 5-10 minutes)
3. App should install and launch on device/simulator

**Option B: From Terminal (Flutter CLI)**
```bash
# From project root
cd familyhub-MVP

# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Or just run (will use first available device)
flutter run
```

---

## ✅ Verification Checklist

After successful build, verify:

- [ ] App launches without crashes
- [ ] Login screen appears
- [ ] Can create account / sign in
- [ ] Firebase authentication works
- [ ] Dashboard loads
- [ ] Navigation works

---

## 🧪 Testing Permissions

Test that permission prompts appear:

1. **Calendar Permission**: Go to Settings → Calendar Sync → Enable sync
2. **Photo Permission**: Try uploading a photo to an event
3. **Camera Permission**: Try taking a photo
4. **Location Permission**: Try accessing location features
5. **Microphone Permission**: Try recording a voice message

All should show iOS permission dialogs.

---

## 🐛 Common Issues & Solutions

### Issue 1: "No such module 'FirebaseCore'"
**Solution:**
```bash
cd ios
pod install
cd ..
# Clean and rebuild
flutter clean
flutter pub get
```

### Issue 2: "Signing for Runner requires a development team"
**Solution:**
- Go to Xcode → Runner target → Signing & Capabilities
- Select your Apple Developer account
- Or use "Personal Team" for testing

### Issue 3: "GoogleService-Info.plist not found"
**Solution:**
- Verify file exists at `ios/Runner/GoogleService-Info.plist`
- Add it to Xcode project (Step 7 above)
- Ensure it's added to "Runner" target

### Issue 4: "CocoaPods not installed"
**Solution:**
```bash
sudo gem install cocoapods
cd ios
pod install
```

### Issue 5: Build fails with "Undefined symbols"
**Solution:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
```

### Issue 6: "Device not trusted" or "Developer Mode not enabled"
**Solution:**
- On iOS device: Settings → Privacy & Security → Developer Mode → Enable
- Restart device
- Trust computer when prompted

---

## 📱 Building for Testing (IPA File)

If you want to create an IPA file for testing:

1. In Xcode, select **Product** → **Archive**
2. Wait for archive to complete
3. In Organizer window:
   - Click **Distribute App**
   - Select **Development** or **Ad Hoc**
   - Follow prompts to export IPA

**Note:** For Ad Hoc distribution, you need to register device UDID in Apple Developer portal.

---

## 🔄 Updating the App Later

If code changes are made:

```bash
# Pull latest changes
git pull origin develop

# Get Flutter dependencies
flutter pub get

# Update iOS dependencies (if new plugins added)
cd ios
pod install
cd ..

# Rebuild
flutter run
```

---

## 📞 What to Report Back

Please let us know:

1. ✅ **Build Status**: Did it build successfully?
2. ✅ **Run Status**: Does the app launch and run?
3. ✅ **Firebase**: Does login/authentication work?
4. ✅ **Permissions**: Do permission prompts appear?
5. ✅ **Issues**: Any errors or crashes?
6. ✅ **Device Info**: What device/iOS version did you test on?

---

## 🎯 Quick Reference Commands

```bash
# Full setup (if starting fresh)
git clone https://github.com/cryptonut/familyhub-MVP.git
cd familyhub-MVP
git checkout develop
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace

# Then in Xcode:
# 1. Configure signing
# 2. Select device
# 3. Click Play button
```

---

## 📝 Notes

- **Bundle ID**: `com.example.familyhubMvp` (must match exactly)
- **Firebase Project**: `family-hub-71ff0`
- **Minimum iOS**: 13.0 (recommended: 14.0+)
- **Flutter Version**: Should work with latest stable

---

**Estimated Time:** 30-60 minutes (first time setup)  
**Difficulty:** Intermediate (requires Xcode knowledge)

---

**Questions?** Check `IOS_SETUP_PLAN.md` for more detailed explanations.

