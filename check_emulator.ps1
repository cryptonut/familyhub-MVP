# Android Emulator Diagnostic Script
# Checks virtualization status, emulator availability, and provides recommendations

Write-Host "=== Android Emulator Diagnostics ===" -ForegroundColor Cyan
Write-Host ""

# Check virtualization status
Write-Host "1. Checking Virtualization Status..." -ForegroundColor Yellow
$virtStatus = $null
try {
    $virtStatus = Get-ComputerInfo | Select-Object -Property HyperVRequirementVirtualizationFirmwareEnabled
    if ($virtStatus.HyperVRequirementVirtualizationFirmwareEnabled) {
        Write-Host "   [OK] Virtualization is ENABLED in BIOS" -ForegroundColor Green
    } else {
        Write-Host "   [X] Virtualization is DISABLED in BIOS" -ForegroundColor Red
        Write-Host "   [!] You MUST enable VT-x in BIOS for x86_64 emulators to work" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [!] Could not check virtualization status" -ForegroundColor Yellow
}

Write-Host ""

# Check Android SDK path
Write-Host "2. Checking Android SDK..." -ForegroundColor Yellow
$androidHome = $env:ANDROID_HOME
if (-not $androidHome) {
    $androidHome = "$env:LOCALAPPDATA\Android\Sdk"
    Write-Host "   Using default: $androidHome" -ForegroundColor Gray
}

if (Test-Path $androidHome) {
    Write-Host "   [OK] Android SDK found: $androidHome" -ForegroundColor Green
    
    # Check emulator
    $emulatorPath = Join-Path $androidHome "emulator\emulator.exe"
    if (Test-Path $emulatorPath) {
        Write-Host "   [OK] Android Emulator found" -ForegroundColor Green
        
        # Check acceleration
        Write-Host ""
        Write-Host "3. Checking Emulator Acceleration..." -ForegroundColor Yellow
        & $emulatorPath -accel-check | ForEach-Object {
            Write-Host "   $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "   [X] Android Emulator not found" -ForegroundColor Red
    }
} else {
    Write-Host "   [X] Android SDK not found at: $androidHome" -ForegroundColor Red
    Write-Host "   Set ANDROID_HOME environment variable or install Android Studio" -ForegroundColor Yellow
}

Write-Host ""

# Check Flutter
Write-Host "4. Checking Flutter..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    if ($flutterVersion -match "Flutter") {
        Write-Host "   [OK] Flutter is installed" -ForegroundColor Green
    }
} catch {
    Write-Host "   [X] Flutter not found in PATH" -ForegroundColor Red
}

Write-Host ""

# List available emulators
Write-Host "5. Available Emulators..." -ForegroundColor Yellow
try {
    flutter emulators 2>&1 | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }
} catch {
    Write-Host "   [!] Could not list emulators" -ForegroundColor Yellow
}

Write-Host ""

# Check running devices
Write-Host "6. Connected Devices..." -ForegroundColor Yellow
try {
    $devices = flutter devices 2>&1
    if ($devices -match "emulator") {
        Write-Host "   [OK] Emulator is running" -ForegroundColor Green
    } else {
        Write-Host "   [i] No emulators currently running" -ForegroundColor Gray
    }
    $devices | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }
} catch {
    Write-Host "   [!] Could not check devices" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Recommendations ===" -ForegroundColor Cyan

if ($null -eq $virtStatus -or -not $virtStatus.HyperVRequirementVirtualizationFirmwareEnabled) {
    Write-Host "1. ENABLE VIRTUALIZATION IN BIOS (Required for x86_64 emulators)" -ForegroundColor Red
    Write-Host "   - Restart computer and press F2/F10/Del during boot" -ForegroundColor Yellow
    Write-Host "   - Enable 'Intel Virtualization Technology (VT-x)' or 'AMD-V'" -ForegroundColor Yellow
    Write-Host "   - Save and restart" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "2. Alternative: Use a physical Android device via USB" -ForegroundColor Yellow
    Write-Host "   - Enable USB Debugging on your phone" -ForegroundColor Yellow
    Write-Host "   - Connect via USB and run: flutter devices" -ForegroundColor Yellow
} else {
    Write-Host "[OK] Virtualization is enabled. Emulators should work!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To launch an emulator:" -ForegroundColor Yellow
    Write-Host '   flutter emulators --launch <emulator_id>' -ForegroundColor Gray
    Write-Host ""
    Write-Host "To run your app:" -ForegroundColor Yellow
    Write-Host "   flutter run" -ForegroundColor Gray
}

Write-Host ""
