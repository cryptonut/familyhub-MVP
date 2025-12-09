# SIMPC1 Cursor Auto-Approve Checklist

## The Problem
- **Working PC**: Commands auto-approve, Git auth works
- **SIMPC1**: Manual approval needed for EVERY command, Git auth fails

## Quick Checks on SIMPC1

### 1. Check Cursor Settings Location
Open PowerShell on SIMPC1 and run:
```powershell
# Check if settings file exists
Test-Path "$env:APPDATA\Cursor\User\settings.json"
# If false, try:
Test-Path "$env:USERPROFILE\.cursor\User\settings.json"
# List all Cursor directories
Get-ChildItem "$env:USERPROFILE" -Filter "*cursor*" -Directory
```

### 2. Open Cursor Settings
In Cursor on SIMPC1:
- Press `Ctrl+,` (or File → Preferences → Settings)
- Search for: `auto approve`
- Search for: `agent`
- Search for: `terminal`

Look for these settings and enable them:
- `cursor.general.autoApproveAgentCommands` → Set to `true`
- `cursor.terminal.autoApproveCommands` → Set to `true`
- `git.terminalAuthentication` → Set to `true`

### 3. Check Cursor Version
In Cursor: Help → About
Compare version with working PC

### 4. Check Windows UAC Level
On SIMPC1:
- Press `Win + R`, type `msconfig`, press Enter
- Go to "Tools" tab
- Select "Change UAC settings" → Launch
- Check the level (should match working PC)

### 5. Check if Running as Admin
In PowerShell on SIMPC1:
```powershell
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```
Both PCs should have the same result.

## Most Likely Fix

**Option 1: Enable Auto-Approve in Cursor Settings**
1. Open Cursor on SIMPC1
2. `Ctrl+,` to open Settings
3. Search: `auto approve`
4. Enable: `cursor.general.autoApproveAgentCommands`
5. Restart Cursor

**Option 2: Use SSH Keys (Bypasses the Issue)**
If you can't change settings, switch to SSH keys - they don't need interactive prompts:

```powershell
# On SIMPC1:
ssh-keygen -t ed25519 -C "your.email@example.com"
# Press Enter 3 times (or set passphrase)
cat ~/.ssh/id_ed25519.pub | clip
# Go to: https://github.com/settings/keys
# Click "New SSH key", paste, save
# Then:
git remote set-url origin git@github.com:cryptonut/familyhub-MVP.git
git push origin develop
```

SSH keys work even when interactive prompts are blocked.

## Why This Matters

If Cursor requires manual approval for commands, it's likely also blocking:
- Git credential prompts
- Firebase CLI authentication prompts
- Any interactive terminal input

This explains why Git auth fails on SIMPC1 but works on the working PC.

