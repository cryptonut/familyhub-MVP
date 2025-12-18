# Fix Workspace Root Issue

## Problem
Cursor workspace root is pointing to `D:\Users\Simon\Documents\familyhub-MVP` but the project is on `C:\Users\Simon\Documents\familyhub-MVP`.

## Solution

**Option 1: Open Workspace File (Recommended)**
1. In Cursor, go to `File > Open Workspace from File...`
2. Select `familyhub-MVP.code-workspace` from the project root
3. This will open the workspace with the correct C: drive path

**Option 2: Reopen Folder**
1. In Cursor, go to `File > Open Folder...`
2. Navigate to `C:\Users\Simon\Documents\familyhub-MVP`
3. Select the folder
4. This will set the workspace root to C: drive

**Option 3: Use Command Line**
```powershell
cd C:\Users\Simon\Documents\familyhub-MVP
code familyhub-MVP.code-workspace
```

## Verification
After fixing, verify the workspace root by:
- Opening a terminal in Cursor
- Running `Get-Location` - should show `C:\Users\Simon\Documents\familyhub-MVP`
- Creating a test file - should appear in C: drive location

## Temporary Workaround (Until Fixed)
All file write operations are currently using absolute `C:\` paths to ensure files are created in the correct location.

