# Automated QA Release Deployment Script
# Merges develop -> release/qa, builds QA APK, and distributes to qa-testers group
# Usage: .\release_to_qa_testers.ps1 [--notes "Custom release notes"]

param(
    [Parameter()]
    [string]$Notes = ""
)

Write-Host "=== QA Release Deployment Automation ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify we're on develop branch (will checkout release/qa)
Write-Host "[INFO] Checking current branch..." -ForegroundColor Yellow
$currentBranch = git branch --show-current
Write-Host "   Current branch: $currentBranch" -ForegroundColor Gray

# Step 2: Verify Firebase CLI is available
Write-Host "`n[INFO] Checking Firebase CLI..." -ForegroundColor Yellow
$firebaseCmd = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseCmd) {
    Write-Host "[ERROR] Firebase CLI not found!" -ForegroundColor Red
    Write-Host "   Install it with: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}
Write-Host "[OK] Firebase CLI found: $(firebase --version)" -ForegroundColor Green

# Step 3: Checkout release/qa branch
Write-Host "`n[INFO] Checking out release/qa branch..." -ForegroundColor Yellow
git fetch origin release/qa --quiet 2>&1 | Out-Null

# Check if branch exists locally
$qaBranchExists = git branch --list release/qa
if ($qaBranchExists) {
    git checkout release/qa
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to checkout release/qa branch!" -ForegroundColor Red
        exit 1
    }
} else {
    # Create branch tracking remote
    git checkout -b release/qa origin/release/qa
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to create release/qa branch!" -ForegroundColor Red
        Write-Host "   Ensure release/qa branch exists on remote: git checkout -b release/qa && git push -u origin release/qa" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "[OK] On release/qa branch" -ForegroundColor Green

# Step 4: Pull latest release/qa
Write-Host "`n[INFO] Pulling latest release/qa..." -ForegroundColor Yellow
git pull origin release/qa --no-edit --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Git pull had issues, continuing anyway..." -ForegroundColor Yellow
}

# Step 5: Merge develop into release/qa
Write-Host "`n[INFO] Merging develop into release/qa..." -ForegroundColor Yellow
Write-Host "   Fetching latest develop..." -ForegroundColor Gray
git fetch origin develop --quiet 2>&1 | Out-Null

# Merge with no-edit to avoid interactive prompts
git merge origin/develop --no-edit --no-ff -m "chore: Merge develop into release/qa for QA release"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Merge failed!" -ForegroundColor Red
    Write-Host "   Merge conflicts detected. Please resolve manually:" -ForegroundColor Yellow
    Write-Host "   1. Resolve conflicts: git status" -ForegroundColor Gray
    Write-Host "   2. Complete merge: git commit" -ForegroundColor Gray
    Write-Host "   3. Push: git push origin release/qa" -ForegroundColor Gray
    Write-Host "   4. Re-run this script" -ForegroundColor Gray
    exit 1
}

Write-Host "[OK] Merge completed successfully" -ForegroundColor Green

# Step 6: Push merged branch
Write-Host "`n[INFO] Pushing merged release/qa branch..." -ForegroundColor Yellow
git push origin release/qa
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Push had issues, continuing with build anyway..." -ForegroundColor Yellow
}

# Step 7: Get commit info for release notes
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
    $releaseNotes = "QA Release Build - Ready for Testing!`n`n" +
                    "========================================`n`n" +
                    "BUILD INFO:`n" +
                    "   Branch: $branchName`n" +
                    "   Commit: $commitHash`n" +
                    "   Build #: $commitCount`n" +
                    "   Deployed: $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n" +
                    "   Source: Merged from develop branch`n`n" +
                    "LATEST CHANGES:`n" +
                    "   $commitMessage`n" +
                    "   By: $commitAuthor on $commitDate`n`n" +
                    "RECENT UPDATES:`n" +
                    "$recentCommits`n`n" +
                    "========================================`n`n" +
                    "TEST PLAN:`n" +
                    "   A comprehensive test plan is available in the repository:`n" +
                    "   - File: ANDROID_TEST_PLAN.md`n" +
                    "   - Location: Project root`n" +
                    "   - Coverage: 200+ test cases across 16 feature categories`n" +
                    "   - Please follow the test plan for systematic testing`n`n" +
                    "TESTING NOTES:`n" +
                    "   - This is a QA release build for thorough testing`n" +
                    "   - Please test all features thoroughly`n" +
                    "   - Report any issues you encounter`n" +
                    "   - Your feedback helps us improve!`n`n" +
                    "Thank you for testing!"
} else {
    $releaseNotes = $Notes
}

Write-Host "   Release notes:" -ForegroundColor Gray
$releaseNotes -split "`n" | Select-Object -First 5 | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }

# Step 8: Verify qa google-services.json exists
Write-Host "`n[INFO] Verifying QA configuration..." -ForegroundColor Yellow
$googleServicesPath = "android/app/src/qa/google-services.json"
if (-not (Test-Path $googleServicesPath)) {
    Write-Host "[ERROR] QA google-services.json not found at: $googleServicesPath" -ForegroundColor Red
    Write-Host "   Please set up QA flavor in Firebase Console first." -ForegroundColor Yellow
    exit 1
}

# Step 9: Get QA App ID from google-services.json
$json = Get-Content $googleServicesPath | ConvertFrom-Json

# Find the client entry with qa package name (com.example.familyhub_mvp.test)
$qaClient = $json.client | Where-Object { $_.client_info.android_client_info.package_name -eq "com.example.familyhub_mvp.test" }

if (-not $qaClient) {
    Write-Host "[ERROR] QA package name not found in google-services.json!" -ForegroundColor Red
    Write-Host "   Expected package: com.example.familyhub_mvp.test" -ForegroundColor Yellow
    Write-Host "   Available packages:" -ForegroundColor Yellow
    $json.client | ForEach-Object { Write-Host "     - $($_.client_info.android_client_info.package_name)" -ForegroundColor Gray }
    exit 1
}

$appId = $qaClient.client_info.mobilesdk_app_id
$packageName = $qaClient.client_info.android_client_info.package_name

Write-Host "[OK] QA configuration found" -ForegroundColor Green
Write-Host "   App ID: $appId" -ForegroundColor Gray
Write-Host "   Package: $packageName" -ForegroundColor Gray

# Verify package matches expected qa package
if ($packageName -ne "com.example.familyhub_mvp.test") {
    Write-Host "[ERROR] Package mismatch! Expected 'com.example.familyhub_mvp.test' but found '$packageName'" -ForegroundColor Red
    exit 1
}

# Step 10: Aggressive cleanup to prevent file locking issues
Write-Host "`n[INFO] Preparing build environment..." -ForegroundColor Yellow

# Kill any lingering Gradle/Java processes
Write-Host "   Killing any lingering Java/Gradle processes..." -ForegroundColor Gray
$javaProcesses = Get-Process -Name "java" -ErrorAction SilentlyContinue
$gradleProcesses = Get-Process -Name "gradle*" -ErrorAction SilentlyContinue

if ($javaProcesses -or $gradleProcesses) {
    Write-Host "   Found processes to kill: $($javaProcesses.Count + $gradleProcesses.Count)" -ForegroundColor Yellow
    $javaProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    $gradleProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Write-Host "   [OK] Processes terminated" -ForegroundColor Green
} else {
    Write-Host "   [OK] No lingering processes found" -ForegroundColor Green
}

# Clean Flutter build
Write-Host "   Cleaning Flutter build cache..." -ForegroundColor Gray
flutter clean 2>&1 | Out-Null
Start-Sleep -Seconds 2
Write-Host "[OK] Build environment ready" -ForegroundColor Green

# Step 11: Get dependencies
Write-Host "`n[INFO] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to get dependencies!" -ForegroundColor Red
    exit 1
}

# Step 12: Build QA APK with retry logic
Write-Host "`n[INFO] Building QA release APK..." -ForegroundColor Yellow
Write-Host "   This may take a few minutes..." -ForegroundColor Gray
Write-Host "   Build progress will be shown below...`n" -ForegroundColor Cyan

$maxRetries = 2
$retryCount = 0
$buildSuccess = $false

while ($retryCount -lt $maxRetries -and -not $buildSuccess) {
    if ($retryCount -gt 0) {
        Write-Host "`n[WARN] Previous build failed, retrying attempt $($retryCount + 1)/$maxRetries..." -ForegroundColor Yellow
        Write-Host "   Performing aggressive cleanup..." -ForegroundColor Gray
        
        Get-Process -Name "java","gradle*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 4
        
        flutter clean 2>&1 | Out-Null
        Start-Sleep -Seconds 2
    }
    
    Write-Host "`n   Starting build attempt $($retryCount + 1)...`n" -ForegroundColor Cyan
    flutter build apk --release --flavor qa --dart-define=FLAVOR=qa
    
    if ($LASTEXITCODE -eq 0) {
        $buildSuccess = $true
        Write-Host "`n[OK] Build completed successfully!" -ForegroundColor Green
    } else {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "`n[WARN] Build failed with exit code $LASTEXITCODE" -ForegroundColor Yellow
        }
    }
}

if (-not $buildSuccess) {
    Write-Host "`n[ERROR] Build failed after $maxRetries attempts!" -ForegroundColor Red
    Write-Host "`nTroubleshooting steps:" -ForegroundColor Yellow
    Write-Host "   1. Close any IDEs/editors that might have files open" -ForegroundColor Gray
    Write-Host "   2. Check if antivirus is scanning the build directory" -ForegroundColor Gray
    Write-Host "   3. Ensure you have enough disk space" -ForegroundColor Gray
    exit 1
}

# Step 13: Verify APK was created
$apkPath = "build\app\outputs\flutter-apk\app-qa-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Host "[ERROR] APK not found at: $apkPath" -ForegroundColor Red
    exit 1
}

$apkSize = (Get-Item $apkPath).Length / 1MB
Write-Host "[OK] APK built successfully!" -ForegroundColor Green
Write-Host "   Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Gray
Write-Host "   Location: $apkPath" -ForegroundColor Gray

# Step 14: Distribute to Firebase App Distribution
Write-Host "`n[INFO] Distributing to qa-testers group..." -ForegroundColor Yellow
Write-Host "   App ID: $appId" -ForegroundColor Gray
Write-Host "   Group: qa-testers" -ForegroundColor Gray
Write-Host ""

# Prepare release notes - replace newlines with spaces for command line
$releaseNotesSingleLine = $releaseNotes -replace "`r`n|`n|`r", " "

# Distribute to Firebase - output will stream directly to console
Write-Host "   Uploading APK (this may take a few minutes for 265MB)...`n" -ForegroundColor Cyan
firebase appdistribution:distribute $apkPath --app $appId --groups "qa-testers" --release-notes "$releaseNotesSingleLine"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[OK] Successfully deployed to qa-testers!" -ForegroundColor Green
    Write-Host "   Testers will receive an email with download link." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Release Summary:" -ForegroundColor Cyan
    Write-Host "   Branch: $branchName" -ForegroundColor Gray
    Write-Host "   Commit: $commitHash" -ForegroundColor Gray
    Write-Host "   APK: $apkPath" -ForegroundColor Gray
    Write-Host "   Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Gray
    Write-Host "   Group: qa-testers" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "[ERROR] Deployment failed!" -ForegroundColor Red
    Write-Host "   Exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Verify Firebase CLI is authenticated: firebase login" -ForegroundColor Gray
    Write-Host "   2. Check that 'qa-testers' group exists in Firebase Console" -ForegroundColor Gray
    Write-Host "   3. Verify App ID is correct: $appId" -ForegroundColor Gray
    Write-Host "   4. Check that QA flavor is registered in Firebase Console" -ForegroundColor Gray
    exit 1
}

Write-Host "[OK] QA release deployment complete!" -ForegroundColor Green
Write-Host "   Automation successful! QA testers will receive the build." -ForegroundColor Cyan

