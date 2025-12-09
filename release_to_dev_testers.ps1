# Automated Release Deployment Script
# Deploys develop branch to dev-testers group in Firebase App Distribution
# Usage: .\release_to_dev_testers.ps1 [--notes "Custom release notes"]

param(
    [Parameter()]
    [string]$Notes = ""
)

Write-Host "=== Release Deployment to dev-testers ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify we're on develop branch
Write-Host "📋 Checking git branch..." -ForegroundColor Yellow
$currentBranch = git branch --show-current

if ($currentBranch -ne "develop") {
    Write-Host "⚠️  WARNING: Not on 'develop' branch!" -ForegroundColor Yellow
    Write-Host "   Current branch: $currentBranch" -ForegroundColor Gray
    $continue = Read-Host "   Continue anyway? (Y/N)"
    if ($continue -ne "Y" -and $continue -ne "y") {
        Write-Host "   Aborted." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✅ On develop branch" -ForegroundColor Green
}

# Step 2: Verify Firebase CLI is available
Write-Host "`n🔍 Checking Firebase CLI..." -ForegroundColor Yellow
$firebaseCmd = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseCmd) {
    Write-Host "❌ Firebase CLI not found!" -ForegroundColor Red
    Write-Host "   Install it with: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Firebase CLI found: $(firebase --version)" -ForegroundColor Green

# Step 3: Get latest changes
Write-Host "`n📥 Pulling latest changes..." -ForegroundColor Yellow
git pull origin develop
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Warning: Git pull had issues, continuing anyway..." -ForegroundColor Yellow
}

# Step 4: Get commit info for release notes
Write-Host "`n📝 Generating release notes..." -ForegroundColor Yellow
$commitHash = git rev-parse --short HEAD
$commitMessage = git log -1 --pretty=format:"%s"
$commitDate = git log -1 --pretty=format:"%ad" --date=short
$commitAuthor = git log -1 --pretty=format:"%an"

if ([string]::IsNullOrEmpty($Notes)) {
    $releaseNotes = "Develop Branch Release`n`n" +
                    "Commit: $commitHash`n" +
                    "Date: $commitDate`n" +
                    "Author: $commitAuthor`n" +
                    "Message: $commitMessage`n`n" +
                    "Deployed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
} else {
    $releaseNotes = $Notes
}

Write-Host "   Release notes:" -ForegroundColor Gray
$releaseNotes -split "`n" | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }

# Step 5: Verify dev google-services.json exists
Write-Host "`n🔍 Verifying dev configuration..." -ForegroundColor Yellow
$googleServicesPath = "android/app/src/dev/google-services.json"
if (-not (Test-Path $googleServicesPath)) {
    Write-Host "❌ Dev google-services.json not found at: $googleServicesPath" -ForegroundColor Red
    Write-Host "   Please set up dev flavor in Firebase Console first." -ForegroundColor Yellow
    exit 1
}

# Step 6: Get App ID from google-services.json
$json = Get-Content $googleServicesPath | ConvertFrom-Json
$appId = $json.client[0].client_info.mobilesdk_app_id
$packageName = $json.client[0].client_info.android_client_info.package_name

Write-Host "✅ Dev configuration found" -ForegroundColor Green
Write-Host "   App ID: $appId" -ForegroundColor Gray
Write-Host "   Package: $packageName" -ForegroundColor Gray

# Step 7: Clean previous build
Write-Host "`n🧹 Cleaning previous build..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Warning: Flutter clean had issues, continuing anyway..." -ForegroundColor Yellow
}

# Step 8: Get dependencies
Write-Host "`n📦 Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to get dependencies!" -ForegroundColor Red
    exit 1
}

# Step 9: Build dev APK
Write-Host "`n🔨 Building dev release APK..." -ForegroundColor Yellow
Write-Host "   This may take a few minutes..." -ForegroundColor Gray
flutter build apk --release --flavor dev --dart-define=FLAVOR=dev

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

# Step 10: Verify APK was created
$apkPath = "build\app\outputs\flutter-apk\app-dev-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Host "❌ APK not found at: $apkPath" -ForegroundColor Red
    exit 1
}

$apkSize = (Get-Item $apkPath).Length / 1MB
Write-Host "✅ APK built successfully!" -ForegroundColor Green
Write-Host "   Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Gray
Write-Host "   Location: $apkPath" -ForegroundColor Gray

# Step 11: Distribute to Firebase App Distribution
Write-Host "`n🚀 Distributing to dev-testers group..." -ForegroundColor Yellow
Write-Host "   App ID: $appId" -ForegroundColor Gray
Write-Host "   Group: dev-testers" -ForegroundColor Gray
Write-Host ""

$distributeOutput = firebase appdistribution:distribute $apkPath `
    --app $appId `
    --groups "dev-testers" `
    --release-notes $releaseNotes 2>&1

$distributeOutput | Out-Host

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Successfully deployed to dev-testers!" -ForegroundColor Green
    Write-Host "   Testers will receive an email with download link." -ForegroundColor Gray
    Write-Host ""
    Write-Host "📊 Release Summary:" -ForegroundColor Cyan
    Write-Host "   Branch: develop" -ForegroundColor Gray
    Write-Host "   Commit: $commitHash" -ForegroundColor Gray
    Write-Host "   APK: $apkPath" -ForegroundColor Gray
    Write-Host "   Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Gray
    Write-Host "   Group: dev-testers" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    Write-Host "   Exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Verify Firebase CLI is authenticated: firebase login" -ForegroundColor Gray
    Write-Host "   2. Check that 'dev-testers' group exists in Firebase Console" -ForegroundColor Gray
    Write-Host "   3. Verify App ID is correct: $appId" -ForegroundColor Gray
    Write-Host "   4. Check that dev flavor is registered in Firebase Console" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ Release deployment complete!" -ForegroundColor Green

