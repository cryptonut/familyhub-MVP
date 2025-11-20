# Android Emulator Troubleshooting Guide

## Current Issue
The emulator is not detecting hardware acceleration, even after installing the Android Emulator Hypervisor Driver (AEHD).

## Solutions to Try

### Option 1: Enable Windows Hypervisor Platform (WHPX)
Windows Hypervisor Platform is required when Hyper-V is active. The emulator should use WHPX instead of AEHD.

**Steps:**
1. Open PowerShell as Administrator
2. Run:
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform
   ```
3. Restart your computer
4. Try launching the emulator again

### Option 2: Verify Hyper-V Configuration
If Hyper-V is enabled, the emulator should automatically use it. Verify:

1. Check if Hyper-V is enabled:
   ```powershell
   Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
   ```
   (Requires admin)

2. If Hyper-V is enabled, the AEHD service will be stopped (this is normal)

### Option 3: Reinstall Android Emulator Hypervisor Driver
1. Open Android Studio
2. Go to **Tools > SDK Manager**
3. Click **SDK Tools** tab
4. Uncheck **Android Emulator Hypervisor Driver for AMD Processors**
5. Click **Apply** to uninstall
6. Check it again and click **Apply** to reinstall
7. Restart your computer

### Option 4: Use Software Rendering (Slow but Works)
If hardware acceleration isn't available, you can use software rendering:

```powershell
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
& "$env:ANDROID_HOME\emulator\emulator.exe" -avd pixel6 -gpu swiftshader_indirect -no-snapshot-load
```

**Note:** This will be very slow, but it should work without hardware acceleration.

### Option 5: Create New AVD with ARM64 System Image
ARM64 images don't require hardware acceleration (but are slower):

1. Open Android Studio
2. Go to **Tools > Device Manager**
3. Click **Create Device**
4. Select a device (e.g., Pixel 6)
5. Click **Next**
6. Select an **ARM64** system image (e.g., "Tiramisu" API 33 ARM64)
7. Click **Next** and **Finish**
8. Launch the new AVD

### Option 6: Check BIOS Settings
If you have an Intel processor, ensure:
- **Intel Virtualization Technology (VT-x)** is enabled in BIOS
- **Hyper-V** is enabled in Windows

If you have an AMD processor, ensure:
- **AMD-V** is enabled in BIOS
- **Hyper-V** is enabled in Windows

## Diagnostic Commands

Check acceleration status:
```powershell
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
& "$env:ANDROID_HOME\emulator\emulator.exe" -accel-check
```

Check available emulators:
```powershell
flutter emulators
```

Check connected devices:
```powershell
flutter devices
```

## Next Steps
1. Try Option 1 first (enable WHPX)
2. If that doesn't work, try Option 3 (reinstall driver)
3. As a last resort, use Option 4 (software rendering) or Option 5 (ARM64 image)

