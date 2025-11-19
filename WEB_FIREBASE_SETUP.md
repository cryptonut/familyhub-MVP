# Firebase Web Configuration Guide

If you're running the app on web and getting the error:
```
FirebaseOptions cannot be null when creating the default app.
```

You need to add Firebase web configuration. Here's how:

## Step 1: Get Your Web Firebase Config

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click the gear icon ⚙️ next to "Project Overview"
4. Select **Project settings**
5. Scroll down to **Your apps** section
6. If you don't have a Web app yet:
   - Click the **Web icon** (`</>`)
   - Register your app with a nickname (e.g., "Family Hub Web")
   - Click **Register app**
7. Copy the Firebase configuration object (it looks like this):

```javascript
const firebaseConfig = {
  apiKey: "AIzaSy...",
  authDomain: "family-hub-71ff0.firebaseapp.com",
  projectId: "family-hub-71ff0",
  storageBucket: "family-hub-71ff0.firebasestorage.app",
  messagingSenderId: "559662117534",
  appId: "1:559662117534:web:..."
};
```

## Step 2: Update firebase_options.dart

Open `lib/firebase_options.dart` and update the `web` section:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_API_KEY_HERE',
  appId: 'YOUR_APP_ID_HERE',
  messagingSenderId: '559662117534',
  projectId: 'family-hub-71ff0',
  authDomain: 'family-hub-71ff0.firebaseapp.com',
  storageBucket: 'family-hub-71ff0.firebasestorage.app',
);
```

Replace:
- `YOUR_API_KEY_HERE` with the `apiKey` from Firebase Console
- `YOUR_APP_ID_HERE` with the `appId` from Firebase Console

## Step 3: Update the currentPlatform getter

Make sure the `currentPlatform` getter includes web:

```dart
if (kIsWeb) {
  return web;  // Make sure this line exists
}
```

## Alternative: Run on Android Instead

If you don't need web support right now, you can run the app on Android:

```bash
flutter run -d android
```

Or check available devices:
```bash
flutter devices
```

## Quick Fix: Disable Web Temporarily

If you want to prevent the app from running on web until you configure it, you can add this check in `main.dart`:

```dart
if (kIsWeb) {
  throw UnsupportedError('Web support requires Firebase web configuration');
}
```

But it's better to just add the web config following the steps above!

