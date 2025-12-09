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
Write-Host "[INFO] Checking git branch..." -ForegroundColor Yellow
$currentBranch = git branch --show-current

if ($currentBranch -ne "develop") {
    Write-Host "[WARN] WARNING: Not on 'develop' branch!" -ForegroundColor Yellow
    Write-Host "   Current branch: $currentBranch" -ForegroundColor Gray
    $continue = Read-Host "   Continue anyway? (Y/N)"
    if ($continue -ne "Y" -and $continue -ne "y") {
        Write-Host "   Aborted." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[OK] On develop branch" -ForegroundColor Green
}

# Step 2: Verify Firebase CLI is available
Write-Host "`n[INFO] Checking Firebase CLI..." -ForegroundColor Yellow
$firebaseCmd = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseCmd) {
    Write-Host "[ERROR] Firebase CLI not found!" -ForegroundColor Red
    Write-Host "   Install it with: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Firebase CLI found: $(firebase --version)" -ForegroundColor Green

# Step 3: Get latest changes
Write-Host "`n[INFO] Pulling latest changes..." -ForegroundColor Yellow
git pull origin develop
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Warning: Git pull had issues, continuing anyway..." -ForegroundColor Yellow
}

# Step 4: Get commit info for release notes
Write-Host "`n[INFO] Generating release notes..." -ForegroundColor Yellow
$commitHash = git rev-parse --short HEAD
$commitMessage = git log -1 --pretty=format:"%s"
$commitDate = git log -1 --pretty=format:"%ad" --date=short
$commitAuthor = git log -1 --pretty=format:"%an"
$commitCount = (git rev-list --count HEAD).Trim()
$branchName = git branch --show-current

# Get recent changes (last 5 commits)
$recentCommits = git log -5 --pretty=format:"- %s (%an)" --abbrev-commit

if ([string]::IsNullOrEmpty($Notes)) {
    $releaseNotes = "FamilyHub Dev Build - Ready for Testing!`n`n" +
                    "========================================`n`n" +
                    "BUILD INFO:`n" +
                    "   Branch: $branchName`n" +
                    "   Commit: $commitHash`n" +
                    "   Build #: $commitCount`n" +
                    "   Deployed: $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n" +
                    "LATEST CHANGES:`n" +
                    "   $commitMessage`n" +
                    "   By: $commitAuthor on $commitDate`n`n" +
                    "RECENT UPDATES:`n" +
                    "$recentCommits`n`n" +
                    "========================================`n`n" +
                    "TESTING NOTES:`n" +
                    "   - This is a development build from the develop branch`n" +
                    "   - Please report any issues you encounter`n" +
                    "   - Your feedback helps us improve!`n`n" +
                    "Thank you for testing!"
} else {
    $releaseNotes = $Notes
}

Write-Host "   Release notes:" -ForegroundColor Gray
$releaseNotes -split "`n" | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }

# Step 5: Verify dev google-services.json exists
Write-Host "`n[INFO] Verifying dev configuration..." -ForegroundColor Yellow
$googleServicesPath = "android/app/src/dev/google-services.json"
if (-not (Test-Path $googleServicesPath)) {
    Write-Host "[ERROR] Dev google-services.json not found at: $googleServicesPath" -ForegroundColor Red
    Write-Host "   Please set up dev flavor in Firebase Console first." -ForegroundColor Yellow
    exit 1
}

# Step 6: Get App ID from google-services.json
$json = Get-Content $googleServicesPath | ConvertFrom-Json
$appId = $json.client[0].client_info.mobilesdk_app_id
$packageName = $json.client[0].client_info.android_client_info.package_name

Write-Host "[OK] Dev configuration found" -ForegroundColor Green
Write-Host "   App ID: $appId" -ForegroundColor Gray
Write-Host "   Package: $packageName" -ForegroundColor Gray

# Step 7: Clean previous build
Write-Host "`n[INFO] Cleaning previous build..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Warning: Flutter clean had issues, continuing anyway..." -ForegroundColor Yellow
}

# Step 8: Get dependencies
Write-Host "`n[INFO] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to get dependencies!" -ForegroundColor Red
    exit 1
}

# Step 9: Build dev APK
Write-Host "`n[INFO] Building dev release APK..." -ForegroundColor Yellow
Write-Host "   This may take a few minutes..." -ForegroundColor Gray
Write-Host "   Build progress will be shown below...`n" -ForegroundColor Cyan

# Build APK - let Flutter output directly to console for real-time progress
flutter build apk --release --flavor dev --dart-define=FLAVOR=dev

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[ERROR] Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n[OK] Build completed successfully!" -ForegroundColor Green

# Step 10: Verify APK was created
$apkPath = "build\app\outputs\flutter-apk\app-dev-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Host "[ERROR] APK not found at: $apkPath" -ForegroundColor Red
    exit 1
}

$apkSize = (Get-Item $apkPath).Length / 1MB
Write-Host "[OK] APK built successfully!" -ForegroundColor Green
Write-Host "   Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Gray
Write-Host "   Location: $apkPath" -ForegroundColor Gray

# Step 11: Distribute to Firebase App Distribution
Write-Host "`n[INFO] Distributing to dev-testers group..." -ForegroundColor Yellow
Write-Host "   App ID: $appId" -ForegroundColor Gray
Write-Host "   Group: dev-testers" -ForegroundColor Gray
Write-Host ""

# Prepare release notes - replace newlines with spaces for command line
$releaseNotesSingleLine = $releaseNotes -replace "`r`n|`n|`r", " "

$distributeOutput = firebase appdistribution:distribute $apkPath --app $appId --groups "dev-testers" --release-notes "$releaseNotesSingleLine" 2>&1
$distributeOutput | Out-Host

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Successfully deployed to dev-testers!" -ForegroundColor Green
    Write-Host "   Testers will receive an email with download link." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Release Summary:" -ForegroundColor Cyan
    Write-Host "   Branch: develop" -ForegroundColor Gray
    Write-Host "   Commit: $commitHash" -ForegroundColor Gray
    Write-Host "   APK: $apkPath" -ForegroundColor Gray
    Write-Host "   Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Gray
    Write-Host "   Group: dev-testers" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Deployment failed!" -ForegroundColor Red
    Write-Host "   Exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Verify Firebase CLI is authenticated: firebase login" -ForegroundColor Gray
    Write-Host "   2. Check that 'dev-testers' group exists in Firebase Console" -ForegroundColor Gray
    Write-Host "   3. Verify App ID is correct: $appId" -ForegroundColor Gray
    Write-Host "   4. Check that dev flavor is registered in Firebase Console" -ForegroundColor Gray
    exit 1
}

Write-Host "[OK] Release deployment complete!" -ForegroundColor Green

