# Windows Settings That Enable Auto-Approval for Agents

## The Setting You Changed (But Can't Find)

You mentioned changing a PC setting on the working PC to enable auto-approval. Here are the most likely locations:

## 1. Windows Security / Windows Defender

### SmartScreen Settings
**Location**: Settings → Privacy & Security → Windows Security → App & browser control

**Check**:
- "Check apps and files" - Should be set to **Warn** or **Off** (not Block)
- "SmartScreen for Microsoft Edge" - Check setting
- "SmartScreen for Microsoft Store apps" - Check setting

**On SIMPC1**: Compare these settings with working PC

### Windows Defender Exclusions
**Location**: Windows Security → Virus & threat protection → Manage settings → Exclusions

**Check if Cursor is excluded**:
- Add folder: `C:\Program Files\cursor\`
- Add process: `Cursor.exe`

## 2. User Account Control (UAC)

**Location**: 
- Settings → Privacy & Security → Windows Security → Account Protection
- OR: Control Panel → User Accounts → Change User Account Control settings
- OR: Run `msconfig` → Tools tab → Change UAC settings

**Check UAC Level**:
- Working PC: Check current level (should be lower/less restrictive)
- SIMPC1: Compare - if higher, it may block auto-approval

**To check via command**:
```powershell
(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA").EnableLUA
(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin").ConsentPromptBehaviorAdmin
```

## 3. Windows Developer Mode

**Location**: Settings → Privacy & Security → For developers

**Check**: 
- "Developer Mode" toggle - Should be **ON** on working PC
- This enables sideloading and may affect app execution policies

**On SIMPC1**: Check if Developer Mode is OFF

## 4. Windows Terminal / Console Settings

**Location**: Settings → Privacy & Security → Windows Security → App & browser control → Reputation-based protection

**Check**:
- "Potentially unwanted app blocking" - May need to be OFF or configured
- Terminal/console execution permissions

## 5. Windows Privacy Settings

**Location**: Settings → Privacy & Security

**Check**:
- "Let apps run in the background" - Should be ON
- "Background apps" - Cursor should be allowed
- "App permissions" - Check Cursor permissions

## 6. Windows App Execution Aliases

**Location**: Settings → Apps → Advanced app settings → App execution aliases

**Check**: 
- PowerShell execution aliases
- Command prompt aliases
- May affect how Cursor executes commands

## 7. Windows Group Policy (If Available)

**Location**: Run `gpedit.msc` (if Pro/Enterprise)

**Check**:
- Computer Configuration → Administrative Templates → Windows Components → Windows Defender
- User Configuration → Administrative Templates → System → Scripts
- Look for execution policies or restrictions

## 8. Windows Firewall Rules

**Location**: Windows Security → Firewall & network protection → Advanced settings

**Check**:
- Outbound rules for Cursor
- PowerShell execution rules
- May affect command execution

## 9. Windows Execution Policy (PowerShell)

**Location**: PowerShell (run as admin)

**Check**:
```powershell
Get-ExecutionPolicy -List
```

**Working PC**: `CurrentUser: RemoteSigned`
**SIMPC1**: Compare - if stricter, may block execution

## 10. Windows App Installer Settings

**Location**: Settings → Apps → Advanced app settings

**Check**:
- "Choose where to get apps" - Should allow apps from anywhere or Microsoft Store + other sources
- May affect how Cursor is allowed to execute

## Most Likely Candidates

Based on "PC setting" that enables auto-approval:

1. **Windows Defender SmartScreen** - Most likely
2. **Developer Mode** - Very likely
3. **UAC Level** - Likely
4. **Windows Defender Exclusions** - Possible

## Quick Check Commands for SIMPC1

Run these on SIMPC1 and compare with working PC:

```powershell
# 1. Check UAC level
(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System").ConsentPromptBehaviorAdmin

# 2. Check Developer Mode
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue

# 3. Check SmartScreen
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableSmartScreen" -ErrorAction SilentlyContinue

# 4. Check PowerShell execution policy
Get-ExecutionPolicy -List

# 5. Check if Cursor is in Windows Defender exclusions (if accessible)
Get-MpPreference | Select-Object -ExpandProperty ExclusionPath -ErrorAction SilentlyContinue
```

## How to Find It on Working PC

1. **Open Settings** (Win + I)
2. Go to **Privacy & Security → Windows Security**
3. Check **App & browser control** section
4. Look for SmartScreen settings
5. Also check **For developers** section for Developer Mode

The setting you changed is likely in one of these locations!

