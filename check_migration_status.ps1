# Quick status check for migration
Write-Host "=== Migration Status Check ===" -ForegroundColor Cyan
Write-Host ""

# C: Drive Space
$c = Get-PSDrive C
$freeGB = [math]::Round($c.Free / 1GB, 2)
$color = if ($freeGB -gt 5) { "Green" } elseif ($freeGB -gt 1) { "Yellow" } else { "Red" }
Write-Host "C: Drive Free Space: " -NoNewline
Write-Host "$freeGB GB" -ForegroundColor $color
Write-Host ""

# D: Drive Space
if (Test-Path "D:\") {
    $d = Get-PSDrive D
    $dFreeGB = [math]::Round($d.Free / 1GB, 2)
    Write-Host "D: Drive Free Space: $dFreeGB GB" -ForegroundColor Green
    Write-Host ""
}

# Check Gradle
Write-Host "Gradle Cache:" -ForegroundColor Cyan
if (Test-Path "$env:USERPROFILE\.gradle") {
    $item = Get-Item "$env:USERPROFILE\.gradle" -ErrorAction SilentlyContinue
    if ($item.LinkType -eq "SymbolicLink") {
        Write-Host "  ✓ Symbolic link exists" -ForegroundColor Green
        Write-Host "  Target: $($item.Target)" -ForegroundColor Gray
    } else {
        Write-Host "  ⚠ Still on C: drive (not moved)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✗ Not found" -ForegroundColor Red
}

# Check Pub Cache
Write-Host "`nFlutter Pub Cache:" -ForegroundColor Cyan
if (Test-Path "$env:LOCALAPPDATA\Pub\Cache") {
    $item = Get-Item "$env:LOCALAPPDATA\Pub\Cache" -ErrorAction SilentlyContinue
    if ($item.LinkType -eq "SymbolicLink") {
        Write-Host "  ✓ Symbolic link exists" -ForegroundColor Green
        Write-Host "  Target: $($item.Target)" -ForegroundColor Gray
    } else {
        Write-Host "  ⚠ Still on C: drive (not moved)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✗ Not found" -ForegroundColor Red
}

# Check Android SDK
Write-Host "`nAndroid SDK:" -ForegroundColor Cyan
if (Test-Path "$env:LOCALAPPDATA\Android\Sdk") {
    $item = Get-Item "$env:LOCALAPPDATA\Android\Sdk" -ErrorAction SilentlyContinue
    if ($item.LinkType -eq "SymbolicLink") {
        Write-Host "  ✓ Symbolic link exists" -ForegroundColor Green
        Write-Host "  Target: $($item.Target)" -ForegroundColor Gray
        Write-Host "  ⚠ IMPORTANT: Update ANDROID_HOME environment variable!" -ForegroundColor Yellow
    } else {
        Write-Host "  ⚠ Still on C: drive (not moved)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✗ Not found" -ForegroundColor Red
}

# Check D: drive files
Write-Host "`nFiles on D: Drive:" -ForegroundColor Cyan
$dItems = @(
    @{Name="Gradle"; Path="D:\Development\.gradle"},
    @{Name="Pub Cache"; Path="D:\Development\Pub\Cache"},
    @{Name="Android SDK"; Path="D:\Development\Android\Sdk"}
)

foreach ($item in $dItems) {
    if (Test-Path $item.Path) {
        $size = (Get-ChildItem $item.Path -Recurse -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
        Write-Host "  ✓ $($item.Name): $([math]::Round($size,2)) GB" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($item.Name): Not found" -ForegroundColor Red
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($freeGB -gt 5) {
    Write-Host "✓ SUCCESS: C: drive has enough space!" -ForegroundColor Green
} elseif ($freeGB -gt 1) {
    Write-Host "⚠ WARNING: C: drive still low on space" -ForegroundColor Yellow
    Write-Host "  Consider moving more files or cleaning up" -ForegroundColor Yellow
} else {
    Write-Host "✗ CRITICAL: C: drive still very low!" -ForegroundColor Red
    Write-Host "  Migration may not have worked or more space needed" -ForegroundColor Red
}
