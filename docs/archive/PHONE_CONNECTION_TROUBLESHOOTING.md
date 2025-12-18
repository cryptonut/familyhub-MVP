# Phone Connection Troubleshooting

## 🔧 **Quick Fixes to Try**

### **1. Check USB Connection Mode**
- On your phone, when connected via USB, check the notification
- Tap it and select **"File Transfer"** or **"MTP"** mode
- NOT "Charging only"

### **2. Enable USB Debugging**
- Go to **Settings** → **About Phone**
- Tap **Build Number** 7 times (enable Developer Options)
- Go to **Settings** → **Developer Options**
- Enable **"USB Debugging"**
- Enable **"Stay Awake"** (optional, helps during testing)

### **3. Authorize Computer**
- When you connect, your phone should show a popup: **"Allow USB Debugging?"**
- Check **"Always allow from this computer"**
- Tap **"Allow"**

### **4. Try Different USB Port/Cable**
- Some USB ports don't work well for debugging
- Try a different USB port on your computer
- Try a different USB cable (some cables are charge-only)

### **5. Restart Both Devices**
- Unplug phone
- Restart phone
- Restart computer
- Reconnect and try again

---

## ✅ **Verify Connection**

After trying the above, run:
```bash
adb devices
```

Should show something like:
```
List of devices attached
ABC123XYZ    device
```

If it shows `unauthorized`, you need to authorize on the phone.

---

## 🚀 **Once Connected**

Run:
```bash
flutter run
```

Or if multiple devices:
```bash
flutter devices
flutter run -d <device-id>
```

