# Test Authentication After Rebuild

## Status
✅ `flutter clean` completed
✅ `flutter pub get` completed  
✅ App is launching on device (SM S906E)
⚠️ `adb` not in PATH (not critical - Flutter will reinstall app)

## What to Test Now

### 1. Attempt Login
- Use your test credentials
- Watch for completion time
- Should complete in **2-5 seconds** (not 30s)

### 2. What to Look For

**✅ SUCCESS Indicators:**
- Login completes quickly (< 5 seconds)
- No "Still waiting for Firebase response" messages
- No timeout after 30 seconds
- User successfully authenticated
- App navigates to home screen

**❌ FAILURE Indicators:**
- Still seeing "Still waiting..." messages every 5s
- Timeout after 30 seconds
- "Firebase Auth sign-in timed out" error
- App hangs on login screen

### 3. If Still Timing Out

After rebuild, if timeout persists, check:

#### A. API Key Restrictions (MOST COMMON)
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. **APIs & Services > Credentials**
3. Find API key: `AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4`
4. Click to edit
5. Under **API restrictions**:
   - Ensure **Identity Toolkit API** is enabled
   - OR temporarily set to "Don't restrict key" for testing
6. Click **Save**
7. Wait 1-2 minutes for changes to propagate
8. Test again

#### B. Verify OAuth Clients in Google Cloud
1. **APIs & Services > Credentials > OAuth 2.0 Client IDs**
2. Look for Android client with:
   - Package: `com.example.familyhub_mvp`
   - SHA-1: `bb7a6a5f57f1dd0ded142a5c6f2614fd54c3c71c`
3. If missing, Firebase should auto-create it, but you can create manually

#### C. Re-download google-services.json
If OAuth clients are still empty after rebuild:
1. [Firebase Console](https://console.firebase.google.com/)
2. Project: **family-hub-71ff0**
3. Project Settings > Your apps > Android
4. Click **Download google-services.json**
5. Replace `android/app/google-services.json`
6. Run `flutter clean && flutter run` again

### 4. Capture New Logcat

If still failing, capture new logcat:
- Should now show Flutter messages
- Look for "=== AUTH SERVICE: SIGN IN START ==="
- Check timing of "Still waiting" messages
- Note exact timeout behavior

## Expected Behavior

With OAuth clients in `google-services.json` and proper rebuild:
- **Login should work in 2-5 seconds**
- No 30-second timeout
- Firebase Auth should respond immediately

The OAuth client fix was correct - the rebuild should make it work.

## ADB Alternative (if needed)

If you need to manually uninstall:
```powershell
# Find ADB
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (Test-Path $adb) {
    & $adb uninstall com.example.familyhub_mvp
}
```

Or uninstall from device: Settings > Apps > familyhub_mvp > Uninstall

