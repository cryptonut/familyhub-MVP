# Script to test photo uploads on Android emulator

Write-Host "=== Android Emulator Photo Upload Test ===" -ForegroundColor Cyan
Write-Host ""

# Check if emulator is running
Write-Host "Checking for running emulator..." -ForegroundColor Yellow
$adbPath = "C:\Users\simon\AppData\Local\Android\sdk\platform-tools\adb.exe"
$devices = & $adbPath devices

if ($devices -match "emulator") {
    Write-Host "✓ Emulator detected!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Running Flutter app..." -ForegroundColor Yellow
    flutter run
} else {
    Write-Host "✗ No emulator detected" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start the emulator first:" -ForegroundColor Yellow
    Write-Host "1. Open Android Studio" -ForegroundColor White
    Write-Host "2. Go to Tools → Device Manager" -ForegroundColor White
    Write-Host "3. Click ▶ next to 'pixel6'" -ForegroundColor White
    Write-Host "4. Wait for emulator to boot" -ForegroundColor White
    Write-Host "5. Run this script again" -ForegroundColor White
    Write-Host ""
    Write-Host "Or start emulator from command line:" -ForegroundColor Yellow
    Write-Host '  & "C:\Users\simon\AppData\Local\Android\sdk\emulator\emulator.exe" -avd pixel6' -ForegroundColor Cyan
}

