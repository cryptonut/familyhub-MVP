# SIMPC1 Recovery Guide - Can't Sign In / Won't Restart

## Immediate Recovery Steps

### Option 1: Safe Mode Recovery

1. **Force Shutdown**
   - Hold power button for 10+ seconds to force shutdown

2. **Boot to Safe Mode**
   - Turn on PC
   - When Windows logo appears, hold power button again to force shutdown
   - Repeat 2-3 times until you see "Preparing Automatic Repair"
   - OR: Boot and immediately press F8 repeatedly (before Windows logo)
   - OR: Boot and press Shift while clicking Restart (if you can get to login screen)

3. **Access Safe Mode**
   - Choose "Troubleshoot" → "Advanced options" → "Startup Settings" → "Restart"
   - Press F4 or 4 for Safe Mode
   - OR Press F5 or 5 for Safe Mode with Networking

4. **In Safe Mode - Fix Permissions**
   - Open Command Prompt as Administrator
   - Run these commands to reset user folder permissions:

```cmd
icacls "C:\Users\[YOUR_USERNAME]" /reset /T
icacls "C:\Users\[YOUR_USERNAME]\.cursor" /reset /T
```

Replace `[YOUR_USERNAME]` with your actual username.

### Option 2: System Restore

1. **Boot to Recovery**
   - Same steps as Safe Mode above
   - Choose "Troubleshoot" → "Advanced options" → "System Restore"

2. **Restore to Before Permission Changes**
   - Select a restore point from before you changed permissions
   - Follow prompts to restore

### Option 3: Command Prompt Recovery (If You Can Access It)

1. **Boot to Command Prompt**
   - Boot to recovery (same as above)
   - Choose "Troubleshoot" → "Advanced options" → "Command Prompt"

2. **Reset Permissions**
```cmd
REM Replace [YOUR_USERNAME] with actual username
icacls "C:\Users\[YOUR_USERNAME]" /grant "BUILTIN\Users:(OI)(CI)F" /T
icacls "C:\Users\[YOUR_USERNAME]" /grant "NT AUTHORITY\SYSTEM:(OI)(CI)F" /T
icacls "C:\Users\[YOUR_USERNAME]" /grant "BUILTIN\Administrators:(OI)(CI)F" /T
icacls "C:\Users\[YOUR_USERNAME]" /grant "[YOUR_USERNAME]:(OI)(CI)F" /T
```

### Option 4: Create New Admin User (If Nothing Else Works)

1. **Boot to Command Prompt** (recovery mode)
2. **Create new admin account:**
```cmd
net user TempAdmin YourPassword123 /add
net localgroup administrators TempAdmin /add
```
3. **Restart and log in as TempAdmin**
4. **Fix original user permissions from there**

## What Likely Went Wrong

If you changed permissions on the parent user folder (`C:\Users\[USERNAME]\`) incorrectly, it can:
- Block Windows from accessing user profile
- Prevent login
- Cause system instability

## Prevention for Future

**NEVER change permissions on:**
- `C:\Users\[USERNAME]\` (parent folder) - only child folders
- System folders
- Windows folders

**ONLY change permissions on:**
- Specific application folders like `.cursor`
- Project folders
- Non-system locations

## After Recovery

Once you can log in again:
1. **Don't change parent folder permissions**
2. **Only modify `.cursor` folder permissions if needed**
3. **Use inheritance from parent (don't break inheritance)**

## Emergency Contact

If none of these work:
- Try Windows Recovery Drive (if you have one)
- Consider professional IT support
- May need to reinstall Windows (last resort)

## Important Notes

- **Don't panic** - this is usually recoverable
- **Safe Mode** is your friend - it loads minimal drivers/services
- **System Restore** can undo recent changes
- **Backup important data** once you can access the system

