# Launch Android Emulator Script
# Automatically detects and launches the best available emulator

param(
    [string]$EmulatorName = "",
    [switch]$ColdBoot = $false,
    [switch]$ListOnly = $false
)

$ErrorActionPreference = "Stop"

# Set Android SDK path
if (-not $env:ANDROID_HOME) {
    $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
}

$emulatorPath = Join-Path $env:ANDROID_HOME "emulator\emulator.exe"

if (-not (Test-Path $emulatorPath)) {
    Write-Host "[X] Android Emulator not found at: $emulatorPath" -ForegroundColor Red
    Write-Host "Please install Android Studio and set up an emulator" -ForegroundColor Yellow
    exit 1
}

# List available emulators
Write-Host "Available emulators:" -ForegroundColor Cyan
$emulators = flutter emulators 2>&1 | Where-Object { $_ -match "^\s+\w+" } | ForEach-Object {
    if ($_ -match "(\w+)\s+.*") {
        $matches[1]
    }
}

if ($ListOnly) {
    flutter emulators
    exit 0
}

# Select emulator
if ([string]::IsNullOrEmpty($EmulatorName)) {
    if ($emulators.Count -eq 0) {
        Write-Host "[X] No emulators found. Create one in Android Studio:" -ForegroundColor Red
        Write-Host "   Tools -> Device Manager -> Create Device" -ForegroundColor Yellow
        exit 1
    } elseif ($emulators.Count -eq 1) {
        $EmulatorName = $emulators[0]
        Write-Host "Using emulator: $EmulatorName" -ForegroundColor Green
    } else {
        Write-Host "Multiple emulators found. Please specify one:" -ForegroundColor Yellow
        flutter emulators
        Write-Host ""
        Write-Host 'Usage: .\launch_emulator.ps1 -EmulatorName <name>' -ForegroundColor Yellow
        exit 1
    }
}

# Check if emulator is already running
Write-Host "Checking if emulator is already running..." -ForegroundColor Cyan
$runningDevices = adb devices 2>&1 | Where-Object { $_ -match "emulator" }
if ($runningDevices) {
    Write-Host "[!] Emulator appears to be running already" -ForegroundColor Yellow
    Write-Host "Run 'flutter devices' to see connected devices" -ForegroundColor Gray
    $response = Read-Host "Launch anyway? (y/n)"
    if ($response -ne "y") {
        exit 0
    }
}

# Build emulator command
$emulatorArgs = @("-avd", $EmulatorName)

# Add performance optimizations
$emulatorArgs += @(
    "-gpu", "auto",           # Auto-detect best GPU acceleration
    "-no-snapshot-save"       # Don't save snapshots (faster startup)
)

if ($ColdBoot) {
    $emulatorArgs += "-no-snapshot-load"
    Write-Host "Starting with cold boot (no snapshot)..." -ForegroundColor Yellow
} else {
    Write-Host "Starting emulator: $EmulatorName" -ForegroundColor Cyan
}

# Launch emulator in background
Write-Host "Launching emulator (this may take 30-60 seconds)..." -ForegroundColor Yellow
Start-Process -FilePath $emulatorPath -ArgumentList $emulatorArgs -WindowStyle Normal

Write-Host ""
Write-Host "Waiting for emulator to boot..." -ForegroundColor Cyan

# Wait for emulator to be ready
$maxWait = 120  # 2 minutes
$waited = 0
$ready = $false

while ($waited -lt $maxWait -and -not $ready) {
    Start-Sleep -Seconds 2
    $waited += 2
    
    $devices = adb devices 2>&1 | Where-Object { $_ -match "emulator.*device" }
    if ($devices) {
        $ready = $true
        Write-Host "[OK] Emulator is ready!" -ForegroundColor Green
    } else {
        Write-Host "." -NoNewline -ForegroundColor Gray
    }
}

Write-Host ""

if ($ready) {
    Write-Host "Emulator is ready. You can now run:" -ForegroundColor Green
    Write-Host "   flutter run" -ForegroundColor Cyan
    Write-Host ""
    flutter devices
} else {
    Write-Host "[!] Emulator is taking longer than expected to boot" -ForegroundColor Yellow
    Write-Host "Check the emulator window. It may still be starting up." -ForegroundColor Gray
    Write-Host "Run 'flutter devices' to check when it's ready" -ForegroundColor Gray
}

