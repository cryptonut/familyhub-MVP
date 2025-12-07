# Script to identify and move large files/folders from C: to D: drive
# This script identifies safe-to-move items and provides commands to move them

Write-Host "=== C: Drive Space Analysis ===" -ForegroundColor Cyan
$cDrive = Get-PSDrive C
$freeGB = [math]::Round($cDrive.Free / 1GB, 2)
$usedGB = [math]::Round($cDrive.Used / 1GB, 2)
Write-Host "C: Drive - Free: $freeGB GB | Used: $usedGB GB" -ForegroundColor Yellow

Write-Host "`n=== D: Drive Status ===" -ForegroundColor Cyan
if (Test-Path "D:\") {
    $dDrive = Get-PSDrive D -ErrorAction SilentlyContinue
    if ($dDrive) {
        $dFreeGB = [math]::Round($dDrive.Free / 1GB, 2)
        $dUsedGB = [math]::Round($dDrive.Used / 1GB, 2)
        Write-Host "D: Drive - Free: $dFreeGB GB | Used: $dUsedGB GB" -ForegroundColor Green
    } else {
        Write-Host "D: Drive exists but cannot read stats" -ForegroundColor Yellow
    }
} else {
    Write-Host "D: Drive not found!" -ForegroundColor Red
    exit
}

Write-Host "`n=== Analyzing Large Directories ===" -ForegroundColor Cyan

# Check common large directories
$itemsToCheck = @(
    @{Path="$env:USERPROFILE\.gradle"; Name="Gradle Cache"; Safe=$true},
    @{Path="$env:LOCALAPPDATA\Pub\Cache"; Name="Flutter Pub Cache"; Safe=$true},
    @{Path="$env:LOCALAPPDATA\Android"; Name="Android SDK"; Safe=$true},
    @{Path="$env:LOCALAPPDATA\Android\Sdk"; Name="Android SDK (Sdk)"; Safe=$true},
    @{Path="$env:USERPROFILE\AppData\Local\Android"; Name="Android Local"; Safe=$true},
    @{Path="C:\Users\simon\Documents"; Name="Documents"; Safe=$true},
    @{Path="C:\Users\simon\Downloads"; Name="Downloads"; Safe=$true},
    @{Path="C:\Users\simon\Desktop"; Name="Desktop"; Safe=$true},
    @{Path="$env:LOCALAPPDATA\Temp"; Name="Temp Files"; Safe=$true},
    @{Path="$env:TEMP"; Name="System Temp"; Safe=$true},
    @{Path="C:\Users\simon\AppData\Local\Microsoft\Windows\INetCache"; Name="Browser Cache"; Safe=$true}
)

$largeItems = @()

foreach ($item in $itemsToCheck) {
    if (Test-Path $item.Path) {
        try {
            $size = (Get-ChildItem $item.Path -Recurse -ErrorAction SilentlyContinue -Force | 
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
            if ($size -gt 0.1) {
                $largeItems += [PSCustomObject]@{
                    Name = $item.Name
                    Path = $item.Path
                    SizeGB = [math]::Round($size, 2)
                    Safe = $item.Safe
                }
            }
        } catch {
            Write-Host "  Could not analyze: $($item.Name)" -ForegroundColor Yellow
        }
    }
}

# Sort by size
$largeItems = $largeItems | Sort-Object SizeGB -Descending

Write-Host "`n=== Large Directories Found ===" -ForegroundColor Cyan
foreach ($item in $largeItems) {
    $color = if ($item.SizeGB -gt 5) { "Red" } elseif ($item.SizeGB -gt 1) { "Yellow" } else { "White" }
    Write-Host "  $($item.Name): $($item.SizeGB) GB - $($item.Path)" -ForegroundColor $color
}

$totalMovable = ($largeItems | Where-Object {$_.Safe} | Measure-Object -Property SizeGB -Sum).Sum
Write-Host "`nTotal potentially movable: $([math]::Round($totalMovable, 2)) GB" -ForegroundColor Green

Write-Host "`n=== Recommended Actions ===" -ForegroundColor Cyan
Write-Host "1. Move Gradle cache (if exists):" -ForegroundColor Yellow
if ($largeItems | Where-Object {$_.Name -eq "Gradle Cache"}) {
    $gradle = $largeItems | Where-Object {$_.Name -eq "Gradle Cache"}
    Write-Host "   Move-Item '$($gradle.Path)' 'D:\Development\.gradle' -Force" -ForegroundColor White
    Write-Host "   New-Item -ItemType SymbolicLink -Path '$($gradle.Path)' -Target 'D:\Development\.gradle'" -ForegroundColor White
}

Write-Host "`n2. Move Flutter Pub cache (if exists):" -ForegroundColor Yellow
if ($largeItems | Where-Object {$_.Name -eq "Flutter Pub Cache"}) {
    $pub = $largeItems | Where-Object {$_.Name -eq "Flutter Pub Cache"}
    Write-Host "   Move-Item '$($pub.Path)' 'D:\Development\Pub\Cache' -Force" -ForegroundColor White
    Write-Host "   New-Item -ItemType SymbolicLink -Path '$($pub.Path)' -Target 'D:\Development\Pub\Cache'" -ForegroundColor White
}

Write-Host "`n3. Move Android SDK (if exists):" -ForegroundColor Yellow
if ($largeItems | Where-Object {$_.Name -match "Android"}) {
    $android = $largeItems | Where-Object {$_.Name -match "Android"} | Select-Object -First 1
    Write-Host "   Move-Item '$($android.Path)' 'D:\Development\Android' -Force" -ForegroundColor White
    Write-Host "   New-Item -ItemType SymbolicLink -Path '$($android.Path)' -Target 'D:\Development\Android'" -ForegroundColor White
}

Write-Host "`n4. Clean temp files:" -ForegroundColor Yellow
Write-Host "   Remove-Item '$env:LOCALAPPDATA\Temp\*' -Recurse -Force -ErrorAction SilentlyContinue" -ForegroundColor White
Write-Host "   Remove-Item '$env:TEMP\*' -Recurse -Force -ErrorAction SilentlyContinue" -ForegroundColor White

Write-Host "`n5. Move Documents/Downloads (optional):" -ForegroundColor Yellow
Write-Host "   Move-Item 'C:\Users\simon\Documents' 'D:\Documents' -Force" -ForegroundColor White
Write-Host "   Move-Item 'C:\Users\simon\Downloads' 'D:\Downloads' -Force" -ForegroundColor White
Write-Host "   Then update folder location in Windows Settings > System > Storage > Change where new content is saved" -ForegroundColor Gray

Write-Host "`n=== IMPORTANT NOTES ===" -ForegroundColor Red
Write-Host "- Symbolic links allow tools to find files in new location" -ForegroundColor Yellow
Write-Host "- Test after moving to ensure Flutter/Android still work" -ForegroundColor Yellow
Write-Host "- Keep backups before moving critical folders" -ForegroundColor Yellow
