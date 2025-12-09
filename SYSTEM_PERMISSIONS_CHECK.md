# System-Level Permissions Comparison - Working PC vs SIMPC1

## Key Findings on Working PC

### 1. User Account Type
- **Working PC**: User `simon` is a member of `Administrators` group
- **Check on SIMPC1**: Run `whoami /groups` and verify admin membership

### 2. PowerShell Execution Policy
- **Working PC**: `CurrentUser: RemoteSigned`
- **Check on SIMPC1**: Run `Get-ExecutionPolicy -List`
- **Impact**: If SIMPC1 has `Restricted` or stricter policy, it may block script execution

### 3. Windows User Account Control (UAC)
- **Check on both**: Run `(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA").EnableLUA`
- **Working PC**: Check current level
- **Impact**: Different UAC levels can affect how applications request permissions

### 4. Windows Defender Exclusions
- **Check on SIMPC1**: Open Windows Security → Virus & threat protection → Manage settings → Exclusions
- **Working PC**: Check if Cursor or PowerShell are excluded
- **Impact**: Antivirus can block interactive prompts and command execution

### 5. Group Policy Restrictions
- **Check on SIMPC1**: Run `gpresult /h gp-report.html` and check for:
  - Software restriction policies
  - AppLocker policies
  - Script execution restrictions
  - Terminal/console restrictions

### 6. Terminal/Console Permissions
Check if there are differences in:
- Terminal app permissions (Windows Terminal vs PowerShell)
- Console host permissions
- Command execution policies

### 7. Cursor Installation Location
- **Working PC**: `C:\Program Files\cursor\`
- **Check on SIMPC1**: Verify installation path and permissions
- **Impact**: Different installation locations or permissions can affect behavior

## Commands to Run on SIMPC1

### Quick Check Script
```powershell
# 1. Check admin status
whoami /groups | Select-String "Administrators"

# 2. Check PowerShell execution policy
Get-ExecutionPolicy -List

# 3. Check UAC level
(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA").EnableLUA

# 4. Check if running as elevated
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 5. Check Windows Defender status (if accessible)
Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled, AntivirusEnabled

# 6. Check Cursor installation
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {$_.DisplayName -match "Cursor"} | Select-Object DisplayName, InstallLocation

# 7. Check for Group Policy restrictions
gpresult /Scope User /v | Select-String -Pattern "cursor|terminal|script|execution" -Context 2
```

## Most Likely Differences

1. **PowerShell Execution Policy**: SIMPC1 might have stricter policy
2. **UAC Level**: Different UAC settings can affect how Cursor requests permissions
3. **Windows Defender**: May be blocking interactive prompts on SIMPC1
4. **Admin Rights**: Cursor might not be running with same privileges
5. **Group Policy**: Corporate/domain policies might restrict agent actions

## Quick Fixes to Try on SIMPC1

### Fix 1: PowerShell Execution Policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Fix 2: Run Cursor as Administrator
- Right-click Cursor shortcut → "Run as administrator"
- Or: Properties → Compatibility → Check "Run this program as an administrator"

### Fix 3: Add Cursor to Windows Defender Exclusions
1. Windows Security → Virus & threat protection
2. Manage settings → Add or remove exclusions
3. Add folder: `C:\Program Files\cursor\`
4. Add process: `Cursor.exe`

### Fix 4: Check UAC Settings
- If UAC is too high, lower it temporarily to test
- Settings → Privacy & Security → Windows Security → Account Protection

## Notes

- The user account being in Administrators group on working PC is significant
- If SIMPC1 user is NOT an admin, Cursor may not have permissions to auto-approve
- Check if Cursor is installed in different location or with different permissions

