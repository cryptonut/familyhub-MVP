# USB Device Connection Diagnostic Script
# Checks if your Android phone is connected and ready for Flutter development

Write-Host "=== USB Device Diagnostics ===" -ForegroundColor Cyan
Write-Host ""

# Check if ADB is available
Write-Host "1. Checking ADB..." -ForegroundColor Yellow
$adbPath = $null

# Try to find ADB
$possiblePaths = @(
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "adb.exe"  # If in PATH
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $adbPath = $path
        break
    }
}

if ($null -eq $adbPath) {
    # Try if adb is in PATH
    try {
        $adbCheck = Get-Command adb -ErrorAction Stop
        $adbPath = $adbCheck.Source
    } catch {
        Write-Host "   [X] ADB not found" -ForegroundColor Red
        Write-Host "   Install Android Studio or Android SDK Platform Tools" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   Download Platform Tools:" -ForegroundColor Yellow
        Write-Host "   https://developer.android.com/studio/releases/platform-tools" -ForegroundColor Gray
        exit 1
    }
}

Write-Host "   [OK] ADB found: $adbPath" -ForegroundColor Green
Write-Host ""

# Check ADB server
Write-Host "2. Starting ADB Server..." -ForegroundColor Yellow
try {
    & $adbPath start-server 2>&1 | Out-Null
    Write-Host "   [OK] ADB server started" -ForegroundColor Green
} catch {
    Write-Host "   [!] Could not start ADB server" -ForegroundColor Yellow
}
Write-Host ""

# Check connected devices
Write-Host "3. Checking Connected Devices..." -ForegroundColor Yellow
try {
    $devicesOutput = & $adbPath devices 2>&1
    $deviceLines = $devicesOutput | Where-Object { $_ -match "\t" }
    
    if ($deviceLines.Count -eq 0) {
        Write-Host "   [X] No devices found" -ForegroundColor Red
        Write-Host ""
        Write-Host "   Troubleshooting:" -ForegroundColor Yellow
        Write-Host "   1. Make sure your phone is connected via USB" -ForegroundColor Gray
        Write-Host "   2. Enable USB Debugging on your phone:" -ForegroundColor Gray
        Write-Host "      Settings -> Developer Options -> USB Debugging" -ForegroundColor Gray
        Write-Host "   3. Check your phone for 'Allow USB debugging?' popup" -ForegroundColor Gray
        Write-Host "   4. Try a different USB cable or port" -ForegroundColor Gray
    } else {
        Write-Host "   [OK] Found $($deviceLines.Count) device(s):" -ForegroundColor Green
        Write-Host ""
        
        foreach ($line in $deviceLines) {
            $parts = $line -split "\t"
            $deviceId = $parts[0]
            $status = $parts[1]
            
            if ($status -eq "device") {
                Write-Host "   [OK] $deviceId - Ready" -ForegroundColor Green
            } elseif ($status -eq "unauthorized") {
                Write-Host "   [!] $deviceId - Unauthorized" -ForegroundColor Yellow
                Write-Host "      Check your phone for 'Allow USB debugging?' popup" -ForegroundColor Gray
            } elseif ($status -eq "offline") {
                Write-Host "   [!] $deviceId - Offline" -ForegroundColor Yellow
                Write-Host "      Try disconnecting and reconnecting the USB cable" -ForegroundColor Gray
            } else {
                Write-Host "   [?] $deviceId - $status" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host ""
    Write-Host "   Full ADB output:" -ForegroundColor Gray
    $devicesOutput | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }
} catch {
    Write-Host "   [X] Error checking devices: $_" -ForegroundColor Red
}
Write-Host ""

# Check Flutter
Write-Host "4. Checking Flutter..." -ForegroundColor Yellow
try {
    $flutterDevices = flutter devices 2>&1
    $androidDevices = $flutterDevices | Where-Object { $_ -match "android" -or $_ -match "•" }
    
    if ($androidDevices.Count -gt 0) {
        Write-Host "   [OK] Flutter detected device(s):" -ForegroundColor Green
        $flutterDevices | ForEach-Object {
            if ($_ -match "•" -or $_ -match "android") {
                Write-Host "   $_" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "   [!] Flutter did not detect any devices" -ForegroundColor Yellow
        Write-Host "   Make sure ADB sees your device first (see step 3)" -ForegroundColor Gray
    }
} catch {
    Write-Host "   [!] Could not check Flutter devices" -ForegroundColor Yellow
    Write-Host "   Make sure Flutter is installed and in PATH" -ForegroundColor Gray
}
Write-Host ""

# Recommendations
Write-Host "=== Recommendations ===" -ForegroundColor Cyan

$devicesOutput = & $adbPath devices 2>&1
$readyDevices = $devicesOutput | Where-Object { $_ -match "\tdevice$" }

if ($readyDevices.Count -gt 0) {
    Write-Host "[OK] Your device is ready!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To run your app:" -ForegroundColor Yellow
    Write-Host "   flutter run" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Or specify your device:" -ForegroundColor Yellow
    $deviceId = ($readyDevices[0] -split "\t")[0]
    Write-Host "   flutter run -d $deviceId" -ForegroundColor Gray
} else {
    Write-Host "1. Enable USB Debugging on your phone:" -ForegroundColor Yellow
    Write-Host "   Settings -> Developer Options -> USB Debugging" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Connect your phone via USB" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "3. Allow USB debugging when prompted on your phone" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "4. Run this script again to verify:" -ForegroundColor Yellow
    Write-Host "   .\check_usb_device.ps1" -ForegroundColor Gray
}

Write-Host ""

