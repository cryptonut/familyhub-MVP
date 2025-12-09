# SIMPC1 Login Recovery - "We can't sign in to your account"

## Root Cause
- **Default and Public folders were deleted** from `C:\Users\`
- These are **critical Windows system folders** (not user profiles)
- Windows **cannot log in users** without the `Default` folder
- The `simon` user profile likely exists and is fine, but Windows can't initialize login

## Current Situation
- System Restore completed but login still fails
- Windows shows "We can't sign in to your account" error
- `dir C:\Users` shows only `simon` folder (missing `Default` and `Public`)

## Recovery Options (In Order of Preference)

### Option 1: Recreate Default and Public Folders (Fix Root Cause)

**From Recovery Command Prompt:**

1. **Boot to Recovery Command Prompt**
   - Force shutdown → Boot → Force shutdown (repeat until recovery)
   - Choose "Troubleshoot" → "Advanced options" → "Command Prompt"

2. **Recreate Default Folder:**
```cmd
REM Create Default folder structure
mkdir "C:\Users\Default"
mkdir "C:\Users\Default\AppData"
mkdir "C:\Users\Default\AppData\Local"
mkdir "C:\Users\Default\AppData\Roaming"
mkdir "C:\Users\Default\Documents"
mkdir "C:\Users\Default\Desktop"
mkdir "C:\Users\Default\Downloads"
mkdir "C:\Users\Default\Pictures"
mkdir "C:\Users\Default\Videos"
mkdir "C:\Users\Default\Music"

REM Set permissions
icacls "C:\Users\Default" /grant "NT AUTHORITY\SYSTEM:(OI)(CI)F" /T
icacls "C:\Users\Default" /grant "BUILTIN\Administrators:(OI)(CI)F" /T
icacls "C:\Users\Default" /grant "BUILTIN\Users:(OI)(CI)RX" /T
```

3. **Recreate Public Folder:**
```cmd
REM Create Public folder structure
mkdir "C:\Users\Public"
mkdir "C:\Users\Public\Documents"
mkdir "C:\Users\Public\Desktop"
mkdir "C:\Users\Public\Downloads"
mkdir "C:\Users\Public\Pictures"
mkdir "C:\Users\Public\Videos"
mkdir "C:\Users\Public\Music"

REM Set permissions
icacls "C:\Users\Public" /grant "NT AUTHORITY\SYSTEM:(OI)(CI)F" /T
icacls "C:\Users\Public" /grant "BUILTIN\Administrators:(OI)(CI)F" /T
icacls "C:\Users\Public" /grant "BUILTIN\Users:(OI)(CI)RX" /T
```

4. **Restart and Try Login**
   - Restart the PC
   - Try logging in as `simon`
   - Windows should now be able to initialize the login session

### Option 2: Create New Admin User (If Option 1 Doesn't Work)

**From Recovery Command Prompt:**

1. **Boot to Recovery** (if not already there)
   - Force shutdown (hold power 10+ seconds)
   - Boot and force shutdown 2-3 times until "Preparing Automatic Repair"
   - Choose "Troubleshoot" → "Advanced options" → "Command Prompt"

2. **Create New Admin User:**
```cmd
net user TempAdmin YourPassword123 /add
net localgroup administrators TempAdmin /add
```

3. **Restart and Log In**
   - Restart the PC
   - Log in as `TempAdmin` with password `YourPassword123`
   - You'll have full admin access

4. **Fix Original User Profile:**
   - Once logged in as TempAdmin, open Command Prompt as Admin
   - Reset permissions on original user folder:
```cmd
icacls "C:\Users\simon" /reset /T
```

5. **Try Logging in as Original User**
   - Sign out of TempAdmin
   - Try logging in as `simon` again

### Option 2: Reset User Profile Permissions from Recovery

**From Recovery Command Prompt:**

```cmd
REM Reset permissions on user folder
icacls "C:\Users\simon" /grant "BUILTIN\Users:(OI)(CI)F" /T
icacls "C:\Users\simon" /grant "NT AUTHORITY\SYSTEM:(OI)(CI)F" /T
icacls "C:\Users\simon" /grant "BUILTIN\Administrators:(OI)(CI)F" /T
icacls "C:\Users\simon" /grant "simon:(OI)(CI)F" /T

REM Reset ownership
takeown /F "C:\Users\simon" /R /D Y
icacls "C:\Users\simon" /reset /T
```

Then restart and try logging in.

### Option 3: Rename User Profile (Last Resort Before Reset)

**From Recovery Command Prompt:**

```cmd
REM Rename corrupted profile
move "C:\Users\simon" "C:\Users\simon.old"

REM Create new profile (Windows will do this on next login)
mkdir "C:\Users\simon"
icacls "C:\Users\simon" /grant "simon:(OI)(CI)F" /T
```

**Warning**: This creates a fresh profile. You'll need to copy files from `simon.old` manually after logging in.

### Option 4: Windows Reset (Keep Files)

**If nothing else works:**

1. **Boot to Recovery**
   - Force shutdown → Boot → Force shutdown (repeat until recovery)
   - Choose "Troubleshoot" → "Reset this PC"

2. **Choose "Keep my files"**
   - This reinstalls Windows but keeps your files
   - Your files will be in `C:\Users\simon.old` after reset
   - You'll need to set up Windows again

3. **After Reset:**
   - Copy files from `C:\Users\simon.old` to new profile
   - Reinstall applications

## Recommended Approach

**Try in this order:**

1. ✅ **Option 1: Recreate Default and Public folders** (Fixes root cause - 10 minutes)
2. ✅ **Option 2: Create TempAdmin user** (If Option 1 doesn't work - 5 minutes)
3. ⚠️ **Option 3: Reset permissions on simon folder** (If TempAdmin works)
4. ⚠️ **Option 4: Rename profile** (If permissions don't work)
5. 🔴 **Option 5: Windows Reset** (Last resort)

## Why System Restore Didn't Work

System Restore restores:
- System files
- Registry
- Installed programs

**It does NOT restore:**
- Deleted folders (if Default/Public were deleted before the restore point)
- User profile permissions (if they were broken before restore point)

If `Default` and `Public` folders were deleted before the restore point was created, System Restore won't bring them back. You need to recreate them manually.

## Quick Test from Recovery

**Before trying anything, check if profile exists:**

```cmd
dir C:\Users
```

If `simon` folder exists, try Option 1 (TempAdmin) first.
If `simon` folder is missing, you'll need Option 4 (Reset).

## After Recovery

Once you can log in:
1. **Backup important files immediately**
2. **Don't change permissions on system folders again**
3. **Only modify application-specific folders if needed**

## Emergency: If Nothing Works

If all options fail:
- **Windows Recovery Drive** (if you have one)
- **Professional IT support**
- **Reinstall Windows** (complete reset, lose everything)

But Option 1 (TempAdmin) should work - it's the most reliable method.

