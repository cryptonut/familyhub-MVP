# Check Project Size and Storage Usage
# Usage: .\check_project_size.ps1

Write-Host "=== Project Size Analysis ===" -ForegroundColor Cyan
Write-Host ""

$projectRoot = Get-Location
Write-Host "Project Root: $projectRoot" -ForegroundColor Yellow
Write-Host ""

# Get drive info
$currentDrive = (Get-Item $projectRoot).PSDrive
$currentDriveInfo = Get-PSDrive $currentDrive.Name

Write-Host "Current Drive: $($currentDrive.Name):" -ForegroundColor Cyan
Write-Host "   Total Size: $([math]::Round($currentDriveInfo.Used + $currentDriveInfo.Free, 2)) GB" -ForegroundColor Gray
Write-Host "   Used: $([math]::Round($currentDriveInfo.Used / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "   Free: $([math]::Round($currentDriveInfo.Free / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host ""

# Check C: drive
$cDrive = Get-PSDrive C
Write-Host "C: Drive:" -ForegroundColor Cyan
Write-Host "   Total Size: $([math]::Round($cDrive.Used + $cDrive.Free, 2)) GB" -ForegroundColor Gray
Write-Host "   Used: $([math]::Round($cDrive.Used / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "   Free: $([math]::Round($cDrive.Free / 1GB, 2)) GB" -ForegroundColor Green
Write-Host ""

# Calculate project directory size
Write-Host "Calculating project size..." -ForegroundColor Yellow
$projectSize = (Get-ChildItem -Path $projectRoot -Recurse -Force -ErrorAction SilentlyContinue | 
    Measure-Object -Property Length -Sum).Sum

$projectSizeGB = [math]::Round($projectSize / 1GB, 2)

Write-Host "Total Project Size: $projectSizeGB GB" -ForegroundColor Green
Write-Host ""

# Break down by major directories
Write-Host "Size Breakdown:" -ForegroundColor Cyan

$dirs = @(
    "build",
    ".dart_tool",
    ".gradle",
    "android/.gradle",
    "android/build",
    "android/app/build",
    "node_modules",
    ".git"
)

foreach ($dir in $dirs) {
    $dirPath = Join-Path $projectRoot $dir
    if (Test-Path $dirPath) {
        $dirSize = (Get-ChildItem -Path $dirPath -Recurse -Force -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum
        $dirSizeGB = [math]::Round($dirSize / 1GB, 2)
        if ($dirSizeGB -gt 0.01) {
            Write-Host "   $dir`: $dirSizeGB GB" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Analysis Complete!" -ForegroundColor Green

