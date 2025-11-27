# Close all dev processes and move project
# Run this from a NEW PowerShell window (not in the project folder)

Write-Host "=== Close Dev Processes and Move Project ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Close development processes
Write-Host "Step 1: Closing development processes..." -ForegroundColor Yellow
$processesToClose = @("Code", "Cursor", "dart", "flutter", "java", "adb", "qemu-system")

foreach ($procName in $processesToClose) {
    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Host "Closing $procName processes..." -ForegroundColor Cyan
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }
}

Write-Host "Waiting 3 seconds for processes to fully close..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# Step 2: Check if folder is still locked
$sourcePath = "C:\Users\simon\OneDrive\Desktop\familyhub-MVP"
$destPath = "C:\Users\simon\Documents\familyhub-MVP"

Write-Host ""
Write-Host "Step 2: Checking if folder is accessible..." -ForegroundColor Yellow

if (-not (Test-Path $sourcePath)) {
    Write-Host "Source path not found: $sourcePath" -ForegroundColor Red
    exit 1
}

# Try to access the folder
try {
    $testFile = Join-Path $sourcePath "test-lock-check.tmp"
    New-Item -ItemType File -Path $testFile -Force -ErrorAction Stop | Out-Null
    Remove-Item $testFile -Force -ErrorAction Stop
    Write-Host "✅ Folder is accessible" -ForegroundColor Green
} catch {
    Write-Host "❌ Folder is still locked: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try these steps:" -ForegroundColor Yellow
    Write-Host "1. Close Cursor/VS Code completely"
    Write-Host "2. Close all terminal windows"
    Write-Host "3. Check Task Manager for any remaining processes"
    Write-Host "4. Run this script again from a NEW PowerShell window"
    exit 1
}

# Step 3: Move the project
Write-Host ""
Write-Host "Step 3: Moving project..." -ForegroundColor Yellow
Write-Host "From: $sourcePath"
Write-Host "To:   $destPath"

# Create destination parent if needed
$parentDir = Split-Path -Parent $destPath
if (-not (Test-Path $parentDir)) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

# Remove destination if exists
if (Test-Path $destPath) {
    Write-Host "Destination exists, removing..." -ForegroundColor Yellow
    Remove-Item -Path $destPath -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

try {
    Move-Item -Path $sourcePath -Destination $destPath -Force -ErrorAction Stop
    Write-Host "✅ Project moved successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "New location: $destPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Open Cursor/VS Code in: $destPath"
    Write-Host "2. Run: flutter clean"
    Write-Host "3. Run: flutter pub get"
    Write-Host "4. Run: flutter run"
    
    # Optionally open the new location
    $open = Read-Host "`nOpen new location in Explorer? (y/n)"
    if ($open -eq "y" -or $open -eq "Y") {
        Start-Process explorer.exe -ArgumentList $destPath
    }
    
} catch {
    Write-Host "❌ Error moving project: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "The folder is still in use. Try:" -ForegroundColor Yellow
    Write-Host "1. Close ALL windows (Cursor, terminals, etc.)"
    Write-Host "2. Open Task Manager and end any 'dart', 'flutter', 'java' processes"
    Write-Host "3. Restart your computer if needed"
    Write-Host "4. Run this script again from a fresh PowerShell window"
    exit 1
}

