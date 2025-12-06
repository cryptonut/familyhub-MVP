# Test Network Connectivity from Dev Phone

## Quick Network Test Commands

Connect your dev phone via USB and run:

```bash
# Test if phone can reach Firebase
adb shell ping -c 3 identitytoolkit.googleapis.com

# Test if phone can reach Google
adb shell ping -c 3 googleapis.com

# Test DNS resolution
adb shell nslookup identitytoolkit.googleapis.com

# Test HTTPS connectivity
adb shell curl -I https://identitytoolkit.googleapis.com
```

## What to Look For

**If ping fails:**
- Extender is blocking DNS or ICMP
- Try using Google DNS (8.8.8.8) on the extender

**If nslookup fails:**
- DNS issue - extender's DNS is blocking Google domains
- Fix: Change extender DNS to 8.8.8.8, 8.8.4.4

**If curl fails:**
- HTTPS is blocked or certificate issues
- Extender might be doing SSL inspection

## Quick Fix: Change Phone DNS

On the dev phone:
1. Go to **Settings** > **WiFi**
2. Long-press on "Wavelink N" network
3. Select **Modify network** or **Network details**
4. Change **IP settings** to **Static** (temporarily)
5. Set **DNS 1**: `8.8.8.8`
6. Set **DNS 2**: `8.8.4.4`
7. Save and reconnect

This bypasses the extender's DNS and uses Google's directly.

## Expected Result

After changing DNS or using Starlink:
- ✅ Login should work immediately
- ✅ No more "empty reCAPTCHA token" (if network was the issue)
- ✅ Firebase connections succeed

