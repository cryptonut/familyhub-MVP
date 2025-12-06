# Android Emulator Quick Start Guide

## 🚀 Fast Track (If Virtualization is Already Enabled)

1. **Check status:**
   ```powershell
   .\check_emulator.ps1
   ```

2. **Launch emulator:**
   ```powershell
   .\launch_emulator.ps1
   ```

3. **Run app:**
   ```powershell
   flutter run
   ```

## ⚠️ If Emulator is Slow/Crashy

### Step 1: Check Virtualization
```powershell
.\check_emulator.ps1
```

If virtualization is **DISABLED**, you **MUST** enable it in BIOS:
- See `FINAL_EMULATOR_SOLUTION.md` for detailed BIOS instructions
- Restart computer → Press F2/F10/Del during boot
- Enable "Intel Virtualization Technology (VT-x)" or "AMD-V"
- Save and restart

### Step 2: Verify After BIOS Change
```powershell
Get-ComputerInfo | Select-Object -Property HyperVRequirementVirtualizationFirmwareEnabled
```
Should show: `True`

### Step 3: Optimize AVD Configuration
- See `OPTIMIZED_AVD_CONFIG.md` for detailed setup
- Use x86_64 system images (not ARM64)
- Allocate 4GB RAM
- Use Hardware GLES 2.0 graphics
- Enable 2-4 CPU cores

### Step 4: Launch and Test
```powershell
.\launch_emulator.ps1
flutter run
```

## 📋 Common Commands

```powershell
# Diagnostics
.\check_emulator.ps1

# Launch emulator
.\launch_emulator.ps1
.\launch_emulator.ps1 -EmulatorName pixel6
.\launch_emulator.ps1 -ColdBoot

# Flutter commands
flutter emulators                    # List available emulators
flutter devices                      # List connected devices
flutter run                          # Run app on connected device
flutter run -d <device_id>          # Run on specific device

# ADB commands
adb devices                          # List Android devices
adb kill-server                     # Restart ADB
adb start-server
```

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| Emulator won't start | Enable virtualization in BIOS |
| Emulator is very slow | Use x86_64 system image, enable hardware acceleration |
| Emulator crashes | Cold boot: `.\launch_emulator.ps1 -ColdBoot` |
| "No devices found" | Wait for emulator to fully boot, then run `flutter devices` |
| Build is slow | First build is normal (10-15 min). Subsequent builds are faster. |

## 📚 Full Documentation

- **`FINAL_EMULATOR_SOLUTION.md`** - Complete solution with BIOS instructions
- **`OPTIMIZED_AVD_CONFIG.md`** - Detailed AVD configuration guide
- **`check_emulator.ps1`** - Diagnostic script
- **`launch_emulator.ps1`** - Smart emulator launcher

## 💡 Alternative: Use Physical Device

**Physical devices are often faster than emulators and don't require virtualization!**

### Quick Setup:
1. **Enable USB Debugging:**
   - Settings → About Phone → Tap "Build Number" 7 times
   - Settings → Developer Options → Enable "USB Debugging"
2. **Connect via USB** and allow debugging when prompted
3. **Verify connection:**
   ```powershell
   .\check_usb_device.ps1
   ```
4. **Run your app:**
   ```powershell
   flutter run
   ```

**Full guide:** See `USB_DEVICE_SETUP.md` for detailed instructions and troubleshooting.

