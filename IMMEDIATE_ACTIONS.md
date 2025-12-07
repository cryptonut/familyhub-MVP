# Immediate Actions to Free C: Drive Space

## ⚠️ Current Status: 80.9 MB free (CRITICAL)

The automated migration may not have found the expected files. Here are **immediate actions** you can take:

## 🚀 FASTEST FIX: Windows Disk Cleanup (Do This First!)

### Option 1: GUI Method
1. Press `Win + R`
2. Type `cleanmgr` and press Enter
3. Select **C: drive**
4. Check **ALL boxes**:
   - ✅ Temporary files
   - ✅ Recycle Bin  
   - ✅ Windows Update Cleanup
   - ✅ System error memory dump files
   - ✅ Previous Windows installations
5. Click **"Clean up system files"** (button at bottom - requires admin)
6. Select C: drive again
7. Check all boxes again
8. Click **OK**

**Expected:** 1-5 GB freed immediately

### Option 2: Command Line (Run PowerShell as Admin)
```powershell
cleanmgr /d C: /verylowdisk
```

---

## 📦 Move Your Flutter Project (Safe & Effective)

Your project with build artifacts can be moved to D: drive:

```powershell
# 1. Clean build artifacts first
cd C:\Users\simon\Documents\familyhub-MVP
flutter clean

# 2. Move project to D:
Move-Item "C:\Users\simon\Documents\familyhub-MVP" "D:\familyhub-MVP" -Force

# 3. (Optional) Create shortcut in Documents
New-Item -ItemType SymbolicLink -Path "C:\Users\simon\Documents\familyhub-MVP" -Target "D:\familyhub-MVP"
```

**Expected:** 500 MB - 2 GB freed

**Note:** After moving, open the project from `D:\familyhub-MVP` in your IDE.

---

## 🧹 Clean Flutter Build Artifacts

Even if you don't move the project, clean build files:

```powershell
cd C:\Users\simon\Documents\familyhub-MVP

# Clean Flutter
flutter clean

# Remove build directories
Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "android\app\build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "android\.gradle" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "android\build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force ".dart_tool" -ErrorAction SilentlyContinue
```

**Expected:** 200 MB - 1 GB freed

---

## 📥 Move Downloads Folder

```powershell
# Check size
$size = (Get-ChildItem "C:\Users\simon\Downloads" -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
Write-Host "Downloads folder: $([math]::Round($size,2)) GB"

# If > 1 GB, move it
if ($size -gt 1) {
    New-Item -ItemType Directory -Path "D:\Downloads" -Force | Out-Null
    Move-Item "C:\Users\simon\Downloads\*" "D:\Downloads\" -Force
    Write-Host "Moved to D:\Downloads"
    Write-Host "Update default location: Settings > System > Storage > Change where new content is saved"
}
```

---

## 🗑️ Quick Cleanups

```powershell
# Empty Recycle Bin
Clear-RecycleBin -Force -ErrorAction SilentlyContinue

# Clean temp files
Remove-Item "$env:LOCALAPPDATA\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clean browser caches
Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue
```

---

## 🔍 Find What's Using Space

Run this to see what's actually taking space:

```powershell
# Find large files in your user directory
Get-ChildItem "C:\Users\simon" -Recurse -File -ErrorAction SilentlyContinue | 
    Where-Object {$_.Length -gt 50MB} | 
    Sort-Object Length -Descending | 
    Select-Object -First 20 FullName, @{Name="SizeMB";Expression={[math]::Round($_.Length/1MB,2)}}
```

---

## 📋 Priority Order (Do These First)

1. ✅ **Windows Disk Cleanup** - Easiest, safest, immediate results
2. ✅ **Clean Flutter builds** - Quick, safe
3. ✅ **Move project to D:** - If comfortable
4. ✅ **Empty Recycle Bin** - Instant
5. ✅ **Clean temp files** - Safe

---

## ✅ After Freeing Space

Once you have **at least 2-3 GB free**:

1. Try building your Flutter project:
   ```powershell
   cd D:\familyhub-MVP  # or C:\Users\simon\Documents\familyhub-MVP if not moved
   flutter clean
   flutter pub get
   flutter run
   ```

2. The build should succeed now!

---

## 🆘 If Still Not Enough Space

If after all this you still have < 1 GB:

1. **Uninstall unused programs:**
   - Settings > Apps > Uninstall unused apps

2. **Move more user folders:**
   - Pictures, Videos, Music to D: drive

3. **Check for duplicate files:**
   - Use a tool like Duplicate Cleaner

4. **Consider moving Windows user profile:**
   - Advanced: Move entire `C:\Users\simon` to D: (complex, research first)

---

**Start with Windows Disk Cleanup - it's the fastest and safest!** 🚀
