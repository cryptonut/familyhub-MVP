# Enable Developer Mode on SIMPC1 - Fix Auto-Approval Issue

## The Problem
- **Working PC**: Auto-approval works ✅
- **SIMPC1**: Manual approval required for every command ❌

## The Solution: Enable Developer Mode

**Working PC has Developer Mode ENABLED** - this is what allows auto-approval.

## Step-by-Step Instructions for SIMPC1

### ⚠️ PRIMARY METHOD: Via PowerShell (Use This - Settings UI Not Available)

**Run PowerShell as Administrator** on SIMPC1:

1. **Open PowerShell as Admin**
   - Press `Win + X`
   - Click **"Windows PowerShell (Admin)"** or **"Terminal (Admin)"**
   - Click **Yes** if prompted by UAC

2. **Run This Command**:
   ```powershell
   Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord
   ```

3. **Verify It Worked**:
   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense"
   ```
   Should return: `AllowDevelopmentWithoutDevLicense : 1`

4. **Restart Cursor** (completely close and reopen)

### Method 2: Via Registry (Alternative if PowerShell doesn't work)

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

4. **Restart Cursor** (completely close and reopen)

### Method 3: Via Windows Settings (May Not Be Available)

**Note**: This option may not be available on all Windows versions (like SIMPC1).

If you can find it:
1. **Open Windows Settings** (`Win + I`)
2. Go to **Privacy & Security → For developers**
3. Toggle **Developer Mode** to **ON**
4. Restart Cursor

**If you don't see "For developers" section**: Use Method 1 (PowerShell) instead.

## ⚠️ ALSO CHECK: PowerShell Execution Policy

**This is also critical!** The working PC has `CurrentUser: RemoteSigned` which allows scripts to run.

### Check Current Policy on SIMPC1

Run this command:
```powershell
Get-ExecutionPolicy -List
```

### Compare with Working PC

**Working PC values:**
- `MachinePolicy`: Undefined
- `UserPolicy`: Undefined
- `Process`: Undefined
- `CurrentUser`: **RemoteSigned** ⚠️ (This is important!)
- `LocalMachine`: Undefined

### If SIMPC1 Has Stricter Policy, Fix It

If `CurrentUser` is `Restricted` or `Undefined`, set it to `RemoteSigned`:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**This allows:**
- Scripts you write locally to run
- Downloaded scripts signed by trusted publishers to run
- Prevents unsigned remote scripts (security)

**This is safe and matches the working PC configuration.**

## Verify Developer Mode is Enabled

Run this command on SIMPC1 to verify:

```powershell
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
```

**Expected Result**: `AllowDevelopmentWithoutDevLicense : 1`

**If it returns nothing or `0`**: Developer Mode is still OFF.

## Complete Setup Checklist for SIMPC1

Do BOTH of these:

1. **Enable Developer Mode** (Method 1 - PowerShell)
   ```powershell
   Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1 -Type DWord
   ```

2. **Set PowerShell Execution Policy** (if needed)
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Verify Both Settings**:
   ```powershell
   # Check Developer Mode
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense"
   # Should return: AllowDevelopmentWithoutDevLicense : 1
   
   # Check Execution Policy
   Get-ExecutionPolicy -List
   # CurrentUser should be: RemoteSigned
   ```

4. **Restart Cursor** (completely close and reopen)

5. **Test auto-approval** - try a simple command in Cursor agent

6. **Test Git push** - should work without manual approval

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

