# Fix USB Tethering - Share PC Internet to Phone
# Run as Administrator

Write-Host "Configuring internet sharing..."

# Enable internet sharing from Ethernet to Ethernet 2
netsh interface set interface "Ethernet" admin=enable
netsh interface set interface "Ethernet 2" admin=enable

# Enable IP forwarding
netsh interface ipv4 set interface "Ethernet" forwarding=enabled
netsh interface ipv4 set interface "Ethernet 2" forwarding=enabled

# Configure sharing (this requires admin)
# The GUI method is more reliable, but try this:
Write-Host ""
Write-Host "Now do this manually:"
Write-Host "1. Press Win+R, type: ncpa.cpl"
Write-Host "2. Right-click 'Ethernet' -> Properties -> Sharing tab"
Write-Host "3. Check 'Allow other network users...'"
Write-Host "4. Select 'Ethernet 2' from dropdown"
Write-Host "5. Click OK"
Write-Host ""
Write-Host "Then on phone: Disable and re-enable USB tethering"


