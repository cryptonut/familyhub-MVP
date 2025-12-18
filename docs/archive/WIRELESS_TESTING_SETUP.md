# Wireless Testing Setup - Pre Play Store

Test your app on phones without USB tethering! Here are two options:

## Option 1: Firebase App Distribution (Recommended) ⭐

**Best for**: Easy distribution to multiple testers, automatic updates, crash reporting

### Setup Steps

#### 1. Enable Firebase App Distribution

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. In the left menu, click **App Distribution** (under "Release & Monitor")
4. If not enabled, click **Get started** and follow the prompts

#### 2. Install Firebase CLI (if not already installed)

```bash
npm install -g firebase-tools
```

#### 3. Login to Firebase CLI

```bash
firebase login
```

#### 4. Build Your APK

```bash
flutter build apk --release
```

This creates: `build/app/outputs/flutter-apk/app-release.apk`

#### 5. Distribute via Firebase App Distribution

**Option A: Using Firebase CLI**

```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_APP_ID \
  --groups "testers" \
  --release-notes "Test build - $(date +%Y-%m-%d)"
```

**To get your App ID:**
1. Firebase Console → Project Settings
2. Under "Your apps" → Android app
3. Copy the "App ID" (format: `1:559662117534:android:a59145c8a69587aee7c18f`)

**Option B: Using Firebase Console (Easier)**

1. Go to Firebase Console → **App Distribution**
2. Click **Upload release**
3. Select your APK: `build/app/outputs/flutter-apk/app-release.apk`
4. Add release notes (optional)
5. Click **Next**
6. Add testers:
   - Enter email addresses of testers
   - Or create a tester group
7. Click **Distribute**

#### 6. Testers Install the App

Testers will receive an email with:
- Download link
- Installation instructions
- Release notes

They click the link, download, and install (may need to allow "Install from unknown sources" on Android).

---

## Option 2: Manual APK Sharing (Simple)

**Best for**: Quick testing with a few people, no setup needed

### Steps

#### 1. Build APK

```bash
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

#### 2. Share the APK

**Option A: Email**
- Attach the APK to an email
- Send to testers
- They download and install

**Option B: Cloud Storage**
- Upload to Google Drive, Dropbox, or OneDrive
- Share the link
- Testers download and install

**Option C: QR Code**
- Upload APK to a file sharing service
- Generate QR code for the download link
- Testers scan and download

#### 3. Installation on Testers' Phones

Testers need to:
1. Download the APK
2. Open the file
3. Allow "Install from unknown sources" if prompted
4. Tap "Install"
5. Open the app

---

## Option 3: ADB Over WiFi (For Development)

**Best for**: Continuous development testing, hot reload still works

### Setup (One-time, requires initial USB connection)

#### 1. Connect via USB (first time only)

```bash
adb devices
```

#### 2. Connect to WiFi

```bash
adb tcpip 5555
```

#### 3. Find Phone's IP Address

On your phone: Settings → About phone → Status → IP address
Or use:
```bash
adb shell ip addr show wlan0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1
```

#### 4. Connect Wirelessly

```bash
adb connect YOUR_PHONE_IP:5555
```

Example:
```bash
adb connect 192.168.1.100:5555
```

#### 5. Verify Connection

```bash
adb devices
```

You should see your device listed with its IP address.

#### 6. Run Flutter App Wirelessly

```bash
flutter run --release
```

**Note**: Phone and computer must be on the same WiFi network.

---

## Comparison

| Method | Setup Time | Best For | Updates | Crash Reports |
|--------|-----------|----------|---------|---------------|
| **Firebase App Distribution** | 5-10 min | Multiple testers | Automatic | Yes |
| **Manual APK Sharing** | 2 min | Quick testing | Manual | No |
| **ADB Over WiFi** | 5 min | Development | Hot reload | No |

---

## Recommended Workflow

1. **Development**: Use ADB over WiFi for daily testing
2. **Beta Testing**: Use Firebase App Distribution for family/friends
3. **Quick Tests**: Use manual APK sharing for one-off tests

---

## Troubleshooting

### "Install blocked" on Android

Testers need to enable "Install from unknown sources":
1. Settings → Security → Unknown sources (or Install unknown apps)
2. Allow for the browser/file manager used to download

### APK won't install

- Check Android version compatibility
- Ensure APK is for correct architecture (arm64-v8a, armeabi-v7a, or universal)
- Try building a universal APK: `flutter build apk --release --split-per-abi`

### Firebase App Distribution not showing

- Make sure you're on the Blaze (pay-as-you-go) plan (free tier works)
- App Distribution is free for up to 100 testers

---

## Next Steps

1. Choose your preferred method
2. Build and distribute your first test build
3. Get feedback from testers
4. Iterate and improve!

**Ready to test wirelessly!** 🚀

