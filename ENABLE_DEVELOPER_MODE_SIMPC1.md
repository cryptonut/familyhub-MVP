# Enable Developer Mode on SIMPC1 - Fix Auto-Approval Issue

## The Problem
- **Working PC**: Auto-approval works ✅
- **SIMPC1**: Manual approval required for every command ❌

## The Solution: Enable Developer Mode

**Working PC has Developer Mode ENABLED** - this is what allows auto-approval.

## Step-by-Step Instructions for SIMPC1

### Method 1: Via Windows Settings (Easiest)

1. **Open Windows Settings**
   - Press `Win + I`
   - OR: Click Start → Settings

2. **Navigate to Developer Settings**
   - Click **Privacy & Security** (left sidebar)
   - Scroll down and click **For developers**

3. **Enable Developer Mode**
   - Find the toggle for **"Developer Mode"**
   - Turn it **ON**
   - Windows may prompt you to confirm - click **Yes**

4. **Restart Cursor**
   - Close Cursor completely
   - Reopen Cursor
   - Test auto-approval

### Method 2: Via Registry (If Settings UI doesn't work)

1. **Open Registry Editor**
   - Press `Win + R`
   - Type `regedit` and press Enter
   - Click **Yes** if prompted by UAC

2. **Navigate to the Key**
   - Go to: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock`

3. **Create/Modify the Value**
   - If `AllowDevelopmentWithoutDevLicense` doesn't exist, create it:
     - Right-click in the right pane → New → DWORD (32-bit) Value
     - Name it: `AllowDevelopmentWithoutDevLicense`
   - Double-click the value
   - Set **Value data** to: `1`
   - Click **OK**

4. **Restart Computer** (or at least restart Cursor)

### Method 3: Via PowerShell (Quick Command)

Run PowerShell **as Administrator** on SIMPC1:

```powershell
# Enable Developer Mode
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord

# Verify it's enabled
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense"
# Should return: AllowDevelopmentWithoutDevLicense : 1
```

Then **restart Cursor**.

## Verify Developer Mode is Enabled

Run this command on SIMPC1 to verify:

```powershell
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
```

**Expected Result**: `AllowDevelopmentWithoutDevLicense : 1`

**If it returns nothing or `0`**: Developer Mode is still OFF.

## After Enabling Developer Mode

1. **Restart Cursor** (completely close and reopen)
2. **Test auto-approval** - try a simple command in Cursor agent
3. **Test Git push** - should work without manual approval

## Why This Works

Developer Mode:
- Allows apps to execute with fewer restrictions
- Enables sideloading and development features
- Reduces Windows security prompts for development tools
- This is what enables Cursor agents to auto-approve commands

## Working PC Configuration (For Reference)

- **Developer Mode**: ✅ ENABLED (`AllowDevelopmentWithoutDevLicense = 1`)
- **UAC**: Enabled (ConsentPromptBehaviorAdmin = 5)
- **PowerShell Execution Policy**: CurrentUser = RemoteSigned
- **User**: Member of Administrators group

## Troubleshooting

**If Developer Mode toggle is grayed out:**
- You may need administrator rights
- Try running Settings as administrator
- Or use the PowerShell/Registry method

**If it still doesn't work after enabling:**
- Make sure you restarted Cursor (not just reloaded window)
- Check that the registry value is actually set to `1`
- Verify you're not running Cursor as administrator (should run as normal user)

**If you can't find "For developers" in Settings:**
- Your Windows version might not have this option
- Use the Registry or PowerShell method instead

