# Firebase Setup Guide

This app uses Firebase for authentication and data storage. Follow these steps to set up Firebase:

## 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select an existing project
3. Follow the setup wizard

## 2. Add Firebase to Your Flutter App

### For Android:

1. In Firebase Console, click the Android icon to add an Android app
2. Register your app with package name: `com.example.familyhub_mvp` (or your package name)
3. Download `google-services.json`
4. Place it in `android/app/` directory ✅ **DONE**
5. The Gradle files have been updated automatically ✅ **DONE**

**What was updated:**
- `android/settings.gradle.kts` - Added Google Services plugin
- `android/app/build.gradle.kts` - Applied Google Services plugin

### For iOS:

1. In Firebase Console, click the iOS icon to add an iOS app
2. Register your app with bundle ID
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/` directory
5. Open `ios/Runner.xcworkspace` in Xcode
6. Right-click on `Runner` folder and select "Add Files to Runner"
7. Select `GoogleService-Info.plist`

### For Web:

1. In Firebase Console, click the Web icon to add a Web app
2. Copy the Firebase configuration
3. Create `lib/firebase_options.dart` (or use FlutterFire CLI)

## 3. Enable Authentication

1. In Firebase Console, go to **Authentication** > **Sign-in method**
2. Enable **Email/Password** authentication

## 4. Set Up Firestore Database

1. In Firebase Console, go to **Firestore Database**
2. Click "Create database"
3. Start in **test mode** (for development)
4. Choose your location

## 5. Firestore Security Rules (Development)

For development, use these rules (update for production):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Family data
    match /families/{familyId}/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 6. Install FlutterFire CLI (Optional but Recommended)

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This will automatically configure Firebase for all platforms.

## 7. Update Firebase Initialization (if using FlutterFire CLI)

If you used FlutterFire CLI, update `lib/main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const FamilyHubApp());
}
```

**Note:** The current setup uses `Firebase.initializeApp()` without options, which works for Android. If you add iOS/Web, use FlutterFire CLI for better cross-platform support.

## 8. Run the App

```bash
flutter pub get
flutter run
```

## Important Notes

- **Security Rules**: The default rules above are for development only. Update them for production to ensure proper security.
- **Family ID**: Currently, each user gets their own family ID. To share data between family members, implement a family invitation system.
- **Data Structure**: Data is organized as:
  - `users/{userId}` - User profiles
  - `families/{familyId}/events` - Calendar events
  - `families/{familyId}/tasks` - Tasks
  - `families/{familyId}/messages` - Chat messages
  - `families/{familyId}/members` - Location data

## Troubleshooting

- **"FirebaseApp not initialized"**: Make sure you've completed Firebase setup and added configuration files
- **"Permission denied"**: Check your Firestore security rules
- **Authentication errors**: Ensure Email/Password authentication is enabled in Firebase Console
- **Gradle sync errors**: Make sure `google-services.json` is in `android/app/` directory

## Android Setup Status ✅

- [x] `google-services.json` placed in `android/app/`
- [x] Google Services plugin added to `settings.gradle.kts`
- [x] Google Services plugin applied in `app/build.gradle.kts`
- [ ] Enable Email/Password authentication in Firebase Console
- [ ] Create Firestore database
- [ ] Set up Firestore security rules
