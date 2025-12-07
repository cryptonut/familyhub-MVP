# Quick Space Fix - Immediate Actions

## Current Situation
- **C: Drive:** 80.9 MB free (CRITICAL)
- **Status:** Migration may not have found files, or they're in different locations

## Immediate Actions You Can Take

### 1. Run Windows Disk Cleanup (Easiest - Can free 1-5 GB)

**Method 1: GUI**
1. Press `Win + R`
2. Type `cleanmgr` and press Enter
3. Select C: drive
4. Check all boxes (especially "Temporary files", "Recycle Bin", "Windows Update Cleanup")
5. Click "Clean up system files" (requires admin)
6. Click OK

**Method 2: Command Line (Run as Admin)**
```powershell
cleanmgr /d C:
```

### 2. Move Your Project to D: Drive

Since your Flutter project is taking space, move it:

```powershell
# Move entire project
Move-Item "C:\Users\simon\Documents\familyhub-MVP" "D:\familyhub-MVP" -Force

# Create symbolic link (optional - so it appears in Documents)
New-Item -ItemType SymbolicLink -Path "C:\Users\simon\Documents\familyhub-MVP" -Target "D:\familyhub-MVP"
```

**Expected Space Freed:** 500 MB - 2 GB (depending on build artifacts)

### 3. Clean Flutter Build Artifacts

```powershell
cd C:\Users\simon\Documents\familyhub-MVP
flutter clean
```

Then delete build folders:
```powershell
Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "android\app\build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "android\.gradle" -ErrorAction SilentlyContinue
```

### 4. Move Downloads Folder

```powershell
# Check size first
$size = (Get-ChildItem "C:\Users\simon\Downloads" -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
Write-Host "Downloads: $([math]::Round($size,2)) GB"

# If large, move it
if ($size -gt 1) {
    New-Item -ItemType Directory -Path "D:\Downloads" -Force | Out-Null
    Move-Item "C:\Users\simon\Downloads\*" "D:\Downloads\" -Force
    # Update Windows default location in Settings > System > Storage
}
```

### 5. Check for Large Files

Run this to find large files:
```powershell
Get-ChildItem "C:\Users\simon" -Recurse -File -ErrorAction SilentlyContinue | 
    Where-Object {$_.Length -gt 100MB} | 
    Sort-Object Length -Descending | 
    Select-Object -First 20 FullName, @{Name="SizeMB";Expression={[math]::Round($_.Length/1MB,2)}}
```

### 6. Empty Recycle Bin

```powershell
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
```

### 7. Check Windows Update Files

```powershell
# Clean Windows Update files (requires admin)
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
```

## Automated Script

I've created `emergency_space_free.ps1` - run it:

```powershell
.\emergency_space_free.ps1
```

This will:
- Find and move development caches
- Clean temp files
- Show detailed log

## What to Check

1. **Are development tools installed?**
   - Check if Flutter is installed: `flutter --version`
   - Check if Android SDK exists: Look in `C:\Users\simon\AppData\Local\Android`

2. **Where is space actually being used?**
   - Run: `.\find_large_files.ps1`
   - Check the CSV output

3. **Can you move the project?**
   - Moving the entire project to D: is safe and will free space immediately

## Priority Order

1. **Windows Disk Cleanup** (easiest, immediate)
2. **Move project to D:** (if you're comfortable)
3. **Clean Flutter builds** (safe)
4. **Move Downloads** (if large)
5. **Find and move other large files**

## After Freeing Space

Once you have at least 2-3 GB free:
1. Try building your Flutter project again
2. The build should succeed now

---

**Most Important:** Run Windows Disk Cleanup first - it's the safest and easiest way to free space immediately!
