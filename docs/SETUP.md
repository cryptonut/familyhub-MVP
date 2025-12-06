# Family Hub MVP - Setup Guide

This guide provides step-by-step instructions for setting up the Family Hub MVP development environment.

## Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / VS Code with Flutter extensions
- Firebase account
- Git

## Initial Setup

### 1. Clone Repository

```bash
git clone https://github.com/cryptonut/familyhub-MVP.git
cd familyhub-MVP
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication (Email/Password)
3. Create Firestore database in **Native mode** (not Datastore mode)
4. Download `google-services.json` for each flavor:
   - Dev: `android/app/src/dev/google-services.json`
   - QA: `android/app/src/test/google-services.json`
   - Prod: `android/app/src/main/google-services.json`

### 4. Configure API Keys

1. Go to Google Cloud Console
2. Enable required APIs:
   - Cloud Firestore API
   - Firebase Authentication API
   - Google Maps API (if using location features)
3. Configure API key restrictions:
   - Application restrictions: Android apps
   - API restrictions: Select specific APIs

### 5. Environment Configuration

Configure environment-specific settings in:
- `lib/config/dev_config.dart` - Development
- `lib/config/qa_config.dart` - QA/Test
- `lib/config/prod_config.dart` - Production

**Required Configuration:**
- Firebase project ID
- Firebase app IDs
- Agora credentials (for video calls)
- WebSocket URLs (if using real-time features)

## Running the App

### Development

```bash
flutter run --flavor dev
```

### QA/Test

```bash
flutter run --flavor qa
```

### Production

```bash
flutter run --flavor prod
```

## Building Releases

### Android APK

```bash
# Dev
flutter build apk --flavor dev --release

# QA
flutter build apk --flavor qa --release

# Prod
flutter build apk --flavor prod --release
```

### Android App Bundle

```bash
flutter build appbundle --flavor prod --release
```

## Troubleshooting

### Common Issues

1. **Firestore Unavailable Error**
   - Ensure Firestore is in **Native mode** (not Datastore mode)
   - Check API key restrictions
   - Verify network connectivity

2. **Authentication Timeout**
   - Check API key restrictions
   - Verify OAuth client configuration
   - Ensure SHA-1 fingerprint is added to Firebase

3. **Build Errors**
   - Run `flutter clean`
   - Run `flutter pub get`
   - Check `google-services.json` paths

## Additional Resources

- [Firebase Setup Guide](FIREBASE_SETUP.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Contributing Guidelines](CONTRIBUTING.md)

