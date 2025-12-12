# PowerShell script to monitor logcat for Family Hub app
# Usage: .\monitor_logcat.ps1 [filter]

param(
    [string]$Filter = "flutter|AuthService|CalendarService|permission|ERROR|WARNING|FamilyHub"
)

$deviceId = "RFCT61EGZEH"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Logcat Monitor for Family Hub" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Device: $deviceId" -ForegroundColor Yellow
Write-Host "Filter: $Filter" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Green
Write-Host ""

# Clear logcat buffer
adb -s $deviceId logcat -c | Out-Null

# Start monitoring with filter
adb -s $deviceId logcat | Select-String -Pattern $Filter

