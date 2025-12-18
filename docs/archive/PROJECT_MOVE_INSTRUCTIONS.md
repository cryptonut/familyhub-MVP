# Move Project to D: Drive - Instructions

## ⚠️ Important: Close Your IDE First!

Before moving the project, **close Cursor/VS Code** completely. Open files can prevent the move.

## Quick Steps

1. **Close Cursor/VS Code** (and any other editors)

2. **Open PowerShell** (Run as Administrator if symlink creation fails)

3. **Navigate to project directory:**
   ```powershell
   cd C:\Users\simon\Documents\familyhub-MVP
   ```

4. **Run the move script:**
   ```powershell
   .\MOVE_PROJECT_NOW.ps1
   ```

   OR run the commands directly:
   ```powershell
   # Move project
   Move-Item "C:\Users\simon\Documents\familyhub-MVP" "D:\familyhub-MVP" -Force
   
   # Create symlink (so it still appears in Documents)
   New-Item -ItemType SymbolicLink -Path "C:\Users\simon\Documents\familyhub-MVP" -Target "D:\familyhub-MVP"
   ```

5. **Reopen Cursor** and open the project from `D:\familyhub-MVP`

## What This Does

- ✅ Moves entire project from C: to D: drive
- ✅ Creates symbolic link in Documents (so it still appears there)
- ✅ Frees up space on C: drive (typically 500 MB - 2 GB)
- ✅ Project works exactly the same, just on different drive

## After Moving

1. Open project in Cursor from: `D:\familyhub-MVP`
2. Run: `flutter pub get`
3. Try building: `flutter run`

## If Move Fails

If you get "file is in use" errors:
- Close ALL programs (IDE, terminals, file explorers)
- Try again
- Or move manually using File Explorer (drag & drop)

## Verify Success

Check C: drive space - it should have increased by ~500 MB - 2 GB!
