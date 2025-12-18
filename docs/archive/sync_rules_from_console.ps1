# Sync Rules from Firebase Console to Local Files
# Use this if you've manually updated rules in console and want to sync them to local files

Write-Host "=== Sync Rules from Firebase Console ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script helps you sync rules that were manually updated in Firebase Console" -ForegroundColor Yellow
Write-Host "back to your local files to keep them in sync." -ForegroundColor Yellow
Write-Host ""
Write-Host "IMPORTANT: Firebase CLI cannot download deployed rules." -ForegroundColor Red
Write-Host "You need to manually copy from console to local files." -ForegroundColor Red
Write-Host ""
Write-Host "Steps:" -ForegroundColor Cyan
Write-Host "1. Open Firebase Console Storage Rules:" -ForegroundColor White
Write-Host "   https://console.firebase.google.com/project/family-hub-71ff0/storage/rules" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Copy ALL rules from the console (Ctrl+A, Ctrl+C)" -ForegroundColor White
Write-Host ""
Write-Host "3. The storage.rules file will open in Notepad" -ForegroundColor White
Write-Host "   - Delete all existing content" -ForegroundColor White
Write-Host "   - Paste the rules from console (Ctrl+V)" -ForegroundColor White
Write-Host "   - Save and close (Ctrl+S, Alt+F4)" -ForegroundColor White
Write-Host ""
Write-Host "4. Press Enter here when done..." -ForegroundColor Yellow
Write-Host ""

# Open storage.rules in Notepad
notepad storage.rules

Write-Host ""
Write-Host "Press Enter after you've saved the file..." -ForegroundColor Yellow
Read-Host

# Verify the file
$lineCount = (Get-Content storage.rules | Measure-Object -Line).Lines
Write-Host ""
Write-Host "Storage rules file now has $lineCount lines" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: Run deploy_firebase_rules_verified.ps1 to deploy the synced rules" -ForegroundColor Green

