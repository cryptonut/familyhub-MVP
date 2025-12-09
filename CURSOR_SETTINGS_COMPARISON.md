# Cursor Settings Comparison - Working PC vs SIMPC1

## The Issue
- **Working PC (this one)**: Commands auto-approve, Git authentication works
- **SIMPC1**: Every command requires manual approval, Git authentication fails

This suggests a Cursor configuration difference that may be blocking:
1. Auto-approval of agent commands
2. Interactive credential prompts (Git, Firebase)
3. Background processes

## Settings to Compare

### 1. Cursor User Settings

Check on both machines:
- `C:\Users\[USERNAME]\.cursor\User\settings.json`
- Or: Cursor → Settings (Ctrl+,) → Search for "agent" or "auto"

Key settings to check:
```json
{
  "cursor.general.autoApproveAgentCommands": true,
  "cursor.terminal.autoApproveCommands": true,
  "cursor.security.allowUnrestrictedCommands": true,
  "git.terminalAuthentication": true,
  "terminal.integrated.allowWorkspaceConfiguration": true
}
```

### 2. Cursor Workspace Settings

Check in project root:
- `.vscode/settings.json` (workspace-specific)

### 3. Cursor Extension Settings

Location: `C:\Users\[USERNAME]\.cursor\extensions\`

Check for differences in:
- Installed extensions
- Extension configurations
- Version differences

### 4. Windows Security/Permission Differences

Check on SIMPC1:
- Windows User Account Control (UAC) level
- Group Policy restrictions
- Antivirus/security software blocking interactive prompts
- Windows Defender SmartScreen settings

### 5. Environment Variables

Compare these environment variables on both machines:
```powershell
Get-ChildItem Env: | Where-Object {$_.Name -match 'cursor|git|auth|credential'} | Format-Table
```

### 6. Git Configuration

Check Git credential helper differences:
```powershell
# On both machines:
git config --list | Select-String credential
git config --global credential.helper
git config --system credential.helper
```

### 7. Cursor Process Permissions

Check if Cursor is running with different privileges:
```powershell
# On both machines:
Get-Process cursor | Format-List *
```

## Quick Diagnostic Commands for SIMPC1

Run these on SIMPC1 and compare with working PC:

```powershell
# 1. Cursor settings location
Get-ChildItem "$env:USERPROFILE\.cursor" -Recurse -Filter "settings.json" | Select-Object FullName

# 2. Check for agent/auto-approval settings
Select-String -Path "$env:USERPROFILE\.cursor\User\settings.json" -Pattern "auto|agent|approve" -ErrorAction SilentlyContinue

# 3. Git credential helper
git config --global credential.helper
git config --system credential.helper
git config --list | Select-String credential

# 4. Windows UAC level
(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue).EnableLUA

# 5. Cursor version
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {$_.DisplayName -match "Cursor"} | Select-Object DisplayName, DisplayVersion

# 6. Check if running as admin
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

## Most Likely Causes

1. **Cursor Settings**: `cursor.general.autoApproveAgentCommands` is `false` on SIMPC1
2. **UAC/Admin Rights**: Cursor running with different privileges
3. **Security Software**: Antivirus blocking interactive prompts
4. **Git Credential Manager**: Not properly configured to allow non-interactive access
5. **Cursor Version**: Different versions with different default behaviors

## Solution Steps

1. **On SIMPC1**, open Cursor Settings (Ctrl+,)
2. Search for "auto approve" or "agent"
3. Enable auto-approval for agent commands
4. Search for "terminal authentication" 
5. Enable terminal authentication
6. Restart Cursor
7. Test Git push again

## Alternative: Use SSH Keys

If settings can't be changed, switch to SSH keys (which don't require interactive prompts):

```powershell
# On SIMPC1:
ssh-keygen -t ed25519 -C "your.email@example.com"
cat ~/.ssh/id_ed25519.pub | clip
# Add to GitHub, then:
git remote set-url origin git@github.com:cryptonut/familyhub-MVP.git
```

SSH keys bypass credential managers entirely and work even with restricted interactive prompts.

