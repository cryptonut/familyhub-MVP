# Quick Start: Android Emulator

## Launch Emulator

You have two emulators available:
- `pixel6` (Google Pixel 6)
- `Medium_Phone_API_35` (Generic medium phone)

### Launch from Command Line:
```bash
flutter emulators --launch pixel6
```

Or from Android Studio:
1. Open Android Studio
2. Tools → Device Manager
3. Click ▶ next to your emulator

## Run Flutter App on Emulator

Once emulator is running:
```bash
flutter devices          # Verify emulator is detected
flutter run              # Run the app
```

## Test Mobile Features

The emulator allows you to test:
- ✅ Camera (virtual camera available)
- ✅ Location services (set via emulator controls)
- ✅ Photo uploads (no CORS issues on mobile)
- ✅ Native permissions
- ✅ Push notifications

## Troubleshooting

**Emulator not detected:**
```bash
adb kill-server
adb start-server
flutter devices
```

**Emulator is slow:**
- Increase RAM in AVD settings (4GB recommended)
- Use x86_64 system images
- Enable hardware acceleration

