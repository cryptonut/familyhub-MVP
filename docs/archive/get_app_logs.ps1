# PowerShell script to get Family Hub app logs from logcat
# Usage: .\get_app_logs.ps1 [filter] [lines]

param(
    [string]$Filter = "flutter|AuthService|CalendarService|permission|ERROR|WARNING|FamilyHub|Firebase",
    [int]$Lines = 100
)

$deviceId = "RFCT61EGZEH"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Family Hub App Logs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Device: $deviceId" -ForegroundColor Yellow
Write-Host "Filter: $Filter" -ForegroundColor Yellow
Write-Host "Lines: $Lines" -ForegroundColor Yellow
Write-Host ""

# Get recent logs with filter
$logs = adb -s $deviceId logcat -d | Select-String -Pattern $Filter | Select-Object -Last $Lines

if ($logs) {
    $logs | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "No logs found matching filter. The app may not be running." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To start monitoring logs in real-time, run:" -ForegroundColor Green
    Write-Host "  adb -s $deviceId logcat | Select-String -Pattern '$Filter'" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

