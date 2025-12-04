# Use PC Internet on Phone - USB Tethering

## Method 1: USB Tethering (Easiest)

### On Your Phone:
1. **Connect phone to PC via USB**
2. **On phone**: Settings → Connections → Mobile Hotspot and Tethering
3. **Enable "USB tethering"**
4. Phone will now use PC's internet connection

### Verify:
- Phone's WiFi should be OFF
- Phone should show "USB tethering" or "Connected via USB" in status bar
- PC should show network adapter for the phone

## Method 2: Mobile Hotspot from PC

### On Your PC (Windows):
1. **Settings** → **Network & Internet** → **Mobile hotspot**
2. **Turn on "Mobile hotspot"**
3. **Share my Internet connection from**: Select your PC's internet (Ethernet/Starlink)
4. **Edit** to set network name and password
5. **On phone**: Connect to this hotspot (instead of Wavelink N)

## Method 3: Reverse USB Tethering (Advanced)

If USB tethering doesn't work, use reverse tethering:

### Install Required Tools:
```bash
# Download and install:
# 1. Android Reverse Tethering Tool
# 2. Or use adb commands
```

### Using ADB:
```bash
# Enable USB debugging on phone
# Then on PC:
adb shell settings put global tether_dun_required 0
adb shell svc wifi disable
adb shell svc data disable
# Then enable USB tethering on phone
```

## Quick Test - Method 1 (USB Tethering)

**Just do this:**
1. Connect phone to PC via USB
2. On phone: Settings → Connections → Mobile Hotspot and Tethering → USB tethering ON
3. Disable WiFi on phone
4. Test login

This will use your PC's internet (Starlink) instead of the WiFi extender.

