# USB Device Setup Guide

Using a physical Android device is often faster and more reliable than an emulator. This guide will help you set up USB debugging.

## Prerequisites

- Android phone (Android 5.0+ recommended)
- USB cable (preferably the original cable that came with your phone)
- USB drivers installed (usually automatic on Windows 10/11)

## Step 1: Enable Developer Options

1. **Open Settings** on your Android phone
2. **Go to About Phone** (or About Device)
3. **Find "Build Number"** (usually at the bottom)
4. **Tap "Build Number" 7 times**
   - You'll see a message like "You are now a developer!"
5. **Go back** to main Settings

## Step 2: Enable USB Debugging

1. **Open Settings** → **Developer Options** (now visible)
2. **Enable "Developer Options"** (toggle at the top)
3. **Enable "USB Debugging"**
   - You may see a warning - tap "OK" or "Allow"
4. **Optional but recommended:**
   - Enable "Stay awake" (keeps screen on while charging)
   - Enable "USB Debugging (Security settings)" if available

## Step 3: Connect Your Phone

1. **Connect your phone to your computer** via USB cable
2. **On your phone**, you'll see a popup: **"Allow USB debugging?"**
   - Check **"Always allow from this computer"**
   - Tap **"Allow"** or **"OK"**

## Step 4: Verify Connection

Run the diagnostic script:
```powershell
.\check_usb_device.ps1
```

Or manually check:
```powershell
# Check if device is detected
adb devices

# Should show something like:
# List of devices attached
# ABC123XYZ    device
```

If you see "unauthorized", tap "Allow" on your phone when the popup appears.

## Step 5: Run Your App

Once connected, you can run your Flutter app:

```powershell
# List all devices (phone should appear)
flutter devices

# Run on your phone
flutter run

# Or specify the device ID
flutter run -d <device_id>
```

## Troubleshooting

### Phone Not Detected

**1. Check USB Connection:**
- Try a different USB cable
- Try a different USB port (prefer USB 3.0 ports)
- Make sure cable supports data transfer (not just charging)

**2. Check USB Drivers:**
- Windows usually installs drivers automatically
- If not working, install your phone manufacturer's USB drivers:
  - **Samsung**: Samsung USB Driver
  - **Google Pixel**: Google USB Driver
  - **OnePlus**: OnePlus USB Driver
  - **Xiaomi**: Mi USB Driver
  - Or use universal: [Universal ADB Driver](https://github.com/koush/UniversalAdbDriver)

**3. Restart ADB:**
```powershell
adb kill-server
adb start-server
adb devices
```

**4. Check Phone Settings:**
- Make sure USB Debugging is still enabled
- Try revoking USB debugging authorizations:
  - Settings → Developer Options → Revoke USB debugging authorizations
  - Disconnect and reconnect phone
  - Allow the popup again

### "Unauthorized" Device

1. **Check your phone** - you should see a popup asking to allow USB debugging
2. **Tap "Allow"** and check "Always allow from this computer"
3. **Run `adb devices` again**

### Device Shows as "Offline"

1. **Disconnect and reconnect** the USB cable
2. **Revoke USB debugging** on phone, then reconnect
3. **Restart ADB:**
   ```powershell
   adb kill-server
   adb start-server
   ```

### Windows Not Recognizing Device

1. **Check Device Manager:**
   - Press `Win + X` → Device Manager
   - Look for your phone under "Portable Devices" or "Android Phone"
   - If you see a yellow exclamation mark, update the driver

2. **Install Manufacturer Drivers:**
   - Download from your phone manufacturer's website
   - Or use Windows Update to find drivers

### Flutter Not Seeing Device

1. **Make sure ADB sees it first:**
   ```powershell
   adb devices
   ```
   If ADB doesn't see it, Flutter won't either.

2. **Check Flutter:**
   ```powershell
   flutter devices
   ```
   Should show your phone with device ID.

3. **Try restarting Flutter daemon:**
   ```powershell
   flutter doctor -v
   ```

## USB Connection Modes

Some phones have different USB connection modes. When you connect:

1. **Pull down notification panel** on your phone
2. **Tap "USB" or "Charging this device via USB"**
3. **Select "File Transfer" or "MTP"** mode
   - This ensures the computer can communicate with the phone

## Advantages of Physical Device

✅ **Faster than emulator** - Real hardware performance
✅ **No virtualization required** - Works even if BIOS virtualization is disabled
✅ **Real-world testing** - Test on actual device your users will use
✅ **Better performance** - Native hardware acceleration
✅ **Camera/Location** - Real sensors instead of virtual ones
✅ **Battery/Network** - Test real-world conditions

## Quick Commands Reference

```powershell
# Check connected devices
adb devices
flutter devices

# Restart ADB
adb kill-server
adb start-server

# Run app on phone
flutter run

# Run on specific device
flutter run -d <device_id>

# Install APK directly
adb install app.apk

# View device logs
adb logcat

# Reboot device
adb reboot
```

## Next Steps

Once your phone is connected and working:

1. **Run your app:**
   ```powershell
   flutter run
   ```

2. **Test features:**
   - Camera (real camera)
   - Location (real GPS)
   - Push notifications
   - Photo uploads
   - All Firebase features

3. **Development workflow:**
   - Make code changes
   - Hot reload: Press `r` in terminal
   - Hot restart: Press `R` in terminal
   - Full restart: Press `q` then `flutter run` again

Enjoy faster development with your physical device!

