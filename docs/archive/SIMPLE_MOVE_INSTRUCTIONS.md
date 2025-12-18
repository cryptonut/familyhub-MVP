# Simple Move Instructions - Drag & Drop

## ✅ Yes! You can just drag the folder!

This is the **easiest way** to move your project.

## Steps:

1. **Close Cursor/IDE completely** (important - prevents file lock errors)

2. **Open File Explorer**

3. **Navigate to:**
   - Source: `C:\Users\simon\Documents\familyhub-MVP`
   - Destination: `D:\` (just the D: drive root)

4. **Drag the `familyhub-MVP` folder** from Documents to D: drive

5. **Wait for the move to complete** (may take a few minutes)

6. **Optional - Create shortcut in Documents:**
   - Right-click the moved folder at `D:\familyhub-MVP`
   - Select "Create shortcut"
   - Move the shortcut to `C:\Users\simon\Documents\`
   - Rename it to `familyhub-MVP` (remove "- Shortcut" from name)

   OR create a symbolic link (more advanced):
   ```powershell
   # Run PowerShell as Administrator
   New-Item -ItemType SymbolicLink -Path "C:\Users\simon\Documents\familyhub-MVP" -Target "D:\familyhub-MVP"
   ```

7. **Reopen Cursor** and open the project from `D:\familyhub-MVP`

## That's it! 

The project is now on D: drive and will free up space on C: drive.

## After Moving:

- Open project from: `D:\familyhub-MVP`
- Run: `flutter pub get`
- Build should work now!
