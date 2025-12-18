# Network Issue Diagnosis - WiFi Extender Blocking Firebase

## The Problem

**WiFi extender "Wavelink N" is likely blocking Firebase/reCAPTCHA traffic**, causing login to hang.

**Evidence:**
- ✅ Works on Starlink WiFi (direct connection)
- ❌ Doesn't work on Wavelink N extender
- ❌ Flutter app won't load on other phone with that WiFi
- ❌ Login hangs/times out

## Quick Test

### Test 1: Use Mobile Data
1. **Disable WiFi** on dev phone
2. **Enable mobile data**
3. **Try login** - if it works, it's definitely the WiFi extender

### Test 2: Test Firebase Connectivity
On the dev phone (connected to Wavelink N), open a browser and try to access:
- `https://identitytoolkit.googleapis.com` - Should load (even if it shows an error page)
- `https://firebase.googleapis.com` - Should load
- `https://www.google.com` - Should load

If these don't load, the extender is blocking Google/Firebase domains.

## What WiFi Extenders Often Block

1. **DNS issues** - Extender might use different DNS that blocks Google
2. **Firewall rules** - Extender might block certain ports/protocols
3. **Content filtering** - Extender might filter "suspicious" domains
4. **NAT issues** - Extender might not route properly
5. **Port blocking** - Extender might block HTTPS on certain ports

## Solutions

### Option 1: Use Starlink WiFi (Immediate Fix)
**Just use Starlink WiFi for testing** - it works there, so use it.

### Option 2: Configure Extender
1. **Access extender admin panel** (usually 192.168.1.1 or similar)
2. **Disable firewall/content filtering** temporarily
3. **Check DNS settings** - use Google DNS (8.8.8.8, 8.8.4.4)
4. **Disable port blocking**
5. **Check for "parental controls" or "security features"**

### Option 3: Use Mobile Data
**Switch to mobile data** for testing - bypasses the extender entirely.

### Option 4: Bridge Mode
If possible, configure the extender in **bridge mode** instead of router mode to avoid double NAT.

## Why This Causes "Empty reCAPTCHA Token"

When the extender blocks Firebase/reCAPTCHA endpoints:
1. Firebase Auth tries to get reCAPTCHA token
2. Request to `recaptcha.net` or `googleapis.com` gets blocked
3. Token generation fails → "empty reCAPTCHA token"
4. Login hangs waiting for token that never comes

## Network Security Config

The app already has `network_security_config.xml` configured to allow Firebase domains, but if the extender blocks at the network level, Android can't help.

## Recommendation

**For now: Use Starlink WiFi or mobile data for testing.**

The code is fine - it's the network infrastructure blocking Firebase.

