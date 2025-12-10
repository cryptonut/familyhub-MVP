# Firebase Rules Deployment Script with Verification
# This script ensures rules are actually deployed and verifies the deployment

param(
    [switch]$Force = $false
)

Write-Host "=== Firebase Rules Deployment (Verified) ===" -ForegroundColor Cyan
Write-Host ""

# Check Firebase CLI
$firebaseInstalled = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseInstalled) {
    Write-Host "ERROR: Firebase CLI not found!" -ForegroundColor Red
    Write-Host "Install with: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

Write-Host "OK: Firebase CLI: $(firebase --version)" -ForegroundColor Green

# Check project
$firebaserc = Get-Content .firebaserc -ErrorAction SilentlyContinue | ConvertFrom-Json
if ($firebaserc) {
    $projectId = $firebaserc.projects.default
    Write-Host "OK: Active Project: $projectId" -ForegroundColor Green
} else {
    $projectOutput = firebase use 2>&1 | Out-String
    if ($projectOutput -match "family-hub-71ff0") {
        $projectId = "family-hub-71ff0"
        Write-Host "OK: Active Project: $projectId" -ForegroundColor Green
    } else {
        Write-Host "ERROR: No Firebase project selected!" -ForegroundColor Red
        Write-Host "Run: firebase use --add" -ForegroundColor Yellow
        exit 1
    }
}
Write-Host ""

# Get file info
$firestoreRules = "firestore.rules"
$storageRules = "storage.rules"

if (-not (Test-Path $firestoreRules)) {
    Write-Host "ERROR: $firestoreRules not found!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $storageRules)) {
    Write-Host "ERROR: $storageRules not found!" -ForegroundColor Red
    exit 1
}

$firestoreLines = (Get-Content $firestoreRules | Measure-Object -Line).Lines
$storageLines = (Get-Content $storageRules | Measure-Object -Line).Lines

Write-Host "Firestore Rules: $firestoreLines lines" -ForegroundColor Cyan
Write-Host "Storage Rules: $storageLines lines" -ForegroundColor Cyan
Write-Host ""

# Verify openMatchmakingEnabled is in Firestore rules
$hasOpenMatchmaking = (Get-Content $firestoreRules | Select-String -Pattern "openMatchmakingEnabled").Count
if ($hasOpenMatchmaking -eq 0) {
    Write-Host "WARNING: openMatchmakingEnabled not found in Firestore rules!" -ForegroundColor Yellow
} else {
    Write-Host "OK: Found $hasOpenMatchmaking references to openMatchmakingEnabled" -ForegroundColor Green
}
Write-Host ""

# Deploy Firestore rules
Write-Host "Deploying Firestore rules..." -ForegroundColor Yellow
$firestoreDeploy = firebase deploy --only firestore:rules 2>&1
$firestoreDeploy | Out-Host

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Firestore rules deployment failed!" -ForegroundColor Red
    exit 1
}

# Check if it actually uploaded or was skipped
$wasUploaded = $firestoreDeploy | Select-String -Pattern "uploading rules"
$wasSkipped = $firestoreDeploy | Select-String -Pattern "already up to date.*skipping"

if ($wasSkipped) {
    Write-Host ""
    Write-Host "WARNING: Firebase CLI says rules are already up to date and skipped upload!" -ForegroundColor Yellow
    Write-Host "This might mean the deployed rules do not match your local file." -ForegroundColor Yellow
    Write-Host "Consider deploying via Firebase Console to ensure rules are updated." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Console URL: https://console.firebase.google.com/project/$projectId/firestore/rules" -ForegroundColor Cyan
} elseif ($wasUploaded) {
    Write-Host "OK: Firestore rules uploaded successfully!" -ForegroundColor Green
} else {
    Write-Host "WARNING: Could not determine if rules were uploaded or skipped" -ForegroundColor Yellow
}

Write-Host ""

# Deploy Storage rules
Write-Host "Deploying Storage rules..." -ForegroundColor Yellow
Write-Host "WARNING: This will overwrite any manual changes in Firebase Console!" -ForegroundColor Yellow
Write-Host "If you manually updated rules in console, run sync_rules_from_console.ps1 first" -ForegroundColor Yellow
Write-Host ""

$storageDeploy = firebase deploy --only storage 2>&1
$storageDeploy | Out-Host

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Storage rules deployment failed!" -ForegroundColor Red
    exit 1
}

$storageUploaded = $storageDeploy | Select-String -Pattern "uploading.*rules"
$storageSkipped = $storageDeploy | Select-String -Pattern "already up to date.*skipping"

if ($storageSkipped) {
    Write-Host "WARNING: Storage rules were skipped (already up to date)" -ForegroundColor Yellow
    Write-Host "If console shows different rules, they may have been manually updated." -ForegroundColor Yellow
    Write-Host "Run sync_rules_from_console.ps1 to sync console rules to local file first." -ForegroundColor Yellow
} elseif ($storageUploaded) {
    Write-Host "OK: Storage rules uploaded successfully!" -ForegroundColor Green
} else {
    Write-Host "OK: Storage rules deployed (status unclear)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host "Firestore Rules: $firestoreLines lines" -ForegroundColor White
Write-Host "Storage Rules: $storageLines lines" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Verify in Firebase Console:" -ForegroundColor White
Write-Host "     Firestore: https://console.firebase.google.com/project/$projectId/firestore/rules" -ForegroundColor Cyan
Write-Host "     Storage: https://console.firebase.google.com/project/$projectId/storage/rules" -ForegroundColor Cyan
Write-Host "  2. Check Last published timestamp" -ForegroundColor White
Write-Host "  3. Search for openMatchmakingEnabled in Firestore rules" -ForegroundColor White
Write-Host ""

if ($wasSkipped) {
    Write-Host "IMPORTANT: If rules do not appear updated in console, deploy manually:" -ForegroundColor Yellow
    Write-Host "  1. Open firestore.rules in Notepad" -ForegroundColor White
    Write-Host "  2. Copy all content" -ForegroundColor White
    Write-Host "  3. Paste into Firebase Console and click Publish" -ForegroundColor White
    Write-Host ""
}

Write-Host "Deployment script completed!" -ForegroundColor Green
