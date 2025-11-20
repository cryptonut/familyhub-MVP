# Start Emulator and Test Photo Uploads

## Step 1: Start Android Emulator

### Option A: From Android Studio (Recommended)
1. Open **Android Studio**
2. Click **Tools** → **Device Manager** (or **AVD Manager**)
3. Find **pixel6** in the list
4. Click the **Play button (▶)** next to it
5. Wait for the emulator to fully boot (home screen appears)

### Option B: From Command Line
If you have Android SDK in your PATH:
```powershell
emulator -avd pixel6
```

## Step 2: Verify Emulator is Running

Once the emulator shows the home screen, run:
```powershell
flutter devices
```

You should see something like:
```
sdk gphone64 arm64 • emulator-5554 • android-arm64 • Android 14 (API 34)
```

## Step 3: Run the App on Emulator

```powershell
flutter run -d <device-id>
```

Or just:
```powershell
flutter run
```
(Flutter will auto-select the emulator if it's the only Android device)

## Step 4: Test Photo Upload

1. Navigate to **Photos** tab in the app
2. Click **Upload Photo** button
3. Select a photo from your device/gallery
4. Add a caption (optional)
5. Click **Upload**
6. ✅ Photo should upload successfully (no CORS errors on mobile!)

## Troubleshooting

**Emulator not detected:**
- Make sure emulator is fully booted (home screen visible)
- Run `flutter doctor` to check Android setup
- Try restarting ADB: `adb kill-server && adb start-server` (if adb is in PATH)

**App won't install:**
- Make sure emulator is running Android 5.0+ (API 21+)
- Check `flutter doctor` for Android toolchain issues

**Photo upload still fails:**
- Check Firebase Storage rules in Firebase Console
- Verify you're logged in to the app
- Check emulator logs: `adb logcat` (if adb is available)

