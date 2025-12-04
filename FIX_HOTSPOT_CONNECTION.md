# Fix Mobile Hotspot Connection Issue

## The Problem
Phone sees hotspot but can't connect - "Couldn't connect to network"

## Common Causes & Fixes

### 1. WiFi Adapter Not Enabled
**Check:**
- Settings → Network & Internet → WiFi
- Make sure WiFi is ON

### 2. Hotspot Not Sharing Internet
**Fix:**
1. Settings → Network & Internet → Mobile hotspot
2. Click "Edit" 
3. Verify "Share my Internet connection from" is set to **"Ethernet"**
4. Save

### 3. Firewall Blocking
**Fix:**
1. Windows Security → Firewall & network protection
2. Allow an app through firewall
3. Find "Mobile Hotspot" and enable both Private/Public

### 4. Reset Hotspot
**Do this:**
1. Settings → Network & Internet → Mobile hotspot
2. Turn OFF hotspot
3. Wait 10 seconds
4. Turn ON hotspot again
5. On phone: Forget the network, then reconnect

### 5. Change Hotspot Band
**Fix:**
1. Settings → Network & Internet → Mobile hotspot → Edit
2. Change "Network band" from "5 GHz" to **"2.4 GHz"** (more compatible)
3. Save and restart hotspot

### 6. Check Password
- Make sure password is at least 8 characters
- Try a simple password like: `Test1234`
- No special characters

### 7. Network Adapter Issue
**If still not working:**
1. Device Manager → Network adapters
2. Find "Microsoft Wi-Fi Direct Virtual Adapter"
3. Right-click → Disable
4. Right-click → Enable
5. Restart hotspot

## Quick Test
After fixing, on phone:
1. Forget the network
2. Reconnect with password
3. Should connect within 10 seconds

