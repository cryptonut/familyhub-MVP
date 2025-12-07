# Fix local.properties with correct Flutter SDK and Android SDK paths

Write-Host "=== Fixing local.properties ===" -ForegroundColor Cyan
Write-Host ""

$localPropertiesPath = "android\local.properties"

# Find Flutter SDK path
Write-Host "Finding Flutter SDK..." -ForegroundColor Yellow
$flutterPath = $null

# Try to find Flutter from PATH
try {
    $flutterCmd = Get-Command flutter -ErrorAction Stop
    $flutterBin = $flutterCmd.Source
    $flutterPath = (Split-Path (Split-Path $flutterBin -Parent) -Parent)
    Write-Host "  Found Flutter at: $flutterPath" -ForegroundColor Green
} catch {
    Write-Host "  Flutter not in PATH, checking common locations..." -ForegroundColor Yellow
    
    $possiblePaths = @(
        "C:\src\flutter",
        "D:\src\flutter",
        "$env:USERPROFILE\flutter",
        "$env:LOCALAPPDATA\flutter"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path "$path\bin\flutter.bat") {
            $flutterPath = $path
            Write-Host "  Found Flutter at: $flutterPath" -ForegroundColor Green
            break
        }
    }
}

if (-not $flutterPath) {
    Write-Host "  [X] Could not find Flutter SDK!" -ForegroundColor Red
    Write-Host "  Please run 'flutter doctor' or set Flutter SDK path manually" -ForegroundColor Yellow
    exit 1
}

# Normalize path (use forward slashes or escaped backslashes)
$flutterPathNormalized = $flutterPath -replace '\\', '\\'

# Find Android SDK path
Write-Host ""
Write-Host "Finding Android SDK..." -ForegroundColor Yellow
$androidSdkPath = $null

if ($env:ANDROID_HOME) {
    $androidSdkPath = $env:ANDROID_HOME
    Write-Host "  Found from ANDROID_HOME: $androidSdkPath" -ForegroundColor Green
} elseif ($env:ANDROID_SDK_ROOT) {
    $androidSdkPath = $env:ANDROID_SDK_ROOT
    Write-Host "  Found from ANDROID_SDK_ROOT: $androidSdkPath" -ForegroundColor Green
} else {
    $defaultPath = "$env:LOCALAPPDATA\Android\Sdk"
    if (Test-Path $defaultPath) {
        $androidSdkPath = $defaultPath
        Write-Host "  Found at default location: $androidSdkPath" -ForegroundColor Green
    } else {
        Write-Host "  [X] Could not find Android SDK!" -ForegroundColor Red
        Write-Host "  Please set ANDROID_HOME environment variable" -ForegroundColor Yellow
        exit 1
    }
}

$androidSdkPathNormalized = $androidSdkPath -replace '\\', '\\'

# Read existing local.properties if it exists
$existingContent = ""
if (Test-Path $localPropertiesPath) {
    $existingContent = Get-Content $localPropertiesPath -Raw
    Write-Host ""
    Write-Host "Existing local.properties found, updating..." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Creating new local.properties..." -ForegroundColor Yellow
}

# Build new content
$newContent = @"
sdk.dir=$androidSdkPathNormalized
flutter.sdk=$flutterPathNormalized
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
"@

# Write new file
Set-Content -Path $localPropertiesPath -Value $newContent -NoNewline

Write-Host ""
Write-Host "=== Updated local.properties ===" -ForegroundColor Green
Write-Host ""
Write-Host "Flutter SDK: $flutterPath" -ForegroundColor Cyan
Write-Host "Android SDK: $androidSdkPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "[OK] local.properties updated successfully!" -ForegroundColor Green

