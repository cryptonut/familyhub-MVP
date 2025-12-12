# PowerShell script to start Firebase Emulator for testing
# Usage: .\start_emulator_for_tests.ps1

Write-Host "Starting Firebase Emulators for Testing..." -ForegroundColor Green
Write-Host ""

# Check if Firebase CLI is installed
$firebaseVersion = firebase --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Firebase CLI not found. Please install it first." -ForegroundColor Red
    Write-Host "Install with: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

Write-Host "Firebase CLI Version: $firebaseVersion" -ForegroundColor Cyan
Write-Host ""

# Start emulators
Write-Host "Starting emulators (Auth: 9099, Firestore: 8080, Storage: 9199, UI: 4000)..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop emulators" -ForegroundColor Yellow
Write-Host ""

firebase emulators:start

