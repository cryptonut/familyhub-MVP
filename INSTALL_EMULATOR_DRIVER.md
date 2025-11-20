# Install Android Emulator Hypervisor Driver

The Android Emulator needs a hypervisor driver to run. Here's how to install it:

## Option 1: Run the Installer Script (Recommended)

1. **Open PowerShell as Administrator:**
   - Press `Win + X`
   - Select "Windows PowerShell (Admin)" or "Terminal (Admin)"

2. **Navigate to the driver directory:**
   ```powershell
   cd "$env:LOCALAPPDATA\Android\Sdk\emulator\drivers"
   ```

3. **Run the installer:**
   ```powershell
   .\Install_Drivers.bat
   ```

4. **Follow the prompts** - it will install the driver and may ask you to restart.

5. **After restart**, try launching the emulator again.

## Option 2: Install via Android Studio

1. Open Android Studio
2. Go to **Tools → SDK Manager**
3. Click the **SDK Tools** tab
4. Check **Android Emulator Hypervisor Driver for AMD Processors** (or Intel if you have Intel)
5. Click **Apply** and let it install
6. Restart your computer if prompted

## Option 3: Use ARM64 System Image (Slower, but works without driver)

If you can't install the driver, you can create a new AVD with an ARM64 system image:

1. Open Android Studio
2. Go to **Tools → Device Manager**
3. Click **Create Device**
4. Choose a device (e.g., Pixel 6)
5. When selecting a system image, choose an **ARM64** image instead of x86_64
6. This will be slower but doesn't require the hypervisor driver

## Verify Installation

After installing, check if the driver is installed:
```powershell
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
& "$env:ANDROID_HOME\emulator\emulator.exe" -accel-check
```

You should see something like:
```
accel: 1
HAXM version 7.x.x (x) is installed and usable.
```

