# Free Up C: Drive Space - Safe Items to Move

## Current Situation
- C: drive has only **8.58 GB free** of 118 GB (~7% free)
- D: drive has **1.81 TB free** (plenty of space)

## Safe Items to Move to D: Drive

### 1. **Flutter/Dart Caches** (Can free 5-15 GB)
These are safe to move and won't affect your project:

**Flutter Pub Cache:**
```powershell
# Create new location
New-Item -ItemType Directory -Path "D:\Flutter\Pub\Cache" -Force

# Move existing cache (if it exists)
if (Test-Path "$env:LOCALAPPDATA\Pub\Cache") {
    Move-Item "$env:LOCALAPPDATA\Pub\Cache" "D:\Flutter\Pub\Cache" -Force
}

# Create symlink
New-Item -ItemType SymbolicLink -Path "$env:LOCALAPPDATA\Pub\Cache" -Target "D:\Flutter\Pub\Cache"
```

**Flutter Build Cache:**
```powershell
# Set environment variable (add to system PATH)
[System.Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "D:\Flutter", "User")
```

### 2. **Gradle Cache** (Can free 2-10 GB)
We already configured Gradle to use C: drive, but we can move it to D: instead:

**Update `android/gradle.properties`:**
```properties
# Change from C: to D:
systemProp.gradle.user.home=D\:\\Users\\simon\\.gradle
```

**Then move existing cache:**
```powershell
if (Test-Path "$env:USERPROFILE\.gradle") {
    Move-Item "$env:USERPROFILE\.gradle" "D:\Users\simon\.gradle" -Force
}
```

### 3. **Android SDK** (Can free 10-30 GB)
**Option A: Move entire Android SDK**
```powershell
# Find current location (usually in AppData\Local\Android)
$androidSdk = "$env:LOCALAPPDATA\Android"

# Move to D:
if (Test-Path $androidSdk) {
    Move-Item $androidSdk "D:\Android" -Force
}

# Create symlink
New-Item -ItemType SymbolicLink -Path $androidSdk -Target "D:\Android"
```

**Option B: Move only SDK components (safer)**
- Open Android Studio → Settings → Appearance & Behavior → System Settings → Android SDK
- Change "Android SDK Location" to `D:\Android\Sdk`
- Click "Apply" - it will move files automatically

### 4. **Windows Temp Files** (Can free 1-5 GB)
```powershell
# Clean Windows temp
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Disk Cleanup
cleanmgr /d C:
```

### 5. **User Folders** (Can free 10-50 GB depending on usage)
**Move Downloads, Documents, Pictures, Videos to D:**
1. Right-click folder (e.g., Downloads)
2. Properties → Location tab
3. Change path to `D:\Users\simon\Downloads`
4. Click "Move" - Windows will move all files

**⚠️ Keep on C: Drive:**
- `AppData` folders (required by apps)
- `Documents\familyhub-MVP` (your project - keep for performance)
- Desktop (small, keep for convenience)

### 6. **Node.js Cache** (If you use Node.js)
```powershell
npm config set cache "D:\npm-cache" --global
```

## Recommended Order

1. **Start with caches** (Flutter, Gradle) - Low risk, quick wins
2. **Clean temp files** - Instant space
3. **Move Android SDK** - Biggest space saver
4. **Move user folders** - Only if still needed

## After Moving

1. **Restart your computer** to ensure all changes take effect
2. **Test a build:**
   ```powershell
   flutter clean
   flutter build apk --release --flavor dev
   ```
3. **Verify space:**
   ```powershell
   Get-PSDrive C | Select-Object Used,Free
   ```

## Quick Win Commands (Run as Administrator)

```powershell
# 1. Clean temp files
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# 2. Run Windows Disk Cleanup
cleanmgr /d C:

# 3. Check what's using space
Get-ChildItem C:\Users\simon\AppData\Local -Directory | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue | 
             Measure-Object -Property Length -Sum).Sum / 1GB
    if ($size -gt 0.5) {
        [PSCustomObject]@{ Folder = $_.Name; 'Size (GB)' = [math]::Round($size, 2) }
    }
} | Sort-Object 'Size (GB)' -Descending
```

