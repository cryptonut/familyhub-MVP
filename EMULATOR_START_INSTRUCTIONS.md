# Starting the Android Emulator

The emulator has been launched in the background, but it may need to be started interactively. Here are your options:

## ✅ Check if Emulator Window Opened

Look for an **Android Emulator** window on your screen. It may be:
- Behind other windows
- On a different monitor
- Minimized in the taskbar

If you see it, wait for it to fully boot (showing the Android home screen).

## Option 1: Start from Android Studio (Most Reliable)

1. **Open Android Studio**
2. Click **Tools** → **Device Manager** (or **AVD Manager**)
3. Find **pixel6** in the list
4. Click the **▶ Play button** next to it
5. Wait 1-2 minutes for the emulator to boot
6. You'll see the Android home screen when ready

## Option 2: Start from Command Line (Interactive)

Open a **new PowerShell window** and run:
```powershell
& "C:\Users\simon\AppData\Local\Android\sdk\emulator\emulator.exe" -avd pixel6
```

**Important**: Keep this window open - the emulator window will appear.

## Option 3: Use Flutter Command (May Need Terminal to Stay Open)

```powershell
flutter emulators --launch pixel6
```

## Verify Emulator is Running

Once you see the Android home screen in the emulator window, run:
```powershell
flutter devices
```

You should see something like:
```
sdk gphone64 arm64 • emulator-5554 • android-arm64 • Android 14 (API 34)
```

## Then Run Your App

```powershell
flutter run
```

Flutter will automatically detect and use the emulator.

## Troubleshooting

**No emulator window appeared:**
- Try Option 1 (Android Studio) - most reliable
- Check Windows Task Manager for "emulator" or "qemu" processes
- Restart your computer if emulator processes are stuck

**Emulator opens but Flutter doesn't detect it:**
- Wait a bit longer (emulator needs to fully boot)
- Run `flutter devices` again
- Try `adb kill-server && adb start-server` (if adb is in PATH)

**Emulator is very slow:**
- Close other applications
- Increase emulator RAM in AVD settings (4GB recommended)
- Use x86_64 system images instead of ARM

