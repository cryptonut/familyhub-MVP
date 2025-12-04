# Create Mobile Hotspot from PC
# Run PowerShell as Administrator

# Set hotspot name and password
$ssid = "PCInternet"
$password = "Test12345678"

Write-Host "Creating mobile hotspot..."
netsh wlan set hostednetwork mode=allow ssid=$ssid key=$password

Write-Host "Starting hotspot..."
netsh wlan start hostednetwork

Write-Host ""
Write-Host "Hotspot created: $ssid"
Write-Host "Password: $password"
Write-Host ""
Write-Host "Now connect your phone to '$ssid' WiFi network"
Write-Host "Phone will use PC's internet (Ethernet/Starlink)"

# Share internet connection
Write-Host ""
Write-Host "To share internet:"
Write-Host "1. Open Network Connections (ncpa.cpl)"
Write-Host "2. Right-click your Ethernet connection"
Write-Host "3. Properties → Sharing tab"
Write-Host "4. Check 'Allow other network users to connect'"
Write-Host "5. Select the hotspot adapter from dropdown"

