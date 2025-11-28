# PowerShell Script: Build and Distribute APK for Testing
# Usage: .\build_and_distribute.ps1 [method]
# Methods: firebase, manual, adb

param(
    [Parameter(Position=0)]
    [ValidateSet("firebase", "manual", "adb")]
    [string]$Method = "manual"
)

Write-Host "🚀 Building APK for wireless testing..." -ForegroundColor Cyan

# Build the APK
Write-Host "`n📦 Building release APK..." -ForegroundColor Yellow
flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"

if (-not (Test-Path $apkPath)) {
    Write-Host "❌ APK not found at: $apkPath" -ForegroundColor Red
    exit 1
}

$apkSize = (Get-Item $apkPath).Length / 1MB
Write-Host "✅ APK built successfully! ($([math]::Round($apkSize, 2)) MB)" -ForegroundColor Green
Write-Host "   Location: $apkPath" -ForegroundColor Gray

switch ($Method) {
    "firebase" {
        Write-Host "`n🔥 Distributing via Firebase App Distribution..." -ForegroundColor Yellow
        
        # Get app ID from google-services.json
        $googleServicesPath = "android\app\google-services.json"
        if (Test-Path $googleServicesPath) {
            $json = Get-Content $googleServicesPath | ConvertFrom-Json
            $appId = $json.client[0].client_info.mobilesdk_app_id
            Write-Host "   App ID: $appId" -ForegroundColor Gray
        } else {
            Write-Host "⚠️  google-services.json not found. Please provide App ID manually." -ForegroundColor Yellow
            $appId = Read-Host "Enter your Firebase App ID"
        }
        
        $releaseNotes = "Test build - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        
        Write-Host "`n📤 Uploading to Firebase..." -ForegroundColor Yellow
        firebase appdistribution:distribute $apkPath `
            --app $appId `
            --groups "testers" `
            --release-notes $releaseNotes
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✅ Successfully distributed via Firebase App Distribution!" -ForegroundColor Green
            Write-Host "   Testers will receive an email with download link." -ForegroundColor Gray
        } else {
            Write-Host "`n❌ Firebase distribution failed!" -ForegroundColor Red
            Write-Host "   Make sure you're logged in: firebase login" -ForegroundColor Yellow
        }
    }
    
    "manual" {
        Write-Host "`n📤 Manual Distribution Instructions:" -ForegroundColor Yellow
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
        Write-Host "`n📱 Setting up ADB over WiFi..." -ForegroundColor Yellow
        Write-Host "   Make sure your phone is connected via USB first!" -ForegroundColor Yellow
        
        # Check if device is connected
        $devices = adb devices
        if ($devices -match "device$") {
            Write-Host "✅ Device detected via USB" -ForegroundColor Green
            
            Write-Host "`n📡 Enabling TCP/IP mode..." -ForegroundColor Yellow
            adb tcpip 5555
            
            Write-Host "`nPlease find your phone's IP address:" -ForegroundColor Yellow
            Write-Host "   Settings → About phone → Status → IP address" -ForegroundColor Gray
            $phoneIP = Read-Host "`nEnter your phone's IP address"
            
            Write-Host "`n🔌 Connecting wirelessly..." -ForegroundColor Yellow
            adb connect "$phoneIP:5555"
            
            Write-Host "`n✅ Setup complete! You can now disconnect USB." -ForegroundColor Green
            Write-Host "   Run: flutter run --release" -ForegroundColor Gray
        } else {
            Write-Host "❌ No device detected via USB!" -ForegroundColor Red
            Write-Host "   Please connect your phone via USB first." -ForegroundColor Yellow
        }
    }
}

Write-Host "`n✨ Done!" -ForegroundColor Cyan

