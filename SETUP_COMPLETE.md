# Dev/Test/Prod Environment Setup - Complete! ✅

## What Was Set Up

### ✅ Flutter Flavors
- **Dev**: `com.example.familyhub_mvp.dev` - "FamilyHub Dev"
- **Test**: `com.example.familyhub_mvp.test` - "FamilyHub Test"  
- **Prod**: `com.example.familyhub_mvp` - "FamilyHub"

### ✅ Configuration Files
- `lib/config/app_config.dart` - Base configuration interface
- `lib/config/dev_config.dart` - Development settings
- `lib/config/test_config.dart` - Test/QA settings
- `lib/config/prod_config.dart` - Production settings
- `lib/config/config.dart` - Configuration manager

### ✅ Android Build Configuration
- Updated `android/app/build.gradle.kts` with product flavors
- Created flavor-specific directories:
  - `android/app/src/dev/`
  - `android/app/src/test/`
  - `android/app/src/prod/`
- Moved production `google-services.json` to `android/app/src/prod/`

### ✅ Build Scripts
- Updated `build_and_distribute.ps1` to support flavors
- Usage: `.\build_and_distribute.ps1 [flavor] [method]`

### ✅ Documentation
- `ENVIRONMENT_SETUP_GUIDE.md` - Overview and architecture
- `FIREBASE_MULTI_ENV_SETUP.md` - Firebase setup instructions
- `FLAVORS_QUICK_REFERENCE.md` - Quick command reference

## Next Steps (Required)

### 1. Set Up Firebase Apps

You need to create Firebase app registrations for Dev and Test environments:

1. **Dev Environment**:
   - Go to Firebase Console → Project settings
   - Add Android app with package: `com.example.familyhub_mvp.dev`
   - Download `google-services.json` → Place in `android/app/src/dev/`
   - Update `lib/config/dev_config.dart` with the App ID

2. **Test Environment**:
   - Go to Firebase Console → Project settings
   - Add Android app with package: `com.example.familyhub_mvp.test`
   - Download `google-services.json` → Place in `android/app/src/test/`
   - Update `lib/config/test_config.dart` with the App ID

See `FIREBASE_MULTI_ENV_SETUP.md` for detailed instructions.

### 2. Create Firebase App Distribution Groups

1. Go to Firebase Console → App Distribution → Testers & Groups
2. Create groups:
   - `dev-testers`
   - `test-testers`
   - `prod-testers`
3. Add testers to each group

### 3. Test the Setup

```powershell
# Test dev build
.\build_and_distribute.ps1 dev firebase-manual

# Test test build
.\build_and_distribute.ps1 test firebase-manual

# Test prod build (should work now)
.\build_and_distribute.ps1 prod firebase-manual
```

## Usage Examples

### Build and Distribute Dev
```powershell
.\build_and_distribute.ps1 dev firebase-manual
```

### Build and Distribute Test
```powershell
.\build_and_distribute.ps1 test firebase-manual
```

### Build and Distribute Prod
```powershell
.\build_and_distribute.ps1 prod firebase-manual
```

### Run on Device
```powershell
# Dev
flutter run --release --flavor dev --dart-define=FLAVOR=dev

# Test
flutter run --release --flavor test --dart-define=FLAVOR=test

# Prod
flutter run --release --flavor prod --dart-define=FLAVOR=prod
```

## Benefits

✅ **Isolation**: Each environment has separate app ID - can install all 3 on same device  
✅ **Safety**: Can't accidentally deploy wrong environment  
✅ **Testing**: Test environment mirrors production  
✅ **Flexibility**: Developers work without affecting testers  
✅ **Organization**: Clear separation of concerns  

## File Structure

```
familyhub-MVP/
├── android/app/
│   ├── build.gradle.kts (flavors configured)
│   ├── src/
│   │   ├── dev/
│   │   │   ├── google-services.json (TODO: Add)
│   │   │   └── README.md
│   │   ├── test/
│   │   │   ├── google-services.json (TODO: Add)
│   │   │   └── README.md
│   │   └── prod/
│   │       ├── google-services.json ✅
│   │       └── README.md
├── lib/
│   ├── config/
│   │   ├── app_config.dart ✅
│   │   ├── config.dart ✅
│   │   ├── dev_config.dart ✅ (TODO: Update App ID)
│   │   ├── test_config.dart ✅ (TODO: Update App ID)
│   │   └── prod_config.dart ✅
│   └── main.dart (updated to use config) ✅
├── build_and_distribute.ps1 (updated for flavors) ✅
└── Documentation files ✅
```

## Questions?

- See `FLAVORS_QUICK_REFERENCE.md` for common commands
- See `FIREBASE_MULTI_ENV_SETUP.md` for Firebase setup
- See `ENVIRONMENT_SETUP_GUIDE.md` for architecture details

