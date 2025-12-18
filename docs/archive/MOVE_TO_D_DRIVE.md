# Move Files from C: to D: Drive - Safe Migration Guide

## Current Situation
- **C: Drive:** 83.6 MB free (CRITICAL - needs immediate action)
- **D: Drive:** Available for storage

## Safe Items to Move

### 1. Development Caches (SAFE - Can be regenerated)

#### A. Gradle Cache (~2-5 GB typically)
**Location:** `C:\Users\simon\.gradle`

**Move Command:**
```powershell
# Create destination directory
New-Item -ItemType Directory -Path "D:\Development\.gradle" -Force

# Move the cache
Move-Item "$env:USERPROFILE\.gradle" "D:\Development\.gradle" -Force

# Create symbolic link so Gradle still finds it
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.gradle" -Target "D:\Development\.gradle"
```

**Expected Space Freed:** 2-5 GB

---

#### B. Flutter Pub Cache (~1-3 GB typically)
**Location:** `C:\Users\simon\AppData\Local\Pub\Cache`

**Move Command:**
```powershell
# Create destination directory
New-Item -ItemType Directory -Path "D:\Development\Pub" -Force

# Move the cache
Move-Item "$env:LOCALAPPDATA\Pub\Cache" "D:\Development\Pub\Cache" -Force

# Create symbolic link
New-Item -ItemType SymbolicLink -Path "$env:LOCALAPPDATA\Pub\Cache" -Target "D:\Development\Pub\Cache"
```

**Expected Space Freed:** 1-3 GB

---

#### C. Android SDK (~10-20 GB typically)
**Location:** `C:\Users\simon\AppData\Local\Android\Sdk`

**Move Command:**
```powershell
# Create destination directory
New-Item -ItemType Directory -Path "D:\Development\Android\Sdk" -Force

# Move the SDK
Move-Item "$env:LOCALAPPDATA\Android\Sdk" "D:\Development\Android\Sdk" -Force

# Create symbolic link
New-Item -ItemType SymbolicLink -Path "$env:LOCALAPPDATA\Android\Sdk" -Target "D:\Development\Android\Sdk"

# Update ANDROID_HOME environment variable (if set)
# Go to: System Properties > Environment Variables
# Change ANDROID_HOME from C:\Users\simon\AppData\Local\Android\Sdk to D:\Development\Android\Sdk
```

**Expected Space Freed:** 10-20 GB (BIGGEST WIN!)

---

### 2. Temporary Files (SAFE - Can be deleted)

#### A. Windows Temp Files
**Location:** `C:\Users\simon\AppData\Local\Temp` and `C:\Windows\Temp`

**Clean Command:**
```powershell
# Clean user temp files
Remove-Item "$env:LOCALAPPDATA\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clean system temp (requires admin)
Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
```

**Expected Space Freed:** 500 MB - 2 GB

---

#### B. Browser Caches
**Location:** `C:\Users\simon\AppData\Local\Microsoft\Windows\INetCache`

**Clean Command:**
```powershell
Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue
```

**Expected Space Freed:** 100-500 MB

---

### 3. User Files (SAFE - But verify first)

#### A. Downloads Folder
**Location:** `C:\Users\simon\Downloads`

**Move Command:**
```powershell
# Create destination
New-Item -ItemType Directory -Path "D:\Downloads" -Force

# Move files
Move-Item "C:\Users\simon\Downloads\*" "D:\Downloads\" -Force

# Update Windows default location (optional)
# Settings > System > Storage > Change where new content is saved > Downloads
```

**Expected Space Freed:** Varies (check size first)

---

#### B. Documents Folder (BE CAREFUL - Contains project!)
**Location:** `C:\Users\simon\Documents`

**⚠️ WARNING:** Your Flutter project is here! Only move if you're sure.

**Option 1: Move everything EXCEPT familyhub-MVP**
```powershell
# Create destination
New-Item -ItemType Directory -Path "D:\Documents" -Force

# Move everything except familyhub-MVP
Get-ChildItem "C:\Users\simon\Documents" -Exclude "familyhub-MVP" | 
    Move-Item -Destination "D:\Documents\" -Force
```

**Option 2: Move entire Documents folder**
```powershell
# Move entire folder
Move-Item "C:\Users\simon\Documents" "D:\Documents" -Force

# Create symbolic link
New-Item -ItemType SymbolicLink -Path "C:\Users\simon\Documents" -Target "D:\Documents"
```

---

## Automated Script

I've created a script that will:
1. Check sizes of all movable items
2. Move them safely
3. Create symbolic links where needed

**Run this script:**
```powershell
# First, review what will be moved
.\free_up_space.ps1

# Then run the automated mover (I'll create this next)
.\move_to_d_drive.ps1
```

---

## Priority Order (Do these first for maximum impact)

1. **Android SDK** (10-20 GB) - Biggest space saver
2. **Gradle Cache** (2-5 GB)
3. **Flutter Pub Cache** (1-3 GB)
4. **Temp Files** (500 MB - 2 GB)
5. **Downloads** (varies)
6. **Documents** (only if safe)

---

## After Moving - Verification

1. **Test Flutter:**
   ```powershell
   flutter doctor
   flutter pub get
   ```

2. **Test Android:**
   ```powershell
   # Check if Android SDK is found
   $env:ANDROID_HOME
   ```

3. **Test Gradle:**
   ```powershell
   cd android
   .\gradlew --version
   ```

---

## Symbolic Links Explained

Symbolic links make Windows think files are still in the original location, but they're actually on D: drive. This means:
- ✅ Flutter/Android tools still work
- ✅ No configuration changes needed
- ✅ Files are actually on D: drive (saving C: space)

---

## Emergency: If Something Breaks

If moving breaks something, you can:
1. Delete the symbolic link
2. Move files back from D: to C:
3. Everything should work again

---

## Next Steps

1. Run the analysis script to see actual sizes
2. Start with Android SDK (biggest impact)
3. Then move caches
4. Clean temp files
5. Verify everything still works
