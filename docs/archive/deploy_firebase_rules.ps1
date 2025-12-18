# Deploy Firebase Rules Script
# This script automates deployment of Firestore and Storage rules

Write-Host "=== Firebase Rules Deployment ===" -ForegroundColor Cyan
Write-Host ""

# Check if Firebase CLI is installed
$firebaseInstalled = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseInstalled) {
    Write-Host "❌ Firebase CLI not found!" -ForegroundColor Red
    Write-Host "Install with: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Firebase CLI found: $(firebase --version)" -ForegroundColor Green
Write-Host ""

# Check if project is linked
if (-not (Test-Path ".firebaserc")) {
    Write-Host "⚠️  .firebaserc not found. Run: firebase use --add" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Firebase project linked: $(Get-Content .firebaserc | ConvertFrom-Json).projects.default" -ForegroundColor Green
Write-Host ""

# Deploy both Firestore and Storage rules
Write-Host "🚀 Deploying Firebase rules..." -ForegroundColor Yellow
Write-Host ""

$deployOutput = firebase deploy --only firestore:rules,storage 2>&1
$deployOutput | Out-Host

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ All Firebase rules deployed successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host "Exit code: $LASTEXITCODE" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ All Firebase rules deployed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Rules are now live in Firebase Console." -ForegroundColor Cyan

