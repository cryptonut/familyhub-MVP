# Fix Internet Connection Sharing - Run as Administrator

Write-Host "Stopping ICS service..."
Stop-Service SharedAccess -Force

Write-Host "Reconfiguring Ethernet 2..."
netsh interface ipv4 set address "Ethernet 2" static 192.168.137.1 255.255.255.0

Write-Host "Starting ICS service..."
Start-Service SharedAccess

Write-Host ""
Write-Host "Now:"
Write-Host "1. Go to ncpa.cpl"
Write-Host "2. Right-click Ethernet -> Properties -> Sharing"
Write-Host "3. UNCHECK sharing, click OK"
Write-Host "4. Right-click Ethernet -> Properties -> Sharing"
Write-Host "5. CHECK sharing, select Ethernet 2, click OK"
Write-Host ""
Write-Host "Then on phone: Turn USB tethering OFF and ON again"

