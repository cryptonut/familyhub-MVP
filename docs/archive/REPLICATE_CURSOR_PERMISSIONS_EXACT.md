# Replicate Cursor Permissions - Exact Settings from Working PC

## What We See on Working PC

From the Advanced Security Settings dialog:
- **All permissions are INHERITED** from `C:\Users\simon\`
- **"Replace all child object permission entries" checkbox is UNCHECKED**
- All principals have **Full control** inherited from parent
- Permissions are inherited, NOT explicitly set on the folder

## Step-by-Step Instructions for SIMPC1

### Method 1: Via File Explorer (Recommended)

1. **Navigate to the Cursor folder**
   - Open File Explorer
   - Go to: `C:\Users\[YOUR_USERNAME]\.cursor`
   - Replace `[YOUR_USERNAME]` with your actual Windows username
   - **Note**: The `.cursor` folder is hidden - enable "Show hidden files" if needed

2. **Open Properties**
   - Right-click on the `.cursor` folder
   - Select **Properties**

3. **Go to Security Tab**
   - Click the **Security** tab
   - Click **Advanced** button

4. **Check Current Permissions**
   - In the "Advanced Security Settings" dialog, look at the "Permission entries" table
   - You should see entries for:
     - **SYSTEM** - Full control (inherited)
     - **Administrators** - Full control (inherited)
     - **Your User Account** - Full control (inherited)
   - All should show "Inherited from: `C:\Users\[YOUR_USERNAME]\`"

5. **If Permissions Are NOT Inherited (Most Likely Issue)**
   
   **Option A: Enable Inheritance (Recommended)**
   - Click **"Disable inheritance"** button
   - When prompted, choose **"Convert inherited permissions into explicit permissions"**
   - This will make the inherited permissions explicit
   - **Then re-enable inheritance:**
     - Click **"Enable inheritance"** button
     - This should restore inheritance from parent folder

   **Option B: Remove Explicit Permissions and Restore Inheritance**
   - If you see explicit (non-inherited) permissions:
     - Select each explicit entry
     - Click **Remove** (if enabled)
   - Click **"Enable inheritance"** button
   - Click **OK**

6. **Verify the Checkbox**
   - **IMPORTANT**: The checkbox **"Replace all child object permission entries with inheritable permission entries from this object"** should be **UNCHECKED**
   - This is the key - we want inheritance, NOT replacement

7. **Verify Parent Folder Permissions**
   - Go back to File Explorer
   - Navigate to: `C:\Users\[YOUR_USERNAME]\`
   - Right-click → Properties → Security tab
   - Verify your user account has **Full Control**
   - If not, add it:
     - Click **Edit**
     - Click **Add**
     - Type your username
     - Click **Check Names** → **OK**
     - Select your account → Check **Full Control** → **OK**

8. **Apply and Close**
   - Click **OK** on all dialogs
   - Restart Cursor

### Method 2: Via PowerShell (If File Explorer Doesn't Work)

Run PowerShell **as Administrator** on SIMPC1:

```powershell
# Replace [YOUR_USERNAME] with your actual Windows username
$username = "[YOUR_USERNAME]"
$cursorPath = "C:\Users\$username\.cursor"
$parentPath = "C:\Users\$username"

# First, ensure parent folder has Full Control for user
icacls $parentPath /grant "${username}:(OI)(CI)F"

# Remove any explicit permissions on .cursor folder
icacls $cursorPath /remove "${username}" 2>$null

# Enable inheritance (this should happen automatically if parent has permissions)
# Verify inheritance is working
icacls $cursorPath
```

**Expected output should show:**
- `(OI)(CI)F` = Object Inherit, Container Inherit, Full Control
- All entries should be inherited from parent

### Method 3: Reset to Inherit from Parent

If permissions are messed up, reset completely:

```powershell
# Replace [YOUR_USERNAME] with your actual Windows username
$username = "[YOUR_USERNAME]"
$cursorPath = "C:\Users\$username\.cursor"

# Remove all explicit permissions
icacls $cursorPath /reset

# This will restore inheritance from parent folder
```

## Key Points

1. **Permissions should be INHERITED**, not explicitly set on `.cursor` folder
2. **"Replace all child object..." checkbox should be UNCHECKED**
3. **Parent folder** (`C:\Users\[USERNAME]\`) must have Full Control for your user
4. **All three principals** should have Full Control:
   - SYSTEM
   - Administrators
   - Your User Account

## Verification

After setting permissions, verify with:

```powershell
icacls "C:\Users\[YOUR_USERNAME]\.cursor"
```

**Expected output:**
```
C:\Users\[YOUR_USERNAME]\.cursor
NT AUTHORITY\SYSTEM:(OI)(CI)(F)
BUILTIN\Administrators:(OI)(CI)(F)
[YOUR_USERNAME]:(OI)(CI)(F)
```

All should show `(OI)(CI)(F)` which means:
- `(OI)` = Object Inherit (files inherit)
- `(CI)` = Container Inherit (folders inherit)
- `(F)` = Full Control

## Troubleshooting

**If inheritance won't enable:**
- Check parent folder permissions first
- Make sure you're not blocking inheritance somewhere
- Try the PowerShell reset method

**If permissions still don't work:**
- Make sure Cursor is completely closed
- Restart Windows (sometimes needed for permission changes)
- Check if antivirus is interfering

## Complete Checklist for SIMPC1

- [ ] Navigate to `C:\Users\[YOUR_USERNAME]\.cursor`
- [ ] Open Properties → Security → Advanced
- [ ] Verify all permissions show "Inherited from: C:\Users\[YOUR_USERNAME]\"
- [ ] If not inherited, enable inheritance
- [ ] Verify "Replace all child object..." checkbox is UNCHECKED
- [ ] Verify parent folder has Full Control for your user
- [ ] Restart Cursor
- [ ] Test auto-approval

