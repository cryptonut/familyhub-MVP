# MOVE PROJECT TO D: DRIVE
# Run this script manually in PowerShell (may need to close IDE first)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MOVING PROJECT TO D: DRIVE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$src = "C:\Users\simon\Documents\familyhub-MVP"
$dest = "D:\familyhub-MVP"

# Check source
if (-not (Test-Path $src)) {
    Write-Host "ERROR: Project not found at:" -ForegroundColor Red
    Write-Host "  $src" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check D: drive
if (-not (Test-Path "D:\")) {
    Write-Host "ERROR: D: drive not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Calculate size
Write-Host "Calculating project size..." -ForegroundColor Yellow
$size = (Get-ChildItem $src -Recurse -ErrorAction SilentlyContinue | 
        Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
Write-Host "Project size: $([math]::Round($size, 2)) GB" -ForegroundColor Cyan

# Check D: space
$d = Get-PSDrive D
$dFree = [math]::Round($d.Free / 1GB, 2)
Write-Host "D: drive free: $dFree GB" -ForegroundColor $(if ($dFree -gt $size + 1) { "Green" } else { "Red" })

if ($dFree -lt $size + 1) {
    Write-Host "WARNING: Not enough space on D: drive!" -ForegroundColor Red
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        exit 0
    }
}

# Clean build artifacts first
Write-Host "`nCleaning build artifacts to reduce size..." -ForegroundColor Yellow
Push-Location $src
try {
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        Write-Host "Running: flutter clean" -ForegroundColor Gray
        flutter clean 2>&1 | Out-Null
    }
} catch {}

# Remove build dirs
$buildDirs = @("build", "android\app\build", "android\.gradle", "android\build", ".dart_tool")
foreach ($dir in $buildDirs) {
    $fullPath = Join-Path $src $dir
    if (Test-Path $fullPath) {
        Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Pop-Location

# Remove destination if exists
if (Test-Path $dest) {
    Write-Host "`nWARNING: Destination already exists!" -ForegroundColor Yellow
    Write-Host "  $dest" -ForegroundColor Yellow
    $response = Read-Host "Delete and overwrite? (y/N)"
    if ($response -eq "y" -or $response -eq "Y") {
        Remove-Item $dest -Recurse -Force
        Write-Host "Removed existing destination" -ForegroundColor Green
    } else {
        Write-Host "Cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Move
Write-Host "`nMoving project..." -ForegroundColor Yellow
Write-Host "  From: $src" -ForegroundColor Gray
Write-Host "  To:   $dest" -ForegroundColor Gray
Write-Host ""

try {
    # Create parent
    $parent = Split-Path $dest -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    
    # Move
    Write-Host "This may take a few minutes..." -ForegroundColor Yellow
    Move-Item $src $dest -Force -ErrorAction Stop
    
    Write-Host "`n✓ Project moved successfully!" -ForegroundColor Green
} catch {
    Write-Host "`n✗ ERROR moving project:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nPossible causes:" -ForegroundColor Yellow
    Write-Host "  - Files are open in IDE/editor (close Cursor/VS Code)" -ForegroundColor Yellow
    Write-Host "  - Files are locked by another process" -ForegroundColor Yellow
    Write-Host "  - Insufficient permissions" -ForegroundColor Yellow
    Read-Host "`nPress Enter to exit"
    exit 1
}

# Create symlink
Write-Host "`nCreating symbolic link..." -ForegroundColor Yellow
try {
    New-Item -ItemType SymbolicLink -Path $src -Target $dest -Force | Out-Null
    Write-Host "✓ Symbolic link created!" -ForegroundColor Green
    Write-Host "  Project will still appear in Documents folder" -ForegroundColor Gray
} catch {
    Write-Host "⚠ Could not create symlink: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  You may need to run PowerShell as Administrator" -ForegroundColor Yellow
    Write-Host "  Project is at: $dest" -ForegroundColor Gray
}

# Verify
Write-Host "`n=== Verification ===" -ForegroundColor Cyan
if (Test-Path $dest) {
    Write-Host "✓ Project exists at: $dest" -ForegroundColor Green
} else {
    Write-Host "✗ Project NOT found at destination!" -ForegroundColor Red
}

if (Test-Path $src) {
    try {
        $item = Get-Item $src -Force
        if ($item.LinkType -eq "SymbolicLink") {
            Write-Host "✓ Symlink working correctly" -ForegroundColor Green
        } else {
            Write-Host "⚠ Path exists but is not a symlink" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠ Could not verify symlink" -ForegroundColor Yellow
    }
}

# Check C: space
$c = Get-PSDrive C
$cFree = [math]::Round($c.Free / 1GB, 2)
Write-Host "`nC: Drive Free Space: $cFree GB" -ForegroundColor $(if ($cFree -gt 5) { "Green" } elseif ($cFree -gt 1) { "Yellow" } else { "Red" })

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  MIGRATION COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Close and reopen your IDE (Cursor)" -ForegroundColor Cyan
Write-Host "2. Open project from: $dest" -ForegroundColor Cyan
Write-Host "   (or use the symlink in Documents if it was created)" -ForegroundColor Gray
Write-Host "3. Run: flutter pub get" -ForegroundColor Cyan
Write-Host "4. Try building your project" -ForegroundColor Cyan
Write-Host ""

Read-Host "Press Enter to exit"
