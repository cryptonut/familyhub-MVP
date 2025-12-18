# WHERE TO ADD SHA-1 FINGERPRINT - CORRECT LOCATION

## ❌ WRONG: Google Cloud Console reCAPTCHA Keys
**DO NOT** add SHA-1 to the reCAPTCHA key in Google Cloud Console. That's not where it goes.

## ✅ CORRECT: Firebase Console Project Settings

### Exact Steps:

1. **Go to Firebase Console**
   - https://console.firebase.google.com/
   - Select project: **family-hub-71ff0**

2. **Open Project Settings**
   - Click the **gear icon ⚙️** next to "Project Overview" (top left)
   - Select **"Project settings"**

3. **Find Your Android App**
   - Scroll down to **"Your apps"** section
   - Find your Android app: **com.example.familyhub_mvp**
   - Click on it to expand

4. **Add SHA-1 Fingerprint**
   - Look for **"SHA certificate fingerprints"** section
   - Click **"Add fingerprint"** button
   - Paste: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
   - Click **"Save"**

5. **Wait 2-3 minutes** for changes to propagate

## Why This Matters

- Firebase Auth uses SHA-1 fingerprints registered in **Firebase Console** to verify your app
- reCAPTCHA keys in Google Cloud Console are separate - they don't need SHA-1
- The "empty reCAPTCHA token" error happens because Firebase Auth can't verify your app without the SHA-1 in Firebase Console

## Your SHA-1 Fingerprint

```
BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C
```

---

**This is the ONLY place you need to add SHA-1 for Firebase Auth to work.**

