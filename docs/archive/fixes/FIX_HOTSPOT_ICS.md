# Fix Hotspot - Phone Can't Get IP

## The Problem
Phone connects to hotspot but gets "reasonCode: 3" (IP configuration failure). The hotspot adapter exists but phone can't get an IP address.

## Fix Steps (Run as Administrator)

### 1. Check Internet Connection Sharing
1. **ncpa.cpl** (Network Connections)
2. Right-click **"Ethernet"** (your Starlink)
3. **Properties** → **Sharing** tab
4. **UNCHECK** "Allow other network users..."
5. Click **OK**
6. Wait 5 seconds
7. Right-click **"Ethernet"** again
8. **Properties** → **Sharing** tab
9. **CHECK** "Allow other network users..."
10. **Select "Local Area Connection* 2"** from dropdown
11. Click **OK**

### 2. Restart ICS Service
**PowerShell as Admin:**
```powershell
Restart-Service icssvc -Force
```

### 3. Disable IPv6 on Hotspot Adapter
**PowerShell as Admin:**
```powershell
Disable-NetAdapterBinding -Name "Local Area Connection* 2" -ComponentID ms_tcpip6
```

### 4. Set Static IP on Hotspot Adapter
**PowerShell as Admin:**
```powershell
netsh interface ipv4 set address "Local Area Connection* 2" static 192.168.137.1 255.255.255.0
```

### 5. Enable DHCP on Hotspot Adapter
**PowerShell as Admin:**
```powershell
netsh interface ipv4 set address "Local Area Connection* 2" dhcp
```

### 6. Restart Everything
1. Turn hotspot **OFF**
2. Wait 10 seconds
3. Turn hotspot **ON**
4. Wait 15 seconds
5. On phone: Forget network, reconnect

## Alternative: Check Windows Version
Some Windows builds have Mobile Hotspot bugs. If nothing works:
- Update Windows
- Or use a USB WiFi adapter dongle
- Or physically move phone closer to Starlink router (if possible)

