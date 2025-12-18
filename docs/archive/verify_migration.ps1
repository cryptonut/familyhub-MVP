# Verification script to check migration results
Write-Host "=== Migration Verification ===" -ForegroundColor Cyan

# Check C: drive space
$cDrive = Get-PSDrive C
$freeGB = [math]::Round($cDrive.Free / 1GB, 2)
$usedGB = [math]::Round($cDrive.Used / 1GB, 2)
Write-Host "`nC: Drive Status:" -ForegroundColor Yellow
Write-Host "  Free: $freeGB GB" -ForegroundColor $(if ($freeGB -gt 5) { "Green" } elseif ($freeGB -gt 1) { "Yellow" } else { "Red" })
Write-Host "  Used: $usedGB GB"

# Check D: drive space
if (Test-Path "D:\") {
    $dDrive = Get-PSDrive D
    $dFreeGB = [math]::Round($dDrive.Free / 1GB, 2)
    Write-Host "`nD: Drive Status:" -ForegroundColor Yellow
    Write-Host "  Free: $dFreeGB GB" -ForegroundColor Green
}

# Check Gradle
Write-Host "`n1. Gradle Cache:" -ForegroundColor Cyan
if (Test-Path "$env:USERPROFILE\.gradle") {
    $item = Get-Item "$env:USERPROFILE\.gradle" -ErrorAction SilentlyContinue
    if ($item.LinkType -eq "SymbolicLink") {
        Write-Host "  ✓ Symbolic link created" -ForegroundColor Green
        Write-Host "  Target: $($item.Target)" -ForegroundColor Gray
        if (Test-Path "D:\Development\.gradle") {
            Write-Host "  ✓ Files exist on D: drive" -ForegroundColor Green
        }
    } else {
        Write-Host "  Still on C: drive" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Not found" -ForegroundColor Yellow
}

# Check Pub Cache
Write-Host "`n2. Flutter Pub Cache:" -ForegroundColor Cyan
if (Test-Path "$env:LOCALAPPDATA\Pub\Cache") {
    $item = Get-Item "$env:LOCALAPPDATA\Pub\Cache" -ErrorAction SilentlyContinue
    if ($item.LinkType -eq "SymbolicLink") {
        Write-Host "  ✓ Symbolic link created" -ForegroundColor Green
        Write-Host "  Target: $($item.Target)" -ForegroundColor Gray
        if (Test-Path "D:\Development\Pub\Cache") {
            Write-Host "  ✓ Files exist on D: drive" -ForegroundColor Green
        }
    } else {
        Write-Host "  Still on C: drive" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Not found" -ForegroundColor Yellow
}

# Check Android SDK
Write-Host "`n3. Android SDK:" -ForegroundColor Cyan
if (Test-Path "$env:LOCALAPPDATA\Android\Sdk") {
    $item = Get-Item "$env:LOCALAPPDATA\Android\Sdk" -ErrorAction SilentlyContinue
    if ($item.LinkType -eq "SymbolicLink") {
        Write-Host "  ✓ Symbolic link created" -ForegroundColor Green
        Write-Host "  Target: $($item.Target)" -ForegroundColor Gray
        if (Test-Path "D:\Development\Android\Sdk") {
            Write-Host "  ✓ Files exist on D: drive" -ForegroundColor Green
            Write-Host "  ⚠ Update ANDROID_HOME environment variable!" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Still on C: drive" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Not found" -ForegroundColor Yellow
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($freeGB -gt 5) {
    Write-Host "✓ SUCCESS: C: drive has enough space now!" -ForegroundColor Green
} elseif ($freeGB -gt 1) {
    Write-Host "⚠ WARNING: C: drive still low on space" -ForegroundColor Yellow
} else {
    Write-Host "✗ CRITICAL: C: drive still critically low!" -ForegroundColor Red
}
