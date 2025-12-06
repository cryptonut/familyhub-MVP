# Fix ICS Internet Sharing

## The Real Fix

The hotspot adapter is configured (192.168.137.1) but ICS isn't sharing internet. Do this:

### Step 1: Configure ICS Properly (MUST DO THIS)

1. **Press Win+R**, type `ncpa.cpl`, press Enter
2. **Right-click "Ethernet"** (your Starlink connection)
3. **Properties** → **Sharing** tab
4. **UNCHECK** "Allow other network users..." (if checked)
5. Click **OK**
6. **Wait 10 seconds**
7. **Right-click "Ethernet"** again
8. **Properties** → **Sharing** tab  
9. **CHECK** "Allow other network users to connect through this computer's Internet connection"
10. **Dropdown**: Select **"Local Area Connection* 2"**
11. **CHECK** "Allow other network users to control or disable the shared Internet connection" (optional)
12. Click **OK**

### Step 2: Restart ICS Service

**PowerShell as Administrator:**
```powershell
Restart-Service icssvc -Force
Start-Sleep -Seconds 5
```

### Step 3: Restart Hotspot

1. **Settings** → **Mobile hotspot**
2. Turn **OFF**
3. Wait 10 seconds
4. Turn **ON**
5. Wait 15 seconds

### Step 4: Test from Phone

1. On phone: **Forget** the network
2. **Connect** again with password
3. Wait 30 seconds
4. Check if phone gets IP (Settings → WiFi → Tap network → Should show IP like 192.168.137.x)

## If Still Not Working

The WiFi adapter driver might be the issue. Try:
1. **Device Manager** → **Network adapters**
2. **Qualcomm Atheros AR9287** → **Update driver**
3. Or **Uninstall** → **Restart PC** → Windows will reinstall

## Critical: ICS Must Be Configured

The hotspot won't share internet unless you manually configure ICS in network adapter properties. The Settings app doesn't always do this correctly.

