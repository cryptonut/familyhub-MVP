# Fix Internet Sharing for USB Tethering

## The Problem
Phone shows "no connection" because Windows isn't sharing the internet connection.

## Fix Steps

### Method 1: Network Connections (GUI - Easiest)

1. **Open Network Connections:**
   - Press `Win + R`
   - Type: `ncpa.cpl`
   - Press Enter

2. **Find Your Internet Connection:**
   - Look for "Ethernet" or "Realtek PCIe GBE" (your Starlink connection)
   - This should show "Enabled" and "Internet access"

3. **Find Phone Connection:**
   - Look for "Ethernet 2" or "Remote NDIS" or something with "Phone" or "Mobile"
   - This is the USB tethering connection

4. **Share Internet:**
   - Right-click your **Internet connection** (Ethernet/Starlink)
   - Click **Properties**
   - Go to **Sharing** tab
   - Check **"Allow other network users to connect through this computer's Internet connection"**
   - In dropdown, select the **phone's adapter** (Ethernet 2/Remote NDIS/etc)
   - Click **OK**

5. **On Phone:**
   - Disable and re-enable USB tethering
   - Should now have internet

### Method 2: PowerShell (If GUI doesn't work)

Run PowerShell as Administrator:

```powershell
# Find your internet adapter (usually "Ethernet")
$internetAdapter = Get-NetAdapter | Where-Object {$_.Name -like "*Ethernet*" -and $_.Status -eq "Up"} | Select-Object -First 1

# Find phone adapter (usually has "Remote" or "RNDIS" in name)
$phoneAdapter = Get-NetAdapter | Where-Object {$_.Name -like "*Remote*" -or $_.Name -like "*RNDIS*" -or $_.Name -like "*Mobile*"} | Select-Object -First 1

# Enable sharing
netsh interface set interface "$($internetAdapter.Name)" admin=enable
netsh interface set interface "$($phoneAdapter.Name)" admin=enable

# Share internet
netsh interface ipv4 set interface "$($internetAdapter.Name)" forwarding=enabled
netsh interface ipv4 set interface "$($phoneAdapter.Name)" forwarding=enabled
```

### Method 3: Use Mobile Hotspot Instead

If USB tethering is too complicated, use mobile hotspot:

1. **Settings** → **Network & Internet** → **Mobile hotspot**
2. **Turn on "Mobile hotspot"**
3. **Share my Internet connection from**: Select "Ethernet"
4. **Edit** to set name/password
5. **On phone**: Connect to this WiFi hotspot instead of Wavelink N

This is easier and more reliable.

