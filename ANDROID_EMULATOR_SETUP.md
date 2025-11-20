# Android Emulator Setup Guide

This guide will help you set up an Android emulator to test mobile-specific features like camera, location, and other native functionality.

## Prerequisites

1. **Android Studio** must be installed
2. **Android SDK** must be configured
3. **Flutter** must be installed and configured

## Step 1: Check Flutter Setup

Run this command to check your Flutter setup:
```bash
flutter doctor
```

Make sure you see:
- ✅ Android toolchain - develop for Android devices
- ✅ Android Studio (if using)

## Step 2: Open Android Studio

1. Launch **Android Studio**
2. If this is your first time, it will download Android SDK components

## Step 3: Create an Android Virtual Device (AVD)

### Method 1: Using Android Studio GUI

1. In Android Studio, click **Tools** → **Device Manager** (or **AVD Manager**)
2. Click **Create Device**
3. Select a device definition (e.g., **Pixel 5** or **Pixel 6**)
4. Click **Next**
5. Select a system image:
   - Choose **API Level 33** or **API Level 34** (Android 13/14)
   - If not downloaded, click **Download** next to the system image
   - Wait for download to complete
6. Click **Next**
7. Configure AVD:
   - **AVD Name**: Give it a name (e.g., "Pixel_5_API_33")
   - **Startup orientation**: Portrait
   - **Graphics**: Automatic (or Hardware - GLES 2.0 for better performance)
8. Click **Finish**

### Method 2: Using Command Line

1. List available system images:
   ```bash
   flutter emulators
   ```

2. Create an emulator (if needed):
   ```bash
   # First, check available system images
   sdkmanager --list | grep "system-images"
   
   # Install a system image (example for API 33)
   sdkmanager "system-images;android-33;google_apis;x86_64"
   
   # Create AVD using avdmanager
   avdmanager create avd -n Pixel_5_API_33 -k "system-images;android-33;google_apis;x86_64" -d "pixel_5"
   ```

## Step 4: Start the Emulator

### Method 1: From Android Studio

1. Open **Device Manager** (Tools → Device Manager)
2. Click the **Play** button (▶) next to your AVD

### Method 2: From Command Line

1. List available emulators:
   ```bash
   flutter emulators
   ```

2. Launch an emulator:
   ```bash
   flutter emulators --launch <emulator_id>
   ```
   
   Or:
   ```bash
   emulator -avd Pixel_5_API_33
   ```

## Step 5: Run Flutter App on Emulator

Once the emulator is running:

```bash
# List connected devices
flutter devices

# Run on the emulator
flutter run
```

Or specify the device:
```bash
flutter run -d <device_id>
```

## Step 6: Enable Camera and Location (for testing)

### Camera Access
The emulator has a virtual camera. To test with real camera:
1. In emulator, go to **Settings** → **Camera**
2. Enable **VirtualScene** or connect a webcam

### Location Access
1. In emulator, click the **three dots** (⋯) menu
2. Go to **Location** tab
3. Set coordinates manually or use GPS files

## Troubleshooting

### Emulator is slow
- Enable **Hardware acceleration** in AVD settings
- Use **x86_64** system images (faster than ARM)
- Increase **RAM** allocation (2GB minimum, 4GB recommended)

### "No devices found"
- Make sure emulator is fully booted (wait for home screen)
- Run `flutter devices` to verify detection
- Restart ADB: `adb kill-server && adb start-server`

### "SDK location not found"
- Set `ANDROID_HOME` environment variable:
  - Windows: `C:\Users\<YourUsername>\AppData\Local\Android\Sdk`
  - Add to PATH: `%ANDROID_HOME%\platform-tools`

### Emulator won't start
- Check if **Hyper-V** (Windows) or **VirtualBox** is conflicting
- Try **Cold Boot** from AVD Manager
- Check Windows **BIOS** settings for virtualization support (VT-x/AMD-V)

## Quick Commands Reference

```bash
# List all emulators
flutter emulators

# Launch specific emulator
flutter emulators --launch <emulator_id>

# List connected devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Check Android SDK path
echo $ANDROID_HOME  # Linux/Mac
echo %ANDROID_HOME% # Windows CMD
$env:ANDROID_HOME   # Windows PowerShell
```

## Recommended Emulator Configuration

For best performance:
- **Device**: Pixel 5 or Pixel 6
- **API Level**: 33 or 34
- **System Image**: Google APIs (x86_64)
- **RAM**: 2048 MB minimum, 4096 MB recommended
- **Graphics**: Hardware - GLES 2.0
- **Multi-core CPU**: 2-4 cores

