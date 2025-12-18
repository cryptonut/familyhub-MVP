# Move entire Flutter project to D: drive
# This will free significant space on C: drive

$ErrorActionPreference = "Continue"
$projectPath = "C:\Users\simon\Documents\familyhub-MVP"
$destPath = "D:\familyhub-MVP"

Write-Host "=== Moving Project to D: Drive ===" -ForegroundColor Cyan
Write-Host ""

# Check if project exists
if (-not (Test-Path $projectPath)) {
    Write-Host "ERROR: Project not found at $projectPath" -ForegroundColor Red
    exit 1
}

# Check D: drive
if (-not (Test-Path "D:\")) {
    Write-Host "ERROR: D: drive not found!" -ForegroundColor Red
    exit 1
}

$d = Get-PSDrive D
$dFreeGB = [math]::Round($d.Free / 1GB, 2)
Write-Host "D: Drive Free Space: $dFreeGB GB" -ForegroundColor Green

# Check project size
Write-Host "Calculating project size..." -ForegroundColor Yellow
$projectSize = (Get-ChildItem $projectPath -Recurse -ErrorAction SilentlyContinue | 
               Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
$projectSizeGB = [math]::Round($projectSize, 2)

Write-Host "Project Size: $projectSizeGB GB" -ForegroundColor Cyan

if ($projectSizeGB -gt ($dFreeGB - 1)) {
    Write-Host "WARNING: Not enough space on D: drive!" -ForegroundColor Red
    Write-Host "Need: $projectSizeGB GB, Available: $dFreeGB GB" -ForegroundColor Red
    exit 1
}

# Check if destination already exists
if (Test-Path $destPath) {
    Write-Host "WARNING: Destination already exists: $destPath" -ForegroundColor Yellow
    $response = Read-Host "Overwrite? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
    Remove-Item $destPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Clean Flutter build artifacts first (to reduce size)
Write-Host "`nCleaning Flutter build artifacts..." -ForegroundColor Yellow
Push-Location $projectPath
try {
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        flutter clean 2>&1 | Out-Null
        Write-Host "  ✓ Flutter clean completed" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠ Flutter clean skipped (flutter not in PATH)" -ForegroundColor Yellow
}

# Remove build directories
$buildDirs = @("build", "android\app\build", "android\.gradle", "android\build", ".dart_tool")
foreach ($dir in $buildDirs) {
    $fullPath = Join-Path $projectPath $dir
    if (Test-Path $fullPath) {
        Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed $dir" -ForegroundColor Gray
    }
}
Pop-Location

# Recalculate size after cleanup
$projectSizeAfter = (Get-ChildItem $projectPath -Recurse -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
$projectSizeAfterGB = [math]::Round($projectSizeAfter, 2)
Write-Host "Project size after cleanup: $projectSizeAfterGB GB" -ForegroundColor Cyan

# Move the project
Write-Host "`nMoving project to D: drive..." -ForegroundColor Yellow
Write-Host "  From: $projectPath" -ForegroundColor Gray
Write-Host "  To:   $destPath" -ForegroundColor Gray

try {
    # Create parent directory
    $parent = Split-Path $destPath -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    
    # Move the project
    Move-Item $projectPath $destPath -Force -ErrorAction Stop
    Write-Host "  ✓ Project moved successfully!" -ForegroundColor Green
} catch {
    Write-Host "  ✗ ERROR moving project: $_" -ForegroundColor Red
    exit 1
}

# Create symbolic link in original location (optional but recommended)
Write-Host "`nCreating symbolic link in Documents..." -ForegroundColor Yellow
try {
    New-Item -ItemType SymbolicLink -Path $projectPath -Target $destPath -Force | Out-Null
    Write-Host "  ✓ Symbolic link created!" -ForegroundColor Green
    Write-Host "  The project will still appear in Documents folder" -ForegroundColor Gray
} catch {
    Write-Host "  ⚠ Could not create symbolic link (may need admin): $_" -ForegroundColor Yellow
    Write-Host "  You can access the project directly at: $destPath" -ForegroundColor Gray
}

# Verify
Write-Host "`n=== Verification ===" -ForegroundColor Cyan
if (Test-Path $destPath) {
    Write-Host "✓ Project exists at: $destPath" -ForegroundColor Green
} else {
    Write-Host "✗ Project NOT found at destination!" -ForegroundColor Red
}

if (Test-Path $projectPath) {
    $linkItem = Get-Item $projectPath -ErrorAction SilentlyContinue
    if ($linkItem.LinkType -eq "SymbolicLink") {
        Write-Host "✓ Symbolic link created successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠ Path exists but is not a symbolic link" -ForegroundColor Yellow
    }
}

# Check C: drive space
$c = Get-PSDrive C
$cFreeGB = [math]::Round($c.Free / 1GB, 2)
Write-Host "`nC: Drive Free Space: $cFreeGB GB" -ForegroundColor $(if ($cFreeGB -gt 5) { "Green" } elseif ($cFreeGB -gt 1) { "Yellow" } else { "Red" })

Write-Host "`n=== MIGRATION COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Close and reopen your IDE (Cursor/VS Code)" -ForegroundColor Cyan
Write-Host "2. Open the project from: $destPath" -ForegroundColor Cyan
Write-Host "3. If you see the project in Documents, it's the symlink (that's fine!)" -ForegroundColor Cyan
Write-Host "4. Run: flutter pub get" -ForegroundColor Cyan
Write-Host "5. Try building your project again" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project Location: $destPath" -ForegroundColor Gray
