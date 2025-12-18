# Final Solution: Android Emulator Issue

## Root Cause
**Virtualization is disabled in BIOS/UEFI.** This is a hardware-level setting that cannot be changed from Windows.

## Why Emulators Won't Start

1. **x86_64 emulators (pixel6, Medium Phone API 35):**
   - **REQUIRE** hardware acceleration (CPU virtualization)
   - **CANNOT** run with software rendering
   - **WILL NOT** work until virtualization is enabled in BIOS

2. **ARM64 emulators:**
   - Don't require hardware acceleration
   - Are much slower (software emulation)
   - May work but are unreliable

## The Fix (You Must Do This)

**Enable Intel Virtualization Technology (VT-x) in BIOS:**

1. **Restart your computer**
2. **Press F2** (or F10/Del/Esc) during boot to enter BIOS
   - Common keys: F2, F10, F12, Del, Esc
   - Look for "Press [key] to enter Setup" during boot
3. **Navigate to:** Advanced → Processor Configuration
   - Location varies by manufacturer (may be under "CPU Features", "Security", or "System Configuration")
4. **Find:** "Intel Virtualization Technology" or "VT-x" (Intel) / "AMD-V" (AMD)
5. **Change:** Disabled → **Enabled**
6. **Save and Exit** (usually F10, or follow on-screen instructions)
7. **Restart Windows**

### BIOS Navigation by Manufacturer

- **Dell**: System → Processor → Virtualization Technology
- **HP**: Advanced → System Options → Virtualization Technology
- **Lenovo**: Security → Virtualization → Intel Virtualization Technology
- **ASUS**: Advanced → CPU Configuration → Intel Virtualization Technology
- **Acer**: Main → Processor → Virtualization Technology

## After Enabling Virtualization

Once virtualization is enabled:
- All x86_64 emulators will work
- The Android Emulator Hypervisor Driver will work
- Emulators will launch quickly and perform well
- You can use the optimized configurations below

## Verify It's Enabled

After restart, run:
```powershell
Get-ComputerInfo | Select-Object -Property HyperVRequirementVirtualizationFirmwareEnabled
```
Should show: `True`

Or use the diagnostic script:
```powershell
.\check_emulator.ps1
```

## Quick Start (After Virtualization is Enabled)

1. **Check status:**
   ```powershell
   .\check_emulator.ps1
   ```

2. **Launch emulator:**
   ```powershell
   .\launch_emulator.ps1
   ```
   Or manually:
   ```powershell
   flutter emulators --launch pixel6
   ```

3. **Run your app:**
   ```powershell
   flutter run
   ```

## Performance Optimizations (Applied)

The following optimizations have been applied to improve emulator and build performance:

### Build Optimizations (`android/gradle.properties`)
- ✅ Gradle daemon enabled
- ✅ Parallel builds enabled
- ✅ Build caching enabled
- ✅ G1 garbage collector for faster builds
- ✅ Configure on demand enabled

### Emulator Optimizations
- Use x86_64 system images (faster than ARM)
- Allocate 4GB+ RAM to emulator
- Use Hardware GLES 2.0 graphics
- Enable multi-core CPU (2-4 cores)

See `OPTIMIZED_AVD_CONFIG.md` for detailed AVD setup.

## Alternative: Use Physical Device

If you cannot enable virtualization:
1. Enable **USB Debugging** on your Android phone:
   - Settings → About Phone → Tap "Build Number" 7 times
   - Settings → Developer Options → Enable "USB Debugging"
2. Connect via USB
3. Run: `flutter devices` (should show your phone)
4. Run: `flutter run` (will deploy to phone)

**Note:** Physical devices are often faster than emulators and don't require virtualization!

## Troubleshooting

### Emulator Still Slow After Enabling Virtualization

1. **Check acceleration:**
   ```powershell
   $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
   & "$env:ANDROID_HOME\emulator\emulator.exe" -accel-check
   ```

2. **Increase emulator RAM:**
   - Android Studio → Device Manager → Edit AVD
   - Advanced Settings → RAM: 4096 MB

3. **Use Hardware Graphics:**
   - Edit AVD → Graphics: Hardware - GLES 2.0

4. **Enable Windows Hypervisor Platform (if Hyper-V is enabled):**
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform
   ```
   (Requires admin, restart required)

### Emulator Crashes

1. **Cold boot the emulator:**
   ```powershell
   .\launch_emulator.ps1 -ColdBoot
   ```

2. **Check for conflicting virtualization:**
   - Disable VirtualBox if installed
   - Check Windows Features → Hyper-V (should be enabled if using WHPX)

3. **Recreate AVD:**
   - Android Studio → Device Manager → Delete AVD
   - Create new AVD with x86_64 system image

## Why I Can't Fix This Programmatically

BIOS/UEFI settings are hardware-level firmware configurations that:
- Cannot be changed from within Windows
- Require physical access during boot
- Are security-protected to prevent malware from enabling virtualization

This is a **hardware configuration issue**, not a software problem.

## Helper Scripts

Two PowerShell scripts are available:

1. **`check_emulator.ps1`** - Comprehensive diagnostics
   - Checks virtualization status
   - Verifies Android SDK setup
   - Lists available emulators
   - Shows connected devices
   - Provides recommendations

2. **`launch_emulator.ps1`** - Smart emulator launcher
   - Auto-detects best emulator
   - Waits for emulator to be ready
   - Supports cold boot option
   - Shows device status

Usage:
```powershell
.\check_emulator.ps1      # Run diagnostics
.\launch_emulator.ps1     # Launch emulator
.\launch_emulator.ps1 -EmulatorName pixel6 -ColdBoot  # Launch specific emulator with cold boot
```

