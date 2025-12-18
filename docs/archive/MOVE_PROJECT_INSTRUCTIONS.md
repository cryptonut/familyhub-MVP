# Move Project from OneDrive - Safe Instructions

## Why Move?

Your project is currently in `C:\Users\simon\OneDrive\Desktop\familyhub-MVP`

**OneDrive can cause issues with Flutter/Android development:**
- ✅ File locking during builds (especially `google-services.json`)
- ✅ Build artifacts being synced and corrupted
- ✅ Sync conflicts during hot reload
- ✅ Path length issues on Windows
- ✅ Login errors returning due to file sync issues

## Safe Move Options

### Option 1: Documents Folder (Recommended)
```powershell
$dest = 'C:\Users\simon\Documents\familyhub-MVP'
Move-Item 'C:\Users\simon\OneDrive\Desktop\familyhub-MVP' $dest -Force
cd $dest
```

### Option 2: Dev Folder
```powershell
# Create dev folder if needed
New-Item -ItemType Directory -Path 'C:\dev' -Force | Out-Null

$dest = 'C:\dev\familyhub-MVP'
Move-Item 'C:\Users\simon\OneDrive\Desktop\familyhub-MVP' $dest -Force
cd $dest
```

### Option 3: Use the Script
Run `MOVE_PROJECT_SAFELY.ps1` which will:
- Check for running processes
- Let you choose destination
- Move everything safely
- Preserve git, dependencies, and configs

## Steps to Move

1. **Close everything:**
   - Close VS Code/Cursor
   - Close all terminals
   - Stop any `flutter run` processes
   - Stop Android Studio if running

2. **Run the move command** (choose one option above)

3. **Open in new location:**
   - Open VS Code/Cursor in the new folder
   - Or run: `code C:\Users\simon\Documents\familyhub-MVP`

4. **Reinitialize:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## What's Preserved

✅ **Git repository** - All history and remotes preserved
✅ **Dependencies** - `pubspec.yaml` and `pubspec.lock` preserved
✅ **Configuration** - All config files use relative paths
✅ **Project files** - Everything moves intact

## What Gets Regenerated

- `.idea/workspace.xml` - IDE settings (will be recreated)
- `build/` folders - Will be rebuilt
- `.dart_tool/` - Will be regenerated

## After Moving

1. Run `flutter clean` to clear old build artifacts
2. Run `flutter pub get` to refresh dependencies
3. Test login - should be more stable without OneDrive interference
4. If you want to keep it synced, add the new location to OneDrive **after** moving (not recommended for dev folders)

## Troubleshooting

If you get permission errors:
- Run PowerShell as Administrator
- Or move manually through Windows Explorer

If git shows issues:
- Run `git status` - should work fine
- Git uses relative paths, so it's location-independent

