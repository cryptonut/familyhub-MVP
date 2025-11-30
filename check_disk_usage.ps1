# Check Disk Usage Script
Write-Host "=== Checking C: Drive Usage ===" -ForegroundColor Cyan

# Check Flutter/Dart caches
Write-Host "`n--- Flutter/Dart Caches ---" -ForegroundColor Yellow
$flutterPub = "$env:LOCALAPPDATA\Pub\Cache"
if (Test-Path $flutterPub) {
    $size = (Get-ChildItem $flutterPub -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "Flutter Pub Cache: $([math]::Round($size, 2)) GB" -ForegroundColor Green
} else {
    Write-Host "Flutter Pub Cache: Not found"
}

# Check Gradle cache
Write-Host "`n--- Gradle Cache ---" -ForegroundColor Yellow
$gradle = "$env:USERPROFILE\.gradle"
if (Test-Path $gradle) {
    $size = (Get-ChildItem $gradle -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "Gradle Cache: $([math]::Round($size, 2)) GB" -ForegroundColor Green
} else {
    Write-Host "Gradle Cache: Not found"
}

# Check Android SDK
Write-Host "`n--- Android SDK ---" -ForegroundColor Yellow
$android = "$env:LOCALAPPDATA\Android"
if (Test-Path $android) {
    $size = (Get-ChildItem $android -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "Android SDK: $([math]::Round($size, 2)) GB" -ForegroundColor Green
} else {
    Write-Host "Android SDK: Not found"
}

# Check Temp folders
Write-Host "`n--- Temp Folders ---" -ForegroundColor Yellow
$temp = $env:TEMP
if (Test-Path $temp) {
    $size = (Get-ChildItem $temp -File -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "User Temp: $([math]::Round($size, 2)) GB" -ForegroundColor Green
}

$winTemp = "$env:WINDIR\Temp"
if (Test-Path $winTemp) {
    $size = (Get-ChildItem $winTemp -File -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "Windows Temp: $([math]::Round($size, 2)) GB" -ForegroundColor Green
}

# Check large AppData folders
Write-Host "`n--- Large AppData Folders (>500 MB) ---" -ForegroundColor Yellow
Get-ChildItem "$env:LOCALAPPDATA" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    if ($size -gt 0.5) {
        Write-Host "$($_.Name): $([math]::Round($size, 2)) GB" -ForegroundColor Green
    }
} | Sort-Object -Descending

# Check C: root folders (excluding system folders)
Write-Host "`n--- C: Root Folders (excluding system) ---" -ForegroundColor Yellow
Get-ChildItem C:\ -Directory -ErrorAction SilentlyContinue | Where-Object { 
    $_.Name -notmatch '^(Windows|Program Files|Program Files \(x86\)|Users|PerfLogs|Recovery|MSI|inetpub)$' 
} | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "$($_.Name): $([math]::Round($size, 2)) GB" -ForegroundColor Green
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan

