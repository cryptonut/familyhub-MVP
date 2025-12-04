# Fix Hotspot Not Starting

## The Problem
Phone connects but gets "reasonCode: 3" (IP configuration failure). Hotspot shows "Not available" - it's not actually running.

## Fix Steps

### 1. Restart Mobile Hotspot Service
**Run PowerShell as Administrator:**
```powershell
Restart-Service icssvc -Force
```

### 2. Enable WiFi Adapter Power Management
1. **Device Manager** → **Network adapters**
2. Right-click **"Qualcomm Atheros AR9287"**
3. **Properties** → **Power Management** tab
4. **UNCHECK** "Allow the computer to turn off this device to save power"
5. Click **OK**

### 3. Reset Network Stack
**Run PowerShell as Administrator:**
```powershell
netsh winsock reset
netsh int ip reset
ipconfig /flushdns
Restart-Computer
```

### 4. Alternative: Use Legacy Hosted Network
If Mobile Hotspot still doesn't work, use the legacy method:

**Run Command Prompt as Administrator:**
```cmd
netsh wlan set hostednetwork mode=allow ssid=PCInternet key=Test12345678
netsh wlan start hostednetwork
```

Then share Ethernet connection to "Local Area Connection* 2" in network adapter properties.

### 5. Check Windows Version
Some Windows versions have bugs with Mobile Hotspot. If nothing works:
- Update Windows
- Or use a USB WiFi adapter
- Or use your phone's mobile data instead

## Quick Test
After restarting icssvc service, turn hotspot ON and try connecting from phone again.

