# Quick Move Solution - Folder In Use

## The Problem
The folder is locked because Cursor, Dart, Java, and ADB processes are running.

## Solution 1: COPY Instead of MOVE (Easiest)

**This works even with the folder in use:**

```powershell
# Run from ANY PowerShell window (even this one)
Copy-Item 'C:\Users\simon\OneDrive\Desktop\familyhub-MVP' 'C:\Users\simon\Documents\familyhub-MVP' -Recurse -Force
```

Then:
1. Open the NEW location in Cursor: `C:\Users\simon\Documents\familyhub-MVP`
2. Test that everything works
3. Delete the old OneDrive location after confirming

## Solution 2: Close Everything and Move

**Steps:**
1. Close Cursor completely (File > Exit, or kill all processes)
2. Close this terminal
3. Open a NEW PowerShell window (Win+X > Windows PowerShell)
4. Run:
   ```powershell
   cd C:\
   .\C:\Users\simon\OneDrive\Desktop\familyhub-MVP\CLOSE_AND_MOVE.ps1
   ```

Or manually close processes and move:
```powershell
# Close all dev processes
Get-Process -Name Cursor,dart,java,adb -ErrorAction SilentlyContinue | Stop-Process -Force

# Wait a moment
Start-Sleep -Seconds 3

# Move
$dest = 'C:\Users\simon\Documents\familyhub-MVP'
Move-Item 'C:\Users\simon\OneDrive\Desktop\familyhub-MVP' $dest -Force
```

## Recommended: Use COPY

**Copy is safer and works even with processes running:**

```powershell
# Copy the entire project
Copy-Item 'C:\Users\simon\OneDrive\Desktop\familyhub-MVP' 'C:\Users\simon\Documents\familyhub-MVP' -Recurse -Force

# Navigate to new location
cd 'C:\Users\simon\Documents\familyhub-MVP'

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

Then after verifying it works, delete the old OneDrive location.

