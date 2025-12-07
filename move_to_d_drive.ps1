# Automated script to move large files from C: to D: drive
# This script moves safe-to-move items and creates symbolic links

param(
    [switch]$DryRun = $false,
    [switch]$SkipAndroid = $false,
    [switch]$SkipDocuments = $true
)

$ErrorActionPreference = "Stop"

Write-Host "=== Moving Files from C: to D: Drive ===" -ForegroundColor Cyan
Write-Host "Dry Run Mode: $DryRun" -ForegroundColor Yellow
Write-Host ""

# Check D: drive exists
if (-not (Test-Path "D:\")) {
    Write-Host "ERROR: D: drive not found!" -ForegroundColor Red
    exit 1
}

$dDrive = Get-PSDrive D -ErrorAction SilentlyContinue
if ($dDrive) {
    $dFreeGB = [math]::Round($dDrive.Free / 1GB, 2)
    Write-Host "D: Drive has $dFreeGB GB free" -ForegroundColor Green
} else {
    Write-Host "WARNING: Cannot read D: drive stats" -ForegroundColor Yellow
}

# Create base directory on D:
$devBase = "D:\Development"
if (-not $DryRun) {
    New-Item -ItemType Directory -Path $devBase -Force | Out-Null
    Write-Host "Created $devBase" -ForegroundColor Green
} else {
    Write-Host "[DRY RUN] Would create $devBase" -ForegroundColor Gray
}

# Function to move and create symlink
function Move-WithSymlink {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$Name
    )
    
    if (-not (Test-Path $SourcePath)) {
        Write-Host "  $Name not found at $SourcePath" -ForegroundColor Yellow
        return $false
    }
    
    # Check size
    $size = (Get-ChildItem $SourcePath -Recurse -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
    $sizeGB = [math]::Round($size, 2)
    
    if ($sizeGB -lt 0.1) {
        Write-Host "  $Name is too small ($sizeGB GB) - skipping" -ForegroundColor Gray
        return $false
    }
    
    Write-Host "  $Name : $sizeGB GB" -ForegroundColor Cyan
    
    if ($DryRun) {
        Write-Host "    [DRY RUN] Would move to $DestPath" -ForegroundColor Gray
        Write-Host "    [DRY RUN] Would create symlink: $SourcePath -> $DestPath" -ForegroundColor Gray
        return $true
    }
    
    try {
        # Create parent directory
        $parent = Split-Path $DestPath -Parent
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        
        # Move the directory
        Write-Host "    Moving..." -ForegroundColor Yellow
        Move-Item $SourcePath $DestPath -Force
        
        # Create symbolic link
        Write-Host "    Creating symbolic link..." -ForegroundColor Yellow
        New-Item -ItemType SymbolicLink -Path $SourcePath -Target $DestPath | Out-Null
        
        Write-Host "    ✓ Successfully moved $Name" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "    ✗ Error moving $Name : $_" -ForegroundColor Red
        return $false
    }
}

# 1. Move Gradle Cache
Write-Host "`n1. Gradle Cache" -ForegroundColor Cyan
Move-WithSymlink -SourcePath "$env:USERPROFILE\.gradle" `
                 -DestPath "$devBase\.gradle" `
                 -Name "Gradle Cache"

# 2. Move Flutter Pub Cache
Write-Host "`n2. Flutter Pub Cache" -ForegroundColor Cyan
Move-WithSymlink -SourcePath "$env:LOCALAPPDATA\Pub\Cache" `
                 -DestPath "$devBase\Pub\Cache" `
                 -Name "Flutter Pub Cache"

# 3. Move Android SDK (if not skipped)
if (-not $SkipAndroid) {
    Write-Host "`n3. Android SDK" -ForegroundColor Cyan
    $androidSdk = "$env:LOCALAPPDATA\Android\Sdk"
    if (Test-Path $androidSdk) {
        Move-WithSymlink -SourcePath $androidSdk `
                         -DestPath "$devBase\Android\Sdk" `
                         -Name "Android SDK"
        
        Write-Host "  ⚠ IMPORTANT: Update ANDROID_HOME environment variable:" -ForegroundColor Yellow
        Write-Host "    Old: $androidSdk" -ForegroundColor Gray
        Write-Host "    New: $devBase\Android\Sdk" -ForegroundColor Gray
    } else {
        Write-Host "  Android SDK not found" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n3. Android SDK - SKIPPED" -ForegroundColor Yellow
}

# 4. Clean temp files
Write-Host "`n4. Cleaning Temp Files" -ForegroundColor Cyan
$tempDirs = @(
    "$env:LOCALAPPDATA\Temp",
    "$env:TEMP"
)

foreach ($tempDir in $tempDirs) {
    if (Test-Path $tempDir) {
        $size = (Get-ChildItem $tempDir -Recurse -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
        $sizeGB = [math]::Round($size, 2)
        
        if ($sizeGB -gt 0.1) {
            Write-Host "  Temp files: $sizeGB GB" -ForegroundColor Cyan
            if (-not $DryRun) {
                try {
                    Remove-Item "$tempDir\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "  ✓ Cleaned temp files" -ForegroundColor Green
                } catch {
                    Write-Host "  ✗ Error cleaning: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "  [DRY RUN] Would clean $tempDir" -ForegroundColor Gray
            }
        }
    }
}

# 5. Move Downloads (optional)
Write-Host "`n5. Downloads Folder" -ForegroundColor Cyan
$downloadsPath = "C:\Users\simon\Downloads"
if (Test-Path $downloadsPath) {
    $size = (Get-ChildItem $downloadsPath -Recurse -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
    $sizeGB = [math]::Round($size, 2)
    
    if ($sizeGB -gt 0.1) {
        Write-Host "  Downloads: $sizeGB GB" -ForegroundColor Cyan
        Write-Host "  Move manually or run: Move-Item '$downloadsPath' 'D:\Downloads' -Force" -ForegroundColor Yellow
    }
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$cDrive = Get-PSDrive C
$freeGB = [math]::Round($cDrive.Free / 1GB, 2)
Write-Host "C: Drive now has $freeGB GB free" -ForegroundColor $(if ($freeGB -gt 5) { "Green" } else { "Yellow" })

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Test Flutter: flutter doctor" -ForegroundColor Yellow
Write-Host "2. Test Android build: cd android && .\gradlew --version" -ForegroundColor Yellow
Write-Host "3. If Android SDK was moved, update ANDROID_HOME environment variable" -ForegroundColor Yellow
Write-Host "4. Rebuild your project: flutter clean && flutter pub get" -ForegroundColor Yellow
