# Script to compare backup folder with current develop branch
# Usage: .\COMPARE_BACKUP_SCRIPT.ps1 -BackupPath "D:\path\to\backup\familyhub-MVP"

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupPath
)

Write-Host "Comparing backup at: $BackupPath" -ForegroundColor Cyan
Write-Host "With current develop branch at: $(Get-Location)" -ForegroundColor Cyan
Write-Host ""

# Check if backup path exists
if (-not (Test-Path $BackupPath)) {
    Write-Host "ERROR: Backup path not found: $BackupPath" -ForegroundColor Red
    exit 1
}

# Get current branch commit
$currentCommit = git log -1 --oneline
Write-Host "Current branch commit: $currentCommit" -ForegroundColor Yellow
Write-Host ""

# Compare file lists
Write-Host "=== Files in backup but not in current ===" -ForegroundColor Green
$backupFiles = Get-ChildItem -Path $BackupPath -Recurse -File | Where-Object { $_.FullName -notmatch '\.git' } | ForEach-Object { $_.FullName.Replace($BackupPath, '').TrimStart('\') }
$currentFiles = Get-ChildItem -Path . -Recurse -File | Where-Object { $_.FullName -notmatch '\.git' } | ForEach-Object { $_.FullName.Replace((Get-Location).Path, '').TrimStart('\') }

$onlyInBackup = $backupFiles | Where-Object { $_ -notin $currentFiles }
if ($onlyInBackup) {
    $onlyInBackup | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
} else {
    Write-Host "  (none)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Files in current but not in backup ===" -ForegroundColor Green
$onlyInCurrent = $currentFiles | Where-Object { $_ -notin $backupFiles }
if ($onlyInCurrent) {
    $onlyInCurrent | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
} else {
    Write-Host "  (none)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Files that differ (size comparison) ===" -ForegroundColor Green
$commonFiles = $backupFiles | Where-Object { $_ -in $currentFiles }
$differingFiles = @()

foreach ($file in $commonFiles) {
    $backupFile = Join-Path $BackupPath $file
    $currentFile = Join-Path (Get-Location).Path $file
    
    if ((Test-Path $backupFile) -and (Test-Path $currentFile)) {
        $backupSize = (Get-Item $backupFile).Length
        $currentSize = (Get-Item $currentFile).Length
        
        if ($backupSize -ne $currentSize) {
            $differingFiles += [PSCustomObject]@{
                File = $file
                BackupSize = $backupSize
                CurrentSize = $currentSize
            }
        }
    }
}

if ($differingFiles) {
    $differingFiles | ForEach-Object { 
        Write-Host "  $($_.File) - Backup: $($_.BackupSize) bytes, Current: $($_.CurrentSize) bytes" -ForegroundColor Yellow 
    }
} else {
    Write-Host "  (none - all common files have same size)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Files only in backup: $($onlyInBackup.Count)"
Write-Host "Files only in current: $($onlyInCurrent.Count)"
Write-Host "Files that differ: $($differingFiles.Count)"
Write-Host "Common files: $($commonFiles.Count)"

