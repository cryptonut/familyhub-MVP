# Emergency space freeing script - finds and moves large files
# This script will find what's actually taking space and move it

$ErrorActionPreference = "Continue"
$logFile = "C:\Users\simon\Documents\familyhub-MVP\migration_log.txt"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage -ForegroundColor $Color
}

Write-Log "=== Emergency Space Freeing Script ===" "Cyan"

# Check current space
$c = Get-PSDrive C
$freeGB = [math]::Round($c.Free / 1GB, 2)
Write-Log "C: Drive Free: $freeGB GB" $(if ($freeGB -lt 1) { "Red" } else { "Yellow" })

# Check D: drive
if (-not (Test-Path "D:\")) {
    Write-Log "ERROR: D: drive not found!" "Red"
    exit 1
}
$d = Get-PSDrive D
$dFreeGB = [math]::Round($d.Free / 1GB, 2)
Write-Log "D: Drive Free: $dFreeGB GB" "Green"

# Create base directory
$devBase = "D:\Development"
New-Item -ItemType Directory -Path $devBase -Force | Out-Null
Write-Log "Created $devBase" "Green"

# Function to move with symlink
function Move-ToDDrive {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$Name
    )
    
    if (-not (Test-Path $SourcePath)) {
        Write-Log "$Name not found at $SourcePath" "Yellow"
        return $false
    }
    
    # Check if already a symlink
    try {
        $item = Get-Item $SourcePath -ErrorAction Stop
        if ($item.LinkType -eq "SymbolicLink") {
            Write-Log "$Name is already a symbolic link - skipping" "Yellow"
            return $false
        }
    } catch {}
    
    # Get size
    try {
        $size = (Get-ChildItem $SourcePath -Recurse -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
        $sizeGB = [math]::Round($size, 2)
        
        if ($sizeGB -lt 0.1) {
            Write-Log "$Name is too small ($sizeGB GB) - skipping" "Gray"
            return $false
        }
        
        Write-Log "$Name found: $sizeGB GB" "Cyan"
    } catch {
        Write-Log "Error calculating size for $Name : $_" "Red"
        return $false
    }
    
    # Move
    try {
        Write-Log "Moving $Name to $DestPath..." "Yellow"
        
        # Create parent directory
        $parent = Split-Path $DestPath -Parent
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        
        # Move
        Move-Item $SourcePath $DestPath -Force -ErrorAction Stop
        Write-Log "  ✓ Moved successfully" "Green"
        
        # Create symlink
        New-Item -ItemType SymbolicLink -Path $SourcePath -Target $DestPath -Force | Out-Null
        Write-Log "  ✓ Created symbolic link" "Green"
        
        return $true
    } catch {
        Write-Log "  ✗ Error moving $Name : $_" "Red"
        return $false
    }
}

# Items to move
$itemsToMove = @(
    @{Source="$env:USERPROFILE\.gradle"; Dest="$devBase\.gradle"; Name="Gradle Cache"},
    @{Source="$env:LOCALAPPDATA\Pub\Cache"; Dest="$devBase\Pub\Cache"; Name="Flutter Pub Cache"},
    @{Source="$env:LOCALAPPDATA\Android\Sdk"; Dest="$devBase\Android\Sdk"; Name="Android SDK"},
    @{Source="$env:LOCALAPPDATA\Android"; Dest="$devBase\Android"; Name="Android (entire folder)"}
)

$movedCount = 0
foreach ($item in $itemsToMove) {
    if (Move-ToDDrive -SourcePath $item.Source -DestPath $item.Dest -Name $item.Name) {
        $movedCount++
    }
}

# Clean temp files
Write-Log "`nCleaning temp files..." "Cyan"
$tempDirs = @(
    "$env:LOCALAPPDATA\Temp",
    "$env:TEMP",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
)

foreach ($tempDir in $tempDirs) {
    if (Test-Path $tempDir) {
        try {
            $size = (Get-ChildItem $tempDir -Recurse -ErrorAction SilentlyContinue | 
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
            if ($size -gt 0.1) {
                Write-Log "Cleaning $tempDir ($([math]::Round($size,2)) GB)..." "Yellow"
                Remove-Item "$tempDir\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "  ✓ Cleaned" "Green"
            }
        } catch {
            Write-Log "  ✗ Error cleaning $tempDir : $_" "Red"
        }
    }
}

# Final check
$c = Get-PSDrive C
$finalFreeGB = [math]::Round($c.Free / 1GB, 2)
$freed = $finalFreeGB - $freeGB

Write-Log "`n=== FINAL RESULTS ===" "Cyan"
Write-Log "C: Drive Free: $finalFreeGB GB" $(if ($finalFreeGB -gt 5) { "Green" } elseif ($finalFreeGB -gt 1) { "Yellow" } else { "Red" })
Write-Log "Space Freed: $([math]::Round($freed,2)) GB" $(if ($freed -gt 1) { "Green" } else { "Yellow" })
Write-Log "Items Moved: $movedCount" "Cyan"

if ($finalFreeGB -lt 1) {
    Write-Log "`n⚠ WARNING: Still critically low on space!" "Red"
    Write-Log "Consider:" "Yellow"
    Write-Log "  1. Moving Documents/Downloads folders" "Yellow"
    Write-Log "  2. Running Windows Disk Cleanup" "Yellow"
    Write-Log "  3. Uninstalling unused programs" "Yellow"
    Write-Log "  4. Moving project to D: drive" "Yellow"
}

Write-Log "`nLog saved to: $logFile" "Gray"
