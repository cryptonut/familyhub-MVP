# PowerShell script to add UAT test cases to Firestore
# This script runs the Dart script that adds test cases for Roadmap Phase 1.1 & 1.2

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "UAT Test Cases Addition Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterPath) {
    Write-Host "Error: Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Flutter and ensure it's in your PATH" -ForegroundColor Yellow
    exit 1
}

# Check if we're in the project root
if (-not (Test-Path "lib" -PathType Container)) {
    Write-Host "Error: This script must be run from the project root directory" -ForegroundColor Red
    exit 1
}

# Check if the Dart script exists
$scriptPath = "scripts/add_uat_test_cases.dart"
if (-not (Test-Path $scriptPath)) {
    Write-Host "Error: Script not found at $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "Running Dart script to add UAT test cases..." -ForegroundColor Yellow
Write-Host ""

# Run the Dart script using Flutter
try {
    flutter pub get
    dart run $scriptPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Success: Test cases added to Firestore!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Verify test cases in Firebase Console" -ForegroundColor White
        Write-Host "2. Test cases should now appear in the UAT screen" -ForegroundColor White
        Write-Host "3. Testers can now access and test these cases" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "Error: Script failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "Error: Failed to run script" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

