# Enable Virtualization in BIOS - Required for Android Emulator

## Root Cause
Your system has virtualization **disabled in BIOS/UEFI**. This is why the Android emulator cannot use hardware acceleration.

**Evidence:**
- `HyperVRequirementVirtualizationFirmwareEnabled: False`
- `HyperVisorPresent: False`

## Solution: Enable Virtualization in BIOS

### Steps:

1. **Restart your computer**

2. **Enter BIOS/UEFI Setup:**
   - During boot, press the BIOS key (usually one of these):
     - **F2** (most common)
     - **F10** (HP)
     - **F12** (Dell)
     - **Delete** or **Del**
     - **Esc** (some systems)
   - Look for a message like "Press [key] to enter Setup" during boot

3. **Find Virtualization Setting:**
   - Navigate to **Advanced** or **System Configuration** or **Security** tab
   - Look for one of these settings:
     - **Intel Virtualization Technology (VT-x)** - if you have Intel CPU
     - **AMD-V** or **SVM Mode** - if you have AMD CPU
     - **Virtualization Technology**
     - **VT-x** or **Virtualization**

4. **Enable It:**
   - Change the setting from **Disabled** to **Enabled**
   - Save and exit (usually **F10**)

5. **Restart Windows**

6. **After Restart:**
   - Verify virtualization is enabled:
     ```powershell
     Get-ComputerInfo | Select-Object -Property HyperVRequirementVirtualizationFirmwareEnabled
     ```
   - Should show: `True`

7. **Then launch the emulator:**
   ```powershell
   flutter emulators --launch pixel6
   ```

## Why This Is Required

- **x86_64 emulators** require hardware acceleration (virtualization)
- Without it, the emulator cannot run efficiently or at all
- The Android Emulator Hypervisor Driver needs virtualization to work
- Hyper-V also requires virtualization to be enabled

## Alternative (If You Can't Enable Virtualization)

If you cannot enable virtualization (e.g., corporate laptop restrictions), you have two options:

1. **Use ARM64 system image** (much slower, but works without virtualization)
2. **Use a physical Android device** via USB debugging

## After Enabling Virtualization

Once virtualization is enabled:
- The Android Emulator Hypervisor Driver will work
- Or Hyper-V will work (if enabled)
- The emulator will launch successfully

