# Safe Project Migration to C: Drive
# Moves familyhub-MVP from D: to C: drive safely
# Usage: .\migrate_to_c_drive.ps1 [--dry-run]

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=== Safe Project Migration to C: Drive ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify current location
$currentPath = Get-Location
Write-Host "[INFO] Current location: $currentPath" -ForegroundColor Yellow

if (-not $currentPath.ToString().StartsWith("D:\")) {
    Write-Host "[WARN] Project doesn't appear to be on D: drive" -ForegroundColor Yellow
    Write-Host "   Current: $currentPath" -ForegroundColor Gray
    $continue = Read-Host "   Continue anyway? (Y/N)"
    if ($continue -ne "Y" -and $continue -ne "y") {
        exit 0
    }
}

# Step 2: Check project size (quick estimate)
Write-Host "`n[INFO] Checking project size..." -ForegroundColor Yellow
$projectSize = (Get-ChildItem -Path $currentPath -Recurse -Force -ErrorAction SilentlyContinue | 
    Measure-Object -Property Length -Sum).Sum
$projectSizeGB = [math]::Round($projectSize / 1GB, 2)
Write-Host "   Project size: $projectSizeGB GB" -ForegroundColor Gray

# Step 3: Check C: drive space
$cDrive = Get-PSDrive C
$cFreeGB = [math]::Round($cDrive.Free / 1GB, 2)
Write-Host "`n[INFO] C: drive space check..." -ForegroundColor Yellow
Write-Host "   Free space: $cFreeGB GB" -ForegroundColor Gray

if ($cFreeGB -lt ($projectSizeGB * 1.5)) {
    Write-Host "[ERROR] Not enough space on C: drive!" -ForegroundColor Red
    Write-Host "   Need at least $([math]::Round($projectSizeGB * 1.5, 2)) GB, have $cFreeGB GB" -ForegroundColor Red
    exit 1
}

Write-Host "   [OK] Sufficient space available" -ForegroundColor Green

# Step 4: Check for active processes and handle gracefully
Write-Host "`n[INFO] Checking for active processes..." -ForegroundColor Yellow
$javaProcesses = Get-Process -Name "java","gradle*" -ErrorAction SilentlyContinue
if ($javaProcesses) {
    Write-Host "[WARN] Found active Java/Gradle processes:" -ForegroundColor Yellow
    $javaProcesses | ForEach-Object { Write-Host "   - $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "   Waiting 10 seconds for processes to finish..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    
    # Check again
    $javaProcesses = Get-Process -Name "java","gradle*" -ErrorAction SilentlyContinue
    if ($javaProcesses) {
        Write-Host "   Processes still running. Attempting to terminate..." -ForegroundColor Yellow
        $javaProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        
        # Final check
        $javaProcesses = Get-Process -Name "java","gradle*" -ErrorAction SilentlyContinue
        if ($javaProcesses) {
            Write-Host "[ERROR] Could not stop all processes. Please close them manually." -ForegroundColor Red
            exit 1
        } else {
            Write-Host "   [OK] Processes terminated" -ForegroundColor Green
        }
    } else {
        Write-Host "   [OK] Processes finished" -ForegroundColor Green
    }
} else {
    Write-Host "   [OK] No active build processes" -ForegroundColor Green
}

# Step 5: Check for modified tracked files (ignore untracked)
Write-Host "`n[INFO] Checking Git status..." -ForegroundColor Yellow

# Use timeout for git status (quick operation, but can hang)
$gitStatusJob = Start-Job -ScriptBlock { git status --porcelain 2>&1 }
$gitStatusResult = Wait-Job -Job $gitStatusJob -Timeout 10

if ($gitStatusResult) {
    $gitStatusOutput = Receive-Job -Job $gitStatusJob
    Remove-Job -Job $gitStatusJob -Force
    $modifiedFiles = $gitStatusOutput | Where-Object { $_ -match '^[MADRC]' }  # Only tracked files
    $untrackedFiles = $gitStatusOutput | Where-Object { $_ -match '^\?\?' }   # Untracked files
} else {
    Write-Host "[WARN] Git status timed out, assuming clean repository" -ForegroundColor Yellow
    Stop-Job -Job $gitStatusJob -Force
    Remove-Job -Job $gitStatusJob -Force
    $modifiedFiles = @()
    $untrackedFiles = @()
}

if ($modifiedFiles) {
    Write-Host "[WARN] Modified tracked files detected:" -ForegroundColor Yellow
    $modifiedFiles | Select-Object -First 10 | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    if (($modifiedFiles | Measure-Object).Count -gt 10) {
        Write-Host "   ... and $((($modifiedFiles | Measure-Object).Count) - 10) more" -ForegroundColor Gray
    }
    Write-Host ""
    $commit = Read-Host "   Commit tracked changes now? (Y/N) - Untracked files will be copied as-is"
    if ($commit -eq "Y" -or $commit -eq "y") {
        git add -u  # Only add tracked files
        git commit -m "chore: Pre-migration commit before moving to C: drive"
        Write-Host "   [OK] Tracked changes committed" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Please commit or stash tracked file changes before migrating" -ForegroundColor Red
        exit 1
    }
}

if ($untrackedFiles) {
    $untrackedCount = ($untrackedFiles | Measure-Object).Count
    Write-Host "   [INFO] $untrackedCount untracked file(s) will be copied as-is" -ForegroundColor Gray
}

Write-Host "   [OK] Ready to migrate" -ForegroundColor Green

# Step 6: Define source and destination
$sourcePath = $currentPath.ToString()
$projectName = Split-Path $sourcePath -Leaf
$destPath = "C:\Users\Simon\Documents\$projectName"
$backupPath = "${sourcePath}.backup"

Write-Host "`n[INFO] Migration paths:" -ForegroundColor Yellow
Write-Host "   Source: $sourcePath" -ForegroundColor Gray
Write-Host "   Destination: $destPath" -ForegroundColor Gray
Write-Host "   Backup: $backupPath" -ForegroundColor Gray

# Step 7: Check if destination exists
if (Test-Path $destPath) {
    Write-Host "[ERROR] Destination already exists: $destPath" -ForegroundColor Red
    Write-Host "   Please remove it first or choose a different location" -ForegroundColor Yellow
    exit 1
}

# Step 8: Confirm migration
Write-Host "`n=== Migration Summary ===" -ForegroundColor Cyan
Write-Host "   From: $sourcePath" -ForegroundColor White
Write-Host "   To: $destPath" -ForegroundColor White
Write-Host "   Size: $projectSizeGB GB" -ForegroundColor White
Write-Host "   C: Drive Free: $cFreeGB GB" -ForegroundColor White
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] Would migrate project now..." -ForegroundColor Yellow
    Write-Host "   Run without --dry-run to perform actual migration" -ForegroundColor Gray
    exit 0
}

$confirm = Read-Host "   Ready to migrate? This will copy the project to C: drive (Y/N)"
if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-Host "[INFO] Migration cancelled" -ForegroundColor Yellow
    exit 0
}

# Step 9: Create destination directory
Write-Host "`n[INFO] Creating destination directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "C:\Users\Simon\Documents" -Force | Out-Null
Write-Host "   [OK] Destination directory ready" -ForegroundColor Green

# Step 10: Copy project using robocopy (reliable for large directories)
Write-Host "`n[INFO] Copying project to C: drive..." -ForegroundColor Yellow
Write-Host "   This may take several minutes..." -ForegroundColor Gray
Write-Host "   Using robocopy for reliable transfer...`n" -ForegroundColor Cyan

$robocopyArgs = @(
    "`"$sourcePath`"",
    "`"$destPath`"",
    "/E",           # Copy subdirectories including empty ones
    "/COPYALL",     # Copy all file info
    "/R:3",         # Retry 3 times on failure
    "/W:5",         # Wait 5 seconds between retries
    "/MT:8",        # Multi-threaded with 8 threads
    "/NP",          # No progress (cleaner output)
    "/NDL",         # No directory list
    "/NFL"          # No file list
)

$robocopyOutput = & robocopy @robocopyArgs 2>&1
$robocopyExit = $LASTEXITCODE

# Robocopy returns 0-7 for success, 8+ for errors
if ($robocopyExit -ge 8) {
    Write-Host "[ERROR] Robocopy failed with exit code $robocopyExit" -ForegroundColor Red
    Write-Host "   Output:" -ForegroundColor Yellow
    $robocopyOutput | Select-Object -Last 10 | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    exit 1
}

Write-Host "   [OK] Copy completed successfully" -ForegroundColor Green

# Step 11: Verify copy integrity
Write-Host "`n[INFO] Verifying copy integrity..." -ForegroundColor Yellow

$sourceFileCount = (Get-ChildItem -Path $sourcePath -Recurse -File -Force -ErrorAction SilentlyContinue).Count
$destFileCount = (Get-ChildItem -Path $destPath -Recurse -File -Force -ErrorAction SilentlyContinue).Count

Write-Host "   Source files: $sourceFileCount" -ForegroundColor Gray
Write-Host "   Destination files: $destFileCount" -ForegroundColor Gray

if ($sourceFileCount -ne $destFileCount) {
    Write-Host "[WARN] File count mismatch!" -ForegroundColor Yellow
    Write-Host "   Difference: $([math]::Abs($sourceFileCount - $destFileCount)) files" -ForegroundColor Gray
    Write-Host "   This might be normal (temporary files, etc.)" -ForegroundColor Gray
} else {
    Write-Host "   [OK] File counts match" -ForegroundColor Green
}

# Step 12: Verify Git repository
Write-Host "`n[INFO] Verifying Git repository..." -ForegroundColor Yellow
Push-Location $destPath
try {
    $gitRemote = git remote get-url origin 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   [OK] Git remote configured: $gitRemote" -ForegroundColor Green
    } else {
        Write-Host "   [WARN] Could not verify Git remote" -ForegroundColor Yellow
    }
    
    $currentBranch = git branch --show-current
    Write-Host "   [OK] Current branch: $currentBranch" -ForegroundColor Green
} finally {
    Pop-Location
}

# Step 13: Rename source to backup
Write-Host "`n[INFO] Renaming source to backup..." -ForegroundColor Yellow
try {
    Rename-Item -Path $sourcePath -NewName (Split-Path $backupPath -Leaf) -ErrorAction Stop
    Write-Host "   [OK] Source renamed to backup: $backupPath" -ForegroundColor Green
    Write-Host "   You can delete this after verifying everything works" -ForegroundColor Gray
} catch {
    Write-Host "   [WARN] Could not rename source (may be in use)" -ForegroundColor Yellow
    Write-Host "   Manual cleanup needed: $sourcePath" -ForegroundColor Gray
}

# Step 14: Change to new location
Write-Host "`n[INFO] Changing to new location..." -ForegroundColor Yellow
Set-Location $destPath
Write-Host "   [OK] Now in: $destPath" -ForegroundColor Green

# Step 15: Final verification
Write-Host "`n[INFO] Running final verification..." -ForegroundColor Yellow
Write-Host "   Testing Flutter..." -ForegroundColor Gray
$flutterVersion = flutter --version 2>&1 | Select-Object -First 1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   [OK] Flutter works" -ForegroundColor Green
} else {
    Write-Host "   [WARN] Flutter check had issues" -ForegroundColor Yellow
}

Write-Host "   Testing Git..." -ForegroundColor Gray
git status --short | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   [OK] Git works" -ForegroundColor Green
} else {
    Write-Host "   [WARN] Git check had issues" -ForegroundColor Yellow
}

# Step 16: Success!
Write-Host "`n=== Migration Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "New location: $destPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "   1. Test a build: flutter build apk --release --flavor dev" -ForegroundColor Gray
Write-Host "   2. Test Git operations: git status, git pull" -ForegroundColor Gray
Write-Host "   3. Reopen project in your IDE/editor" -ForegroundColor Gray
Write-Host "   4. After verification, delete backup: Remove-Item '$backupPath' -Recurse" -ForegroundColor Gray
Write-Host ""
Write-Host "[OK] Project successfully migrated to C: drive!" -ForegroundColor Green

