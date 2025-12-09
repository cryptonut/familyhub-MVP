# CURSOR FOLDER PERMISSIONS - THE ACTUAL SOLUTION

## 🎯 THIS IS LIKELY THE ROOT CAUSE

On the **working PC**, Cursor was given **Full Control** permissions on the `.cursor` folder with **"pass down permissions"** enabled. This is likely what enables auto-approval!

## Step-by-Step Instructions for SIMPC1

### Method 1: Via File Explorer (Easiest)

1. **Navigate to the Cursor folder**
   - Open File Explorer
   - Go to: `C:\Users\[YOUR_USERNAME]\.cursor`
   - Replace `[YOUR_USERNAME]` with your actual Windows username

2. **Open Properties**
   - Right-click on the `.cursor` folder
   - Select **Properties**

3. **Go to Security Tab**
   - Click the **Security** tab
   - Click **Edit** button

4. **Add Cursor/Your User Account**
   - Click **Add** button
   - Type your username (or the account running Cursor)
   - Click **Check Names** to verify
   - Click **OK**

5. **Set Full Control Permissions**
   - Select your user account in the list
   - In the **Permissions** section below, check **Full Control**
   - ⚠️ **IMPORTANT**: Check the box **"Replace all child object permission entries with inheritable permission entries from this object"**
   - This is the "pass down permissions" option!

6. **Apply Changes**
   - Click **Apply**
   - Click **OK**
   - If prompted, click **Yes** to confirm

7. **Restart Cursor**
   - Close Cursor completely
   - Reopen Cursor
   - Test auto-approval

### Method 2: Via PowerShell (Quick Command)

Run PowerShell **as Administrator** on SIMPC1:

```powershell
# Replace [YOUR_USERNAME] with your actual Windows username
$username = "[YOUR_USERNAME]"
$cursorPath = "C:\Users\$username\.cursor"

# Grant Full Control to the user
icacls $cursorPath /grant "${username}:(OI)(CI)F" /T

# Verify permissions
icacls $cursorPath
```

**What this does:**
- `(OI)` = Object Inherit (pass permissions to files)
- `(CI)` = Container Inherit (pass permissions to subfolders)
- `F` = Full Control
- `/T` = Apply to all subfolders and files

### Method 3: Via Command Prompt (Alternative)

Run Command Prompt **as Administrator**:

```cmd
REM Replace [YOUR_USERNAME] with your actual Windows username
icacls "C:\Users\[YOUR_USERNAME]\.cursor" /grant "[YOUR_USERNAME]:(OI)(CI)F" /T
```

## Verify Permissions Are Set

After setting permissions, verify with:

```powershell
icacls "C:\Users\[YOUR_USERNAME]\.cursor" | Select-String "[YOUR_USERNAME]"
```

You should see your username with `(OI)(CI)F` permissions.

## Why This Works

When Cursor needs to:
- Write configuration files
- Create temporary files
- Execute commands
- Modify settings

It needs **Full Control** permissions on its own folder structure. Without these permissions, Windows blocks operations and requires manual approval.

## Complete Setup Checklist for SIMPC1

Do ALL of these:

1. ✅ **Set Cursor Folder Permissions** (THIS FILE - Most Important!)
   - Give Full Control to your user account
   - Enable "pass down permissions" / inheritance

2. ✅ **Enable Developer Mode**
   ```powershell
   Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord
   ```

3. ✅ **Set PowerShell Execution Policy**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

4. ✅ **Restart Cursor** (completely close and reopen)

5. ✅ **Test auto-approval**

## Troubleshooting

**If you can't find the `.cursor` folder:**
- It might be hidden - enable "Show hidden files" in File Explorer
- Or it might be in `C:\Users\[USERNAME]\AppData\Roaming\Cursor` instead
- Check both locations

**If permissions dialog is grayed out:**
- You need administrator rights
- Right-click File Explorer → "Run as administrator"
- Or use the PowerShell/Command Prompt method

**If it still doesn't work:**
- Make sure you restarted Cursor (not just reloaded window)
- Verify permissions with `icacls` command
- Check that you're using the correct username

## Working PC Configuration (For Reference)

- **Cursor Folder**: `C:\Users\simon\.cursor`
- **Permissions**: Full Control with inheritance enabled
- **Developer Mode**: Enabled
- **PowerShell Execution Policy**: CurrentUser = RemoteSigned
- **User**: Member of Administrators group

