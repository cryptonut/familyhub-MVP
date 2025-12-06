# Fix D: Drive 100% Utilization During Builds

## Problem
Windows is using D: drive for the page file (`D:\pagefile.sys`), causing 100% disk utilization during Flutter/Gradle builds.

## Solution: Move Page File to C: Drive

### Steps:

1. **Open System Properties:**
   - Press `Win + R`
   - Type: `sysdm.cpl`
   - Press Enter

2. **Go to Advanced Tab:**
   - Click "Settings" under "Performance"

3. **Open Virtual Memory Settings:**
   - Click "Advanced" tab
   - Click "Change..." under "Virtual memory"

4. **Remove Page File from D: Drive:**
   - Uncheck "Automatically manage paging file size for all drives"
   - Select **D: drive**
   - Select "No paging file"
   - Click "Set"
   - Click "Yes" to confirm

5. **Add Page File to C: Drive (if not already there):**
   - Select **C: drive**
   - Select "System managed size" (recommended)
   - OR select "Custom size" and set:
     - Initial size: 4096 MB (4 GB)
     - Maximum size: 8192 MB (8 GB)
   - Click "Set"

6. **Apply Changes:**
   - Click "OK" on all dialogs
   - **Restart your computer** for changes to take effect

### Alternative: Disable Page File on D: Only

If C: drive already has a page file, you can just remove it from D: drive:
- Select D: drive → "No paging file" → Set
- Keep C: drive as "System managed size"

## After Restart

1. Verify the change:
   ```powershell
   wmic pagefileset get name,initialsize,maximumsize
   ```
   Should only show `C:\pagefile.sys`, not `D:\pagefile.sys`

2. Test a build:
   ```powershell
   flutter clean
   flutter build apk --release --flavor dev --dart-define=FLAVOR=dev
   ```

3. Monitor D: drive in Task Manager - it should stay low now!

## Why This Happens

- Flutter/Dart builds use a lot of RAM (especially with Gradle)
- When RAM fills up, Windows uses the page file (virtual memory)
- If the page file is on a slow HDD (D: drive), it becomes a bottleneck
- Moving it to the faster SSD (C: drive) eliminates the bottleneck

## Additional Optimization

If you still have RAM issues, you can reduce Gradle memory usage in `android/gradle.properties`:
```
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G ...
```
(Currently set to 8G, which might be too high for your 8GB system)

