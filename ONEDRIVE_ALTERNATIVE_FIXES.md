# Alternative Solutions for OneDrive Sync Issue

Since right-click doesn't show OneDrive options, try these alternatives:

## Option 1: OneDrive Settings (Recommended)
1. **Open OneDrive Settings**:
   - Click the OneDrive cloud icon in system tray (bottom right)
   - Click the gear icon → **Settings**
   - Or: Right-click OneDrive icon → **Settings**

2. **Go to Sync and backup** tab
3. **Click "Advanced settings"**
4. Look for **"Files On-Demand"** settings
5. You can:
   - Turn off "Files On-Demand" for this folder
   - Or set specific folders to "Always keep on this device"

## Option 2: Use OneDrive Web Interface
1. Go to [OneDrive.com](https://onedrive.live.com)
2. Navigate to: `Desktop > familyhub-MVP > android > app`
3. Right-click `google-services.json`
4. Select **"Always keep on this device"** or **"Download"**

## Option 3: Copy File Outside OneDrive (Quick Fix)
Since the file is critical, let's ensure it persists:

```powershell
# Create a backup outside OneDrive
Copy-Item "android\app\google-services.json" -Destination "$env:USERPROFILE\google-services-backup.json"
```

## Option 4: Add to .gitignore and Keep Local Only
Since this is a sensitive config file, you can:
1. Add to `.gitignore` (if not already)
2. Keep it local and don't sync via OneDrive
3. The file will stay on your machine

## Option 5: Move Entire Project (Nuclear Option)
If OneDrive continues causing issues:
1. Close Android Studio/VS Code
2. Move `familyhub-MVP` folder from `OneDrive\Desktop` to `C:\Users\simon\Desktop`
3. Reopen project in new location
4. Update any IDE workspace settings

## Quick Test: Verify File Persists
Run this to check if file stays after operations:
```powershell
# Check current state
Test-Path "android\app\google-services.json"
Get-Item "android\app\google-services.json" | Select Length, LastWriteTime
```

## Recommended Immediate Action
Since OneDrive context menu isn't working, let's use **Option 3** (backup) and ensure the file is properly included in the build:

```bash
# The file is already in place, just rebuild
flutter clean
flutter pub get
flutter run
```

The file should work even with "Not backed up" status - it just means OneDrive isn't syncing it to cloud, which is actually fine for local development!

