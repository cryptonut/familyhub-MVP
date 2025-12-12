# PowerShell script to run tests with Firebase Emulator
# This script starts the emulator in the background, runs tests, then stops the emulator

param(
    [string]$TestPath = "test/integration/extended_family_hub_integration_test.dart"
)

Write-Host "Firebase Emulator Test Runner" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green
Write-Host ""

# Check if emulator is already running
$emulatorRunning = Test-NetConnection -ComputerName localhost -Port 8080 -InformationLevel Quiet -WarningAction SilentlyContinue

if ($emulatorRunning) {
    Write-Host "Firebase Emulator appears to be running on port 8080" -ForegroundColor Yellow
    Write-Host "Running tests against existing emulator..." -ForegroundColor Cyan
    Write-Host ""
    
    flutter test $TestPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Tests passed!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Some tests failed. Check output above." -ForegroundColor Red
    }
} else {
    Write-Host "Firebase Emulator is not running." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To run tests with emulator:" -ForegroundColor Cyan
    Write-Host "1. Start emulator: .\start_emulator_for_tests.ps1" -ForegroundColor White
    Write-Host "2. In another terminal, run: flutter test $TestPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Or run integration tests (no emulator needed):" -ForegroundColor Cyan
    Write-Host "flutter test test/integration/extended_family_hub_integration_test.dart" -ForegroundColor White
}

