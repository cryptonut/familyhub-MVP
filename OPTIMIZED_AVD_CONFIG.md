# Optimized Android Virtual Device (AVD) Configuration

This guide helps you create and configure an Android emulator for optimal performance with the familyhub-MVP app.

## Prerequisites

✅ Virtualization must be enabled in BIOS (see `FINAL_EMULATOR_SOLUTION.md`)
✅ Android Studio installed
✅ Android SDK configured

## Recommended AVD Configuration

### Device Profile
- **Device**: Google Pixel 6 or Pixel 7
- **Why**: Modern device profile, good balance of performance and compatibility

### System Image
- **API Level**: 33 (Android 13) or 34 (Android 14)
- **ABI**: **x86_64** (REQUIRED for performance)
- **Target**: Google APIs (includes Google Play Services)
- **Why**: x86_64 is 10-20x faster than ARM64, requires hardware acceleration

### Performance Settings

#### RAM Allocation
- **Minimum**: 2048 MB
- **Recommended**: 4096 MB (4 GB)
- **Maximum**: 8192 MB (8 GB) - only if you have 16GB+ system RAM
- **Why**: More RAM = smoother performance, less swapping

#### VM Heap
- **Default**: 512 MB
- **Recommended**: 512 MB (usually sufficient)
- **Why**: Controls app memory, 512MB is standard

#### Graphics
- **Option**: **Hardware - GLES 2.0**
- **Alternative**: Automatic (will try hardware first)
- **Avoid**: Software (very slow)
- **Why**: Hardware acceleration provides smooth UI rendering

#### Multi-Core CPU
- **Recommended**: 2-4 cores
- **Maximum**: Don't exceed half your CPU cores
- **Example**: 8-core CPU → use 2-4 cores for emulator
- **Why**: More cores = faster app execution, but uses more system resources

#### Internal Storage
- **Default**: 2048 MB
- **Recommended**: 4096 MB (4 GB)
- **Why**: More space for apps and data

#### SD Card
- **Optional**: 512 MB - 1024 MB
- **Why**: Only needed if testing SD card features

## Step-by-Step: Create Optimized AVD

### Method 1: Android Studio GUI

1. **Open Android Studio**
2. **Tools → Device Manager** (or **AVD Manager**)
3. **Create Device**
4. **Select Device:**
   - Choose **Pixel 6** or **Pixel 7**
   - Click **Next**
5. **Select System Image:**
   - Choose **API Level 33** or **34**
   - **IMPORTANT**: Select **x86_64** ABI (not ARM64)
   - If not downloaded, click **Download**
   - Wait for download to complete
   - Click **Next**
6. **Configure AVD:**
   - **AVD Name**: `pixel6_optimized` (or your preferred name)
   - **Startup orientation**: Portrait
   - Click **Show Advanced Settings**
7. **Advanced Settings:**
   - **RAM**: 4096 MB
   - **VM heap**: 512 MB
   - **Internal Storage**: 4096 MB
   - **SD Card**: 512 MB (optional)
   - **Graphics**: Hardware - GLES 2.0
   - **Multi-Core CPU**: 2-4 (based on your system)
   - **Camera**: VirtualScene (for testing)
   - **Network Speed**: Full
   - **Network Latency**: None
8. **Click Finish**

### Method 2: Command Line

```powershell
# Set Android SDK path
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"

# Install system image (if not already installed)
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" "system-images;android-33;google_apis;x86_64"

# Create AVD
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\avdmanager.bat" create avd `
  -n pixel6_optimized `
  -k "system-images;android-33;google_apis;x86_64" `
  -d "pixel_6"
```

Then edit the AVD config file to add performance settings:
- Location: `%USERPROFILE%\.android\avd\pixel6_optimized.avd\config.ini`
- Add/Edit:
  ```
  hw.ramSize = 4096
  hw.gpu.enabled = yes
  hw.gpu.mode = host
  hw.cpu.ncore = 4
  ```

## Verify Configuration

After creating the AVD, verify it's optimized:

```powershell
# List emulators
flutter emulators

# Launch and check performance
flutter emulators --launch pixel6_optimized

# In another terminal, check acceleration
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
& "$env:ANDROID_HOME\emulator\emulator.exe" -accel-check
```

You should see:
- ✅ HAXM or WHPX acceleration available
- ✅ Emulator boots in 30-60 seconds
- ✅ Smooth UI scrolling
- ✅ Fast app launches

## Performance Tips

### 1. Use Snapshots (Faster Startup)
- First boot: Let emulator fully boot, then close it
- Next launches: Emulator will use snapshot (boots in 5-10 seconds)
- **Note**: Snapshots can cause issues - use cold boot if problems occur

### 2. Close Unnecessary Apps
- Close other heavy applications when running emulator
- Emulator uses significant CPU and RAM

### 3. Use Release Mode for Testing Performance
```powershell
flutter run --release
```
Release mode is faster but doesn't support hot reload.

### 4. Monitor System Resources
- Task Manager → Performance tab
- Watch CPU and RAM usage
- Adjust emulator cores/RAM if system is struggling

### 5. Use Physical Device for Final Testing
- Physical devices are often faster than emulators
- Better for testing real-world performance
- No virtualization required

## Troubleshooting Slow Performance

### Issue: Emulator is still slow after optimization

**Check 1: Virtualization Status**
```powershell
Get-ComputerInfo | Select-Object -Property HyperVRequirementVirtualizationFirmwareEnabled
```
Must be `True`. If `False`, enable in BIOS.

**Check 2: Graphics Acceleration**
```powershell
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
& "$env:ANDROID_HOME\emulator\emulator.exe" -accel-check
```
Should show HAXM or WHPX available.

**Check 3: System Image ABI**
- Must be **x86_64**, not ARM64
- ARM64 is 10-20x slower

**Check 4: RAM Allocation**
- Increase to 4096 MB or 6144 MB
- Don't exceed 50% of system RAM

**Check 5: Windows Hypervisor Platform**
If Hyper-V is enabled, ensure WHPX is enabled:
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform
```
(Requires admin, restart required)

### Issue: Emulator crashes

1. **Cold boot** (clears snapshot issues):
   ```powershell
   .\launch_emulator.ps1 -ColdBoot
   ```

2. **Reduce RAM/CPU cores** if system is unstable

3. **Check for conflicts:**
   - Disable VirtualBox if installed
   - Close other virtualization software

4. **Recreate AVD** with default settings, then optimize gradually

## Quick Reference: Optimal Settings Summary

```
Device: Pixel 6 or Pixel 7
API Level: 33 or 34
ABI: x86_64 (REQUIRED)
RAM: 4096 MB
VM Heap: 512 MB
Graphics: Hardware - GLES 2.0
CPU Cores: 2-4
Internal Storage: 4096 MB
```

## Next Steps

After creating your optimized AVD:

1. **Launch it:**
   ```powershell
   .\launch_emulator.ps1
   ```

2. **Run your app:**
   ```powershell
   flutter run
   ```

3. **Test features:**
   - Camera (virtual camera available)
   - Location (set via emulator controls)
   - Firebase services
   - Photo uploads

For more help, see:
- `FINAL_EMULATOR_SOLUTION.md` - BIOS virtualization setup
- `check_emulator.ps1` - Diagnostic script
- `launch_emulator.ps1` - Smart launcher script

