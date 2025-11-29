# PowerShell Script: Build and Distribute APK for Testing
# Usage: .\build_and_distribute.ps1 [flavor] [method]
# Flavors: dev, qa, prod (default: prod)
# Methods: firebase, firebase-manual, manual, adb

param(
    [Parameter(Position=0)]
    [ValidateSet("dev", "qa", "prod")]
    [string]$Flavor = "prod",
    [Parameter(Position=1)]
    [ValidateSet("firebase", "firebase-manual", "manual", "adb")]
    [string]$Method = "firebase-manual"
)

Write-Host "Building APK for wireless testing..." -ForegroundColor Cyan
Write-Host "Environment: $Flavor" -ForegroundColor Cyan

# Build the APK with flavor
Write-Host "`nBuilding release APK ($Flavor)..." -ForegroundColor Yellow
flutter build apk --release --flavor $Flavor --dart-define=FLAVOR=$Flavor

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

$apkPath = "build\app\outputs\flutter-apk\app-$Flavor-release.apk"

if (-not (Test-Path $apkPath)) {
    Write-Host "APK not found at: $apkPath" -ForegroundColor Red
    exit 1
}

$apkSize = (Get-Item $apkPath).Length / 1MB
Write-Host "APK built successfully! ($([math]::Round($apkSize, 2)) MB)" -ForegroundColor Green
Write-Host "   Location: $apkPath" -ForegroundColor Gray

switch ($Method) {
    "firebase" {
        Write-Host "`nDistributing via Firebase App Distribution (CLI)..." -ForegroundColor Yellow
        
        # Check if Firebase CLI is available
        $firebaseCmd = Get-Command firebase -ErrorAction SilentlyContinue
        if (-not $firebaseCmd) {
            Write-Host "Firebase CLI not found!" -ForegroundColor Red
            Write-Host "   Install it with: npm install -g firebase-tools" -ForegroundColor Yellow
            Write-Host "   Or use 'firebase-manual' method for web upload" -ForegroundColor Yellow
            exit 1
        }
        
        # Get app ID from flavor-specific google-services.json
        $googleServicesPath = "android\app\src\$Flavor\google-services.json"
        if (-not (Test-Path $googleServicesPath)) {
            # Fallback to root if flavor-specific doesn't exist
            $googleServicesPath = "android\app\google-services.json"
        }
        
        if (Test-Path $googleServicesPath) {
            $json = Get-Content $googleServicesPath | ConvertFrom-Json
            $appId = $json.client[0].client_info.mobilesdk_app_id
            Write-Host "   App ID: $appId" -ForegroundColor Gray
        } else {
            Write-Host "WARNING: google-services.json not found for $Flavor flavor." -ForegroundColor Yellow
            Write-Host "   Please set up Firebase for $Flavor environment first." -ForegroundColor Yellow
            $appId = Read-Host "Enter your Firebase App ID (or press Enter to skip)"
            if ([string]::IsNullOrEmpty($appId)) {
                Write-Host "Skipping Firebase distribution. APK built at: $apkPath" -ForegroundColor Yellow
                exit 0
            }
        }
        
        $releaseNotes = "Test build - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        
        Write-Host "`nUploading to Firebase..." -ForegroundColor Yellow
        $testerGroup = "$Flavor-testers"
        firebase appdistribution:distribute $apkPath `
            --app $appId `
            --groups $testerGroup `
            --release-notes $releaseNotes
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nSuccessfully distributed via Firebase App Distribution!" -ForegroundColor Green
            Write-Host "   Testers will receive an email with download link." -ForegroundColor Gray
        } else {
            Write-Host "`nFirebase distribution failed!" -ForegroundColor Red
            Write-Host "   Make sure you're logged in: firebase login" -ForegroundColor Yellow
        }
    }
    
    "firebase-manual" {
        Write-Host "`n=== Firebase App Distribution - Manual Upload ===" -ForegroundColor Cyan
        
        # Get app ID from flavor-specific google-services.json
        $googleServicesPath = "android\app\src\$Flavor\google-services.json"
        if (-not (Test-Path $googleServicesPath)) {
            # Fallback to root if flavor-specific doesn't exist
            $googleServicesPath = "android\app\google-services.json"
        }
        
        $appId = ""
        if (Test-Path $googleServicesPath) {
            $json = Get-Content $googleServicesPath | ConvertFrom-Json
            $appId = $json.client[0].client_info.mobilesdk_app_id
            Write-Host "`nApp ID: $appId" -ForegroundColor Green
        } else {
            Write-Host "`nWARNING: google-services.json not found for $Flavor flavor." -ForegroundColor Yellow
            Write-Host "   Please set up Firebase for $Flavor environment first." -ForegroundColor Yellow
        }
        
        Write-Host "`nStep-by-step instructions:" -ForegroundColor Yellow
        Write-Host "   1. Go to: https://console.firebase.google.com/" -ForegroundColor White
        Write-Host "   2. Select your project" -ForegroundColor White
        Write-Host "   3. Click 'App Distribution' in the left menu" -ForegroundColor White
        Write-Host "   4. Click 'Upload release' button" -ForegroundColor White
        Write-Host "   5. Select your APK file:" -ForegroundColor White
        Write-Host "      $apkPath" -ForegroundColor Gray
        Write-Host "   6. Add release notes (optional):" -ForegroundColor White
        Write-Host "      Test build - $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
        Write-Host "   7. Select tester groups (e.g., '$Flavor-testers')" -ForegroundColor White
        Write-Host "   8. Click 'Distribute' button" -ForegroundColor White
        Write-Host "`n   Testers will receive an email with download link!" -ForegroundColor Green
        
        # Open APK location and Firebase Console
        Write-Host "`nOpening APK location in Explorer..." -ForegroundColor Yellow
        Start-Sleep -Seconds 1
        explorer.exe /select,$apkPath
        
        Write-Host "`nWould you like to open Firebase Console? (Y/N)" -ForegroundColor Yellow
        $openConsole = Read-Host
        if ($openConsole -eq "Y" -or $openConsole -eq "y") {
            Start-Process "https://console.firebase.google.com/project/_/appdistribution"
        }
    }
    
    "manual" {
        Write-Host "`nManual Distribution Instructions:" -ForegroundColor Yellow
        Write-Host "   1. Share this APK file: $apkPath" -ForegroundColor White
        Write-Host "   2. Methods to share:" -ForegroundColor White
        Write-Host "      - Email (attach the APK)" -ForegroundColor Gray
        Write-Host "      - Google Drive / Dropbox / OneDrive" -ForegroundColor Gray
        Write-Host "      - QR Code (upload to file sharing service)" -ForegroundColor Gray
        Write-Host "`n   3. Testers need to:" -ForegroundColor White
        Write-Host "      - Download the APK" -ForegroundColor Gray
        Write-Host "      - Allow 'Install from unknown sources'" -ForegroundColor Gray
        Write-Host "      - Tap the APK to install" -ForegroundColor Gray
        
        # Open file location
        $openFolder = Read-Host "`nOpen APK folder in Explorer? (Y/N)"
        if ($openFolder -eq "Y" -or $openFolder -eq "y") {
            explorer.exe /select,$apkPath
        }
    }
    
    "adb" {
        Write-Host "`nSetting up ADB over WiFi..." -ForegroundColor Yellow
        Write-Host "   Make sure your phone is connected via USB first!" -ForegroundColor Yellow
        
        # Check if device is connected
        $devices = adb devices
        if ($devices -match "device$") {
            Write-Host "Device detected via USB" -ForegroundColor Green
            
            Write-Host "`nEnabling TCP/IP mode..." -ForegroundColor Yellow
            adb tcpip 5555
            
            Write-Host "`nPlease find your phone's IP address:" -ForegroundColor Yellow
            Write-Host "   Settings -> About phone -> Status -> IP address" -ForegroundColor Gray
            $phoneIP = Read-Host "`nEnter your phone's IP address"
            
            Write-Host "`nConnecting wirelessly..." -ForegroundColor Yellow
            adb connect "$phoneIP:5555"
            
            Write-Host "`nSetup complete! You can now disconnect USB." -ForegroundColor Green
            Write-Host "   Run: flutter run --release" -ForegroundColor Gray
        } else {
            Write-Host "No device detected via USB!" -ForegroundColor Red
            Write-Host "   Please connect your phone via USB first." -ForegroundColor Yellow
        }
    }
}

Write-Host "`nDone!" -ForegroundColor Cyan
