# Fix OneDrive "Not Backed Up" Issue for google-services.json

## Problem
The `google-services.json` file shows "Not backed up" status in OneDrive, which can cause sync issues and the file to disappear from builds.

## Solution Options

### Option 1: Always Keep File on This Device (Recommended)
1. Right-click on `android/app/google-services.json` in File Explorer
2. Select **OneDrive** → **Always keep on this device**
3. This ensures the file is always available locally, even if OneDrive sync has issues

### Option 2: Exclude from OneDrive Sync
1. Right-click on `android/app/google-services.json`
2. Select **OneDrive** → **Free up space** or **Remove from OneDrive**
3. The file will remain locally but won't sync to cloud

### Option 3: Move Project Outside OneDrive
If you continue having sync issues:
1. Move the entire `familyhub-MVP` folder to `C:\Users\simon\Desktop\` (outside OneDrive)
2. Update any IDE project paths
3. Rebuild the project

## Verify File Persists After Rebuild
After applying the fix, verify the file stays in place:
```bash
flutter clean
flutter pub get
# Check file still exists
Test-Path android\app\google-services.json
```

## Current Status
✅ File exists: `android/app/google-services.json` (1336 bytes)
✅ SHA-1 matches Firebase Console
✅ Configuration is correct
⚠️ OneDrive sync status: "Not backed up" - apply fix above

