# Fix Hotspot - Step by Step

## The Issue
WiFi adapter is disconnected - hotspot needs it enabled.

## Fix Steps

### 1. Enable WiFi Adapter
1. **Settings** → **Network & Internet** → **WiFi**
2. **Turn WiFi ON** (even if not connected to a network)
3. The adapter needs to be enabled for hotspot to work

### 2. Configure Hotspot Properly
1. **Settings** → **Network & Internet** → **Mobile hotspot**
2. **Turn OFF** hotspot if it's on
3. Click **"Edit"**
4. Set:
   - **Network name**: `PCInternet` (or any name)
   - **Network password**: `Test1234` (8+ chars, simple)
   - **Network band**: **2.4 GHz** (more compatible)
   - **Share my Internet connection from**: **Ethernet**
5. Click **Save**

### 3. Start Hotspot
1. **Turn ON** "Mobile hotspot"
2. Wait 10 seconds for it to start

### 4. On Phone
1. **Settings** → **WiFi**
2. **Forget** the network if it's saved
3. **Scan** for networks
4. Find **"PCInternet"** (or whatever you named it)
5. **Connect** with password `Test1234`
6. Wait 10-20 seconds

### 5. If Still Fails
**Try this:**
1. On PC: Turn hotspot OFF
2. On PC: **Device Manager** → **Network adapters**
3. Find **"Qualcomm Atheros AR9287"** (your WiFi adapter)
4. Right-click → **Disable**
5. Wait 5 seconds
6. Right-click → **Enable**
7. Wait 10 seconds
8. Turn hotspot ON again
9. Try connecting from phone

## Alternative: Use Ethernet Bridge
If hotspot still doesn't work, we can try bridging Ethernet to WiFi adapter, but hotspot is simpler.

