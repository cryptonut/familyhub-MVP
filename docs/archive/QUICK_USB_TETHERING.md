# Quick USB Tethering Setup

## Step-by-Step (Takes 30 seconds)

### 1. Connect Phone to PC
- Plug USB cable into phone and PC

### 2. On Your Phone (Samsung):
1. **Pull down notification shade**
2. **Tap "USB" or "USB for file transfer"**
3. **Select "USB tethering"** or **"Tethering"**
   
   OR
   
1. **Settings** → **Connections** → **Mobile Hotspot and Tethering**
2. **Toggle "USB tethering" ON**

### 3. Disable WiFi on Phone
- **Settings** → **WiFi** → **Turn OFF**

### 4. Verify Connection
- Phone status bar should show "USB" or "Tethering" icon
- Phone should show "Connected via USB" or similar
- PC should show new network adapter (check Network settings)

### 5. Test
- Phone now uses PC's internet (Ethernet/Starlink)
- Run your app and test login

## If USB Tethering Option Doesn't Appear

**Enable Developer Options first:**
1. Settings → About phone
2. Tap "Build number" 7 times
3. Go back → Developer options
4. Enable "USB debugging"
5. Then try USB tethering again

## Alternative: Create Hotspot from PC

If USB tethering doesn't work, create hotspot from PC:

```powershell
# Run as Administrator
netsh wlan set hostednetwork mode=allow ssid=PCInternet key=YourPassword123
netsh wlan start hostednetwork
```

Then connect phone to "PCInternet" WiFi network.

