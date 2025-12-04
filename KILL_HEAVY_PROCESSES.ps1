# Kill Heavy Processes Causing Lag
# Run this script to free up resources

Write-Host "Killing Java/Gradle processes..."
Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "Killing Gradle daemons..."
Get-Process | Where-Object {$_.ProcessName -like "*gradle*"} | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "Killing Dart processes..."
Get-Process | Where-Object {$_.ProcessName -like "*dart*"} | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "Done! PC should be faster now."

