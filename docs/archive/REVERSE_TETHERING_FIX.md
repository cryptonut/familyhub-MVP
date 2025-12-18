# The Real Problem

**USB tethering on Android makes the PHONE the internet provider**, not the receiver.

When you enable USB tethering:
- Phone becomes DHCP server (assigns 10.178.178.x)
- Phone shares ITS internet to PC
- This is backwards from what we need

## What We Actually Need: Reverse USB Tethering

We need the PC to share internet TO the phone, not the other way around.

## Solution: Use Windows Mobile Hotspot (PC Creates WiFi)

**This is the ONLY reliable way to share PC internet to phone:**

1. **Settings** → **Network & Internet** → **Mobile hotspot**
2. **Turn on "Mobile hotspot"**
3. **"Share my Internet connection from"**: Select **"Ethernet"**
4. **Edit** to set name/password
5. **On phone**: Connect to this WiFi hotspot

**This works because:**
- PC creates WiFi network
- Phone connects as WiFi client
- PC shares Ethernet internet through WiFi
- No USB/subnet conflicts

## Why USB Tethering Doesn't Work

USB tethering is designed for phone → PC, not PC → phone. Android doesn't have a built-in "reverse tethering" mode that makes the phone receive internet via USB.

## Alternative: Use Phone's Mobile Data

If you have mobile data on the phone:
- Just use mobile data instead of WiFi
- This bypasses the extender completely
- Test login with mobile data

