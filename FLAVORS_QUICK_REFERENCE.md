# Flavor Quick Reference Guide

## Building for Different Environments

### Development (Dev)
```powershell
# Build dev APK
flutter build apk --release --flavor dev -d-define=FLAVOR=dev

# Build and distribute dev
.\build_and_distribute.ps1 dev firebase-manual
```

### Test/QA
```powershell
# Build test APK
flutter build apk --release --flavor test -d-define=FLAVOR=test

# Build and distribute test
.\build_and_distribute.ps1 test firebase-manual
```

### Production
```powershell
# Build prod APK
flutter build apk --release --flavor prod -d-define=FLAVOR=prod

# Build and distribute prod
.\build_and_distribute.ps1 prod firebase-manual
```

## Running on Device/Emulator

```powershell
# Run dev
flutter run --release --flavor dev -d-define=FLAVOR=dev

# Run test
flutter run --release --flavor test -d-define=FLAVOR=test

# Run prod
flutter run --release --flavor prod -d-define=FLAVOR=prod
```

## App IDs

- **Dev**: `com.example.familyhub_mvp.dev`
- **Test**: `com.example.familyhub_mvp.test`
- **Prod**: `com.example.familyhub_mvp`

## App Names (as shown on device)

- **Dev**: "FamilyHub Dev"
- **Test**: "FamilyHub Test"
- **Prod**: "FamilyHub"

## Firebase App Distribution Groups

- **Dev**: `dev-testers`
- **Test**: `test-testers`
- **Prod**: `prod-testers`

## Configuration Files

- **Dev**: `lib/config/dev_config.dart`
- **Test**: `lib/config/test_config.dart`
- **Prod**: `lib/config/prod_config.dart`

## Firebase Config Files

- **Dev**: `android/app/src/dev/google-services.json`
- **Test**: `android/app/src/test/google-services.json`
- **Prod**: `android/app/src/prod/google-services.json`

## Using Config in Code

```dart
import 'package:familyhub_mvp/config/config.dart';

// Get current environment
final config = Config.current;
print(config.environmentName); // "Development", "Test", or "Production"

// Check environment
if (Config.isDev) {
  // Dev-specific code
}

// Use Firestore prefix
final collectionName = '${Config.current.firestorePrefix}families';
// Dev: "dev_families"
// Test: "test_families"
// Prod: "families"
```

## Common Workflows

### Daily Development
```powershell
# Work on dev branch, build dev flavor
git checkout develop
flutter run --flavor dev -d-define=FLAVOR=dev
```

### Testing a Fix
```powershell
# Merge to test branch, build test flavor
git checkout release/test
flutter build apk --release --flavor test -d-define=FLAVOR=test
.\build_and_distribute.ps1 test firebase-manual
```

### Production Release
```powershell
# Merge to main, build prod flavor
git checkout main
flutter build apk --release --flavor prod -d-define=FLAVOR=prod
.\build_and_distribute.ps1 prod firebase-manual
```

