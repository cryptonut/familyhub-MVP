# PowerShell script to fix Android Studio lock file issue
# This script removes the lock file that prevents Android Studio from starting

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Android Studio Lock File Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for running Android Studio processes
Write-Host "Checking for running Android Studio processes..." -ForegroundColor Yellow
$studioProcesses = Get-Process | Where-Object {
    $_.ProcessName -like "*studio*" -or 
    $_.ProcessName -like "*idea*" -or 
    ($_.ProcessName -eq "java" -and $_.MainWindowTitle -like "*Android Studio*")
}

if ($studioProcesses) {
    Write-Host "Found running Android Studio processes:" -ForegroundColor Yellow
    $studioProcesses | Format-Table ProcessName, Id, MainWindowTitle -AutoSize
    
    $kill = Read-Host "Do you want to kill these processes? (y/n)"
    if ($kill -eq "y" -or $kill -eq "Y") {
        $studioProcesses | ForEach-Object {
            Write-Host "Killing process: $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Yellow
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 2
        Write-Host "Processes killed." -ForegroundColor Green
    }
} else {
    Write-Host "No Android Studio processes found." -ForegroundColor Green
}

Write-Host ""

# Remove lock file
$lockPath = "$env:APPDATA\Google\AndroidStudio2025.2.2\.lock"
Write-Host "Checking for lock file at: $lockPath" -ForegroundColor Yellow

if (Test-Path $lockPath) {
    try {
        Remove-Item $lockPath -Force -ErrorAction Stop
        Write-Host "Lock file removed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Error removing lock file: $_" -ForegroundColor Red
        Write-Host "You may need to run this script as Administrator" -ForegroundColor Yellow
    }
} else {
    Write-Host "Lock file not found (this is good)." -ForegroundColor Green
}

Write-Host ""

# Check for other lock files in subdirectories
Write-Host "Checking for other lock files..." -ForegroundColor Yellow
$studioDir = "$env:APPDATA\Google\AndroidStudio2025.2.2"
if (Test-Path $studioDir) {
    $lockFiles = Get-ChildItem -Path $studioDir -Filter "*.lock" -Recurse -ErrorAction SilentlyContinue
    if ($lockFiles) {
        Write-Host "Found additional lock files:" -ForegroundColor Yellow
        $lockFiles | ForEach-Object {
            Write-Host "  - $($_.FullName)" -ForegroundColor Yellow
            try {
                Remove-Item $_.FullName -Force -ErrorAction Stop
                Write-Host "    Removed" -ForegroundColor Green
            } catch {
                Write-Host "    Could not remove: $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "No additional lock files found." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now try opening Android Studio." -ForegroundColor Yellow
Write-Host "If it still doesn't work, try:" -ForegroundColor Yellow
Write-Host "1. Run this script as Administrator" -ForegroundColor White
Write-Host "2. Restart your computer" -ForegroundColor White
Write-Host "3. Use 'Reset Settings&Plugins' option in Android Studio error dialog" -ForegroundColor White
Write-Host ""

