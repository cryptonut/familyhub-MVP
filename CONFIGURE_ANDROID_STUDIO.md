# Configure Android Studio for Flutter

## Flutter SDK Location
Your Flutter is installed at: `C:\src\flutter`

## Steps to Configure Android Studio:

1. **Open Android Studio**
2. **Go to File > Settings** (or **Android Studio > Preferences** on Mac)
3. **Navigate to:** Languages & Frameworks > Flutter
4. **Set Flutter SDK path to:** `C:\src\flutter`
5. **Click Apply** and **OK**

## Alternative: Use Flutter Doctor

Run this to verify Flutter is properly configured:
```powershell
flutter doctor -v
```

This will show if Android Studio is detected and if there are any issues.

## After Configuration

Once Flutter is configured in Android Studio:
- The Flutter plugin should work properly
- Device Manager should detect Flutter devices correctly
- You can launch emulators from Android Studio

