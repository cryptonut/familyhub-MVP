# Android Publishing Guide for FamilyHub

This guide covers multiple ways to publish and test your FamilyHub app on Android devices.

## Table of Contents
1. [Quick Methods for Testing](#quick-methods-for-testing)
2. [Build a Debug APK](#build-a-debug-apk)
3. [Build a Release APK](#build-a-release-apk)
4. [Set Up App Signing](#set-up-app-signing)
5. [Build an App Bundle](#build-an-app-bundle)
6. [Internal Testing via Google Play Console](#internal-testing-via-google-play-console)
7. [Firebase App Distribution](#firebase-app-distribution)
8. [Direct Device Installation](#direct-device-installation)
9. [Troubleshooting](#troubleshooting)

---

## Quick Methods for Testing

| Method | Best For | Setup Time | Distribution |
|--------|----------|------------|--------------|
| Debug APK | Quick local testing | 5 min | Manual file sharing |
| Release APK | Testing real performance | 15 min | Manual file sharing |
| Firebase App Distribution | Team testing | 30 min | Email invites |
| Internal Testing (Play Console) | Production-like testing | 1-2 hours | Play Store internal track |

---

## Build a Debug APK

The quickest way to test on an Android device:

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build debug APK
flutter build apk --debug
```

The APK will be at: `build/app/outputs/flutter-apk/app-debug.apk`

### Transfer to device:
- **USB**: Connect phone and copy the APK file
- **Email**: Send APK to yourself
- **Cloud storage**: Upload to Google Drive, Dropbox, etc.
- **ADB**: `adb install build/app/outputs/flutter-apk/app-debug.apk`

---

## Build a Release APK

For better performance (optimized, minified):

```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

**Note**: Currently uses debug signing keys (see current `android/app/build.gradle.kts`). For production, set up proper signing.

---

## Set Up App Signing

For production releases and Play Store distribution, you need a signing key.

### Step 1: Generate a Keystore

```bash
keytool -genkey -v -keystore ~/familyhub-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias familyhub
```

**⚠️ IMPORTANT**: Keep this file safe and backed up! If you lose it, you cannot update your app on Play Store.

### Step 2: Create `android/key.properties`

Create a file at `android/key.properties` (do NOT commit to git):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=familyhub
storeFile=/path/to/familyhub-release-key.jks
```

### Step 3: Update `android/app/build.gradle.kts`

Modify the file to use your signing config:

```kotlin
// Load key.properties file
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...
    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String? ?: ""
            keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}
```

### Step 4: Add to `.gitignore`

```
android/key.properties
*.jks
*.keystore
```

---

## Build an App Bundle

Google Play Store requires App Bundles (AAB) for new apps:

```bash
flutter build appbundle --release
```

The bundle will be at: `build/app/outputs/bundle/release/app-release.aab`

---

## Internal Testing via Google Play Console

The recommended way to test on multiple devices with easy updates.

### Step 1: Create a Google Play Developer Account

1. Go to [Google Play Console](https://play.google.com/console)
2. Pay the one-time $25 registration fee
3. Complete account setup

### Step 2: Create a New App

1. Click "Create app"
2. Fill in app details:
   - App name: `FamilyHub`
   - Default language: English
   - App or game: App
   - Free or paid: Free

### Step 3: Set Up Internal Testing

1. Go to **Testing → Internal testing**
2. Click **Create new release**
3. Upload your AAB file (`app-release.aab`)
4. Add release notes
5. Click **Save** → **Review release** → **Start rollout**

### Step 4: Add Testers

1. Go to **Internal testing → Testers**
2. Create a new email list or add testers
3. Testers will receive an email with install link

### Benefits:
- ✅ Easy updates (just upload new build)
- ✅ Up to 100 testers
- ✅ Testers install via Play Store
- ✅ Automatic updates for testers
- ✅ Production-like testing environment

---

## Firebase App Distribution

Great for quick team testing without Play Store setup.

### Step 1: Install Firebase CLI

```bash
# Using npm
npm install -g firebase-tools

# Login
firebase login
```

### Step 2: Add Firebase App Distribution Plugin

In `android/app/build.gradle.kts`:

```kotlin
plugins {
    // ... existing plugins ...
    id("com.google.firebase.appdistribution")
}
```

In `android/build.gradle.kts`:

```kotlin
buildscript {
    dependencies {
        classpath("com.google.firebase:firebase-appdistribution-gradle:4.0.1")
    }
}
```

### Step 3: Configure Distribution

In `android/app/build.gradle.kts`:

```kotlin
firebaseAppDistribution {
    releaseNotes = "Bug fixes and improvements"
    testers = "tester1@example.com, tester2@example.com"
    // Or use groups: groups = "qa-team, beta-testers"
}
```

### Step 4: Distribute

```bash
# Build and distribute
./gradlew assembleRelease appDistributionUploadRelease
```

### Alternative: Web Upload

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project → App Distribution
3. Upload APK/AAB manually
4. Add testers

---

## Direct Device Installation

### Method 1: ADB (Android Debug Bridge)

```bash
# Check device is connected
adb devices

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Install and replace existing
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Method 2: Flutter Run

```bash
# Run directly on connected device
flutter run --release

# Specify device
flutter devices  # List devices
flutter run -d <device-id> --release
```

### Method 3: Manual Transfer

1. Enable **Install from Unknown Sources** on Android:
   - Settings → Security → Unknown sources (Android 7 and below)
   - Settings → Apps → Special app access → Install unknown apps (Android 8+)

2. Transfer APK via:
   - USB cable
   - Email attachment
   - Google Drive / Dropbox
   - Bluetooth
   - QR code link

3. Open the APK file on device and install

---

## Pre-Launch Checklist

Before distributing your app:

### ☐ App Configuration
- [ ] Update `applicationId` in `android/app/build.gradle.kts` (e.g., `com.yourcompany.familyhub`)
- [ ] Update `versionCode` and `versionName` in `pubspec.yaml`
- [ ] Update app name in `android/app/src/main/AndroidManifest.xml`

### ☐ Firebase Setup
- [ ] Verify `google-services.json` is correct for your Firebase project
- [ ] Ensure SHA-1 fingerprint is added to Firebase Console
- [ ] Test authentication works

### ☐ Secrets & API Keys
- [ ] Create `android/secrets.properties` with your API keys
- [ ] Verify Google Maps API key is configured (if using maps)
- [ ] Remove any hardcoded secrets

### ☐ App Icons & Branding
- [ ] Add custom app icons (replace defaults in `android/app/src/main/res/`)
- [ ] Configure splash screen

### ☐ Testing
- [ ] Test on multiple Android versions
- [ ] Test on different screen sizes
- [ ] Test with poor network connectivity
- [ ] Test all Firebase features

---

## Troubleshooting

### Build Fails

```bash
# Clean and rebuild
flutter clean
cd android && ./gradlew clean && cd ..
flutter pub get
flutter build apk --release
```

### APK Won't Install

1. **Unknown Sources**: Enable installation from unknown sources
2. **Previous Version**: Uninstall existing version first
3. **Architecture**: Ensure APK matches device architecture
   ```bash
   # Build for specific architecture
   flutter build apk --release --target-platform android-arm64
   ```

### App Crashes on Launch

```bash
# Check logs
adb logcat | grep -i flutter
adb logcat | grep -i familyhub

# Run in debug mode first
flutter run --debug
```

### Firebase Issues

1. Verify `google-services.json` is in `android/app/`
2. Check SHA-1 fingerprint in Firebase Console:
   ```bash
   # Get debug SHA-1
   cd android && ./gradlew signingReport
   ```
3. Re-download `google-services.json` after adding SHA-1

### Size Too Large

```bash
# Build with split per ABI (smaller APKs)
flutter build apk --release --split-per-abi
```

This creates separate APKs for each architecture:
- `app-arm64-v8a-release.apk` (modern devices)
- `app-armeabi-v7a-release.apk` (older devices)
- `app-x86_64-release.apk` (emulators)

---

## Quick Reference

### Build Commands

| Command | Output |
|---------|--------|
| `flutter build apk --debug` | Debug APK |
| `flutter build apk --release` | Release APK |
| `flutter build apk --release --split-per-abi` | Split APKs by architecture |
| `flutter build appbundle --release` | App Bundle (AAB) |

### Output Locations

| Build Type | Path |
|------------|------|
| Debug APK | `build/app/outputs/flutter-apk/app-debug.apk` |
| Release APK | `build/app/outputs/flutter-apk/app-release.apk` |
| App Bundle | `build/app/outputs/bundle/release/app-release.aab` |

### Useful ADB Commands

```bash
adb devices                    # List connected devices
adb install app.apk           # Install APK
adb install -r app.apk        # Replace existing
adb uninstall com.example.app # Uninstall by package
adb logcat                    # View device logs
```

---

## Recommended Testing Workflow

1. **Local Development**: `flutter run --debug`
2. **Performance Testing**: `flutter run --release`
3. **Team Testing**: Firebase App Distribution or Internal Testing
4. **Beta Testing**: Closed Testing track on Play Console
5. **Production**: Production release on Play Store

---

## Next Steps

Once you've tested your app and it's ready for public release:

1. Complete your Play Store listing (screenshots, description, etc.)
2. Set up Closed Testing for broader beta testing
3. Address any pre-launch report issues
4. Submit for review and publish!

For more details, see:
- [Flutter Android Deployment Guide](https://docs.flutter.dev/deployment/android)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer/)
