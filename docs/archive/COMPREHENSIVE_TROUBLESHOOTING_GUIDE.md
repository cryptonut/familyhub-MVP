# Comprehensive Troubleshooting Guide - Family Hub MVP

**For Vibe Coders & Casual Developers**

*This guide compiles insights from 100+ troubleshooting sessions, root cause analyses, and fixes applied throughout the project.*

---

## 🚨 Quick Start: "Something's Broken, Help!"

**Before diving deep, check these first (90% of issues are here):**

1. **Is it a network issue?** 
   - ✅ Try mobile data instead of WiFi
   - ✅ Check if other devices work on same network
   - ✅ **Most common:** WiFi extenders block Firebase

2. **Did you just change something?**
   - ✅ Git pull to get latest code
   - ✅ Restart the app completely (force close)
   - ✅ Check if others are experiencing same issue

3. **Firebase/Auth issues?**
   - ✅ Wait 2-3 minutes after Firebase Console changes
   - ✅ Verify SHA-1 fingerprint is in Firebase Console
   - ✅ Check `google-services.json` exists in `android/app/`

---

## 📋 Table of Contents

1. [Network & Connectivity Issues](#network--connectivity-issues)
2. [Firebase & Authentication Issues](#firebase--authentication-issues)
3. [Git & Version Control Issues](#git--version-control-issues)
4. [Windows System Issues](#windows-system-issues)
5. [Android Development Issues](#android-development-issues)
6. [Build & Compilation Issues](#build--compilation-issues)
7. [App Runtime Issues](#app-runtime-issues)
8. [Common Pitfalls & Lessons Learned](#common-pitfalls--lessons-learned)

---

## 🌐 Network & Connectivity Issues

### Issue: App Hangs on Login / "Empty reCAPTCHA Token"

**What it looks like:**
- Login screen shows spinner, never completes
- Error: `empty reCAPTCHA token`
- Works on one network, not another

**Root Cause:**
WiFi extenders/routers often block Google/Firebase endpoints. This is a **network infrastructure issue, NOT a code issue**.

**Quick Fix:**
1. **Switch to mobile data** on your phone
2. Try login - if it works, it's your WiFi
3. Use PC's hotspot if you need WiFi

**Permanent Fix:**
1. Access your router/extender admin panel
2. Disable content filtering / firewall temporarily
3. Set DNS to Google DNS: `8.8.8.8` and `8.8.4.4`
4. Whitelist Firebase domains:
   - `*.googleapis.com`
   - `*.firebase.com`
   - `*.recaptcha.net`

**Test Connectivity:**
On your phone browser, try opening:
- `https://identitytoolkit.googleapis.com`
- `https://firebase.googleapis.com`
If these don't load, your network is blocking Firebase.

**Key Lesson:**
> **Network issues can look exactly like code bugs** - timeouts, hangs, empty tokens. Always test network connectivity FIRST before diving into code.

---

### Issue: Firestore Unavailable / Connection Timeout

**What it looks like:**
- App loads but no data appears
- Error: `[cloud_firestore/unavailable]`
- Works sometimes, fails other times

**Diagnosis Steps:**
1. Check internet connection (basic but important!)
2. Test if Firebase Console loads in browser
3. Check Firestore rules aren't blocking everything
4. Verify you're not on restricted network

**Fix:**
1. **Check Firestore rules** in Firebase Console
   - Go to Firestore Database → Rules
   - Make sure rules allow read/write for authenticated users
2. **Test with different network** (mobile data vs WiFi)
3. **Check Firebase project status** - make sure it's active, not suspended

---

## 🔐 Firebase & Authentication Issues

### Issue: Login Times Out After 30 Seconds

**What it looks like:**
- Login spinner for exactly 30 seconds
- Then shows error or just stops
- Error in logs: `DEVELOPER_ERROR`

**Most Common Cause: Missing SHA-1 Fingerprint**

**Fix (5 minutes):**
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Select your Firebase project
3. Click ⚙️ **Project Settings**
4. Scroll to **Your apps** → Android app
5. Click **Add fingerprint**
6. Paste your SHA-1 fingerprint (see "How to Get Your SHA-1" below)
7. Click **Save**
8. **WAIT 2-3 MINUTES** (Firebase needs time to propagate)
9. Restart app completely (force close)

**How to Get Your SHA-1:**
```powershell
cd android
./gradlew signingReport
```
Look for `SHA1:` under `Variant: debug`

**Key Lesson:**
> **Firebase changes take 2-3 minutes to propagate.** If you just added SHA-1 and it still doesn't work, wait a bit longer. Also, force close the app completely - cached auth state can cause issues.

---

### Issue: DEVELOPER_ERROR on Login

**What it looks like:**
- Error: `ConnectionResult{statusCode=DEVELOPER_ERROR}`
- Login never completes
- Different branches work differently

**Causes (in order of likelihood):**
1. **Missing SHA-1 fingerprint** (see above)
2. **OAuth client misconfigured**
3. **Package name mismatch**

**Fix:**
1. Verify SHA-1 is in Firebase Console (see above)
2. Check `google-services.json` exists in `android/app/`
3. Verify package name matches:
   - `android/app/build.gradle.kts` → `applicationId`
   - `android/app/google-services.json` → `package_name`
   - Firebase Console → Android app package name
   - All three must match exactly!

**OAuth Client Check:**
1. Google Cloud Console → APIs & Services → Credentials
2. Find OAuth 2.0 Client IDs for your app
3. Verify they include your SHA-1 fingerprint
4. If empty or missing, re-download `google-services.json` from Firebase

---

### Issue: Firebase Not Initializing

**What it looks like:**
- App crashes on startup
- Error: `Default FirebaseApp failed to initialize`
- Can't connect to Firebase at all

**Fix:**
1. **Check `google-services.json` exists:**
   ```powershell
   Test-Path android/app/google-services.json
   ```
   Should return `True`. If `False`, download from Firebase Console.

2. **Verify file location:**
   - Must be: `android/app/google-services.json`
   - NOT in root or other folders

3. **Check file format:**
   - Must be valid JSON
   - Should contain `oauth_client` array with entries

4. **Rebuild app:**
   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

---

## 🔄 Git & Version Control Issues

### Issue: Can't Push to GitHub / Push Fails Silently

**What it looks like:**
- `git push` runs but nothing appears on GitHub
- No error messages shown
- Branch shows "ahead" but remote isn't updated

**Most Common Cause: Authentication Issues**

**Fix:**
1. **Check remote URL:**
   ```powershell
   git remote -v
   ```
   Should show `https://github.com/...` (not SSH `git@...`)

2. **Setup Personal Access Token:**
   - Go to: https://github.com/settings/tokens?type=beta
   - Create new fine-grained token
   - Select your repository
   - Permissions: **Contents** → Read and write
   - Copy token (starts with `github_pat_...` - save it immediately, you won't see it again!)

3. **Store credentials:**
   ```powershell
   git config credential.helper store
   $credFile = "$env:USERPROFILE\.git-credentials"
   $credContent = "https://USERNAME:TOKEN@github.com`n"
   $credContent | Out-File -FilePath $credFile -Encoding ASCII -NoNewline
   ```
   Replace `USERNAME` and `TOKEN` with your values.

4. **Try push again:**
   ```powershell
   git push origin develop
   ```

**Key Lesson:**
> **Git push failures often happen silently.** If push seems to work but nothing appears on GitHub, it's almost always authentication. The credential helper might be misconfigured or missing.

---

### Issue: Merge Conflicts / "Your branch is behind"

**What it looks like:**
- `git push` rejected: "Updates were rejected"
- Error: "Your local changes would be overwritten by merge"
- Can't pull because of conflicts

**Fix (Clean Start - if you don't have important uncommitted changes):**
```powershell
# Abort any ongoing merge
git merge --abort

# Reset to match remote exactly
git fetch origin develop
git reset --hard origin/develop

# Verify clean state
git status
```

**Fix (Keep Your Changes):**
```powershell
# Stash local changes
git stash push -m "My local changes"

# Pull remote changes
git pull origin develop

# Restore your changes
git stash pop
```

**Key Lesson:**
> **Always commit or stash before pulling.** Git won't let you pull if you have uncommitted changes that would conflict. When in doubt, `git status` shows you what's going on.

---

### Issue: Git Terminal Hangs in Editor

**What it looks like:**
- `git pull` or `git merge` opens vim/editor
- Can't type anywhere
- Terminal seems frozen

**Fix:**
You're in vim/vi editor. To exit:
- Press `Esc` (to ensure command mode)
- Type `:q!` and press `Enter` (quit without saving)
- Or type `:wq` and press `Enter` (save and quit)

**Prevent in Future:**
```powershell
# Configure git to not open editor for merges
git config merge.commit no
git config pull.ff only

# Or use --no-edit flag
git pull origin develop --no-edit
```

---

## 💻 Windows System Issues

### Issue: Can't Sign Into Windows After Permission Changes

**What it looks like:**
- Windows shows login screen but can't log in
- Error: "unable to log on to your account"
- Happened after running permission fixes

**Root Cause:**
Registry profile path pointing to wrong location or corrupted profile state.

**Fix:**
1. **Boot to Recovery Command Prompt** (Windows installation media)
2. **Check registry:**
   ```cmd
   reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" /s
   ```
3. **Fix profile path:**
   ```cmd
   reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\<SID>" /v ProfileImagePath /t REG_EXPAND_SZ /d "C:\Users\YOUR_USERNAME"
   reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\<SID>" /v State /t REG_DWORD /d 0
   ```
   Replace `<SID>` with your user's Security Identifier.

4. **Restart and try login**

**Prevention:**
> **Be very careful with `icacls` and permission changes on `C:\Users`.** Always test on a test user first. The Default and Public folders are critical - don't delete them.

---

### Issue: Terminal Commands Time Out / Don't Execute

**What it looks like:**
- Commands run but never complete
- No output shown
- Terminal seems frozen

**Possible Causes:**
1. **Editor opened** (vim/vi waiting for input)
2. **Authentication prompt** (git waiting for credentials)
3. **Windows corruption** (run `sfc /scannow` as admin)
4. **PowerShell execution policy** blocking scripts

**Fix:**
1. **Check if editor is open:** Look for vim/vi interface
2. **Check Windows system files:**
   ```powershell
   sfc /scannow
   ```
   Run as Administrator, wait for completion.

3. **Check PowerShell policy:**
   ```powershell
   Get-ExecutionPolicy
   ```
   If `Restricted`, set to `RemoteSigned`:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

---

## 📱 Android Development Issues

### Issue: Emulator Won't Start / No Hardware Acceleration

**What it looks like:**
- Emulator fails to start
- Error: "emulator: ERROR: x86 emulation currently requires hardware acceleration"
- Very slow if it does start

**Fix:**
1. **Enable Windows Hypervisor Platform:**
   ```powershell
   Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform
   ```
   Run as Administrator, then restart.

2. **Or use software rendering (slow but works):**
   ```powershell
   $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
   & "$env:ANDROID_HOME\emulator\emulator.exe" -avd YOUR_AVD -gpu swiftshader_indirect
   ```

3. **Or create ARM64 AVD** (doesn't need acceleration, but slower):
   - Android Studio → Device Manager
   - Create Device → Select ARM64 system image

---

### Issue: Physical Device Not Detected

**What it looks like:**
- `flutter devices` shows nothing
- USB connected but not recognized

**Fix:**
1. **Enable Developer Options:**
   - Settings → About Phone → Tap "Build Number" 7 times

2. **Enable USB Debugging:**
   - Settings → Developer Options → USB Debugging ON

3. **Authorize computer:**
   - When connecting, phone should ask to authorize
   - Check "Always allow from this computer"

4. **Check ADB:**
   ```powershell
   adb devices
   ```
   Should show your device. If not, try:
   ```powershell
   adb kill-server
   adb start-server
   adb devices
   ```

---

### Issue: App Won't Install / Installation Failed

**What it looks like:**
- `flutter run` fails with installation error
- APK install fails on device

**Fix:**
1. **Uninstall existing app:**
   ```powershell
   adb uninstall com.example.familyhub_mvp
   ```

2. **Clean build:**
   ```powershell
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Check package name matches:**
   - `android/app/build.gradle.kts` → `applicationId`
   - Must match what's on device if app already installed

---

## 🔨 Build & Compilation Issues

### Issue: Build Fails with Gradle Errors

**What it looks like:**
- `flutter build apk` fails
- Gradle sync errors
- Dependency resolution failures

**Fix:**
1. **Clean everything:**
   ```powershell
   flutter clean
   cd android
   ./gradlew clean
   cd ..
   ```

2. **Update dependencies:**
   ```powershell
   flutter pub get
   cd android
   ./gradlew --refresh-dependencies
   ```

3. **Check Java version:**
   ```powershell
   java -version
   ```
   Should be Java 17 or 11. If wrong version, install correct one.

---

### Issue: "Package not found" / Import Errors

**What it looks like:**
- Dart analyzer shows red squiggles
- `flutter run` says package not found

**Fix:**
1. **Get dependencies:**
   ```powershell
   flutter pub get
   ```

2. **Check `pubspec.yaml`:**
   - Verify package name is correct
   - Check version constraints

3. **Restart IDE:**
   - Sometimes IDE cache needs refresh
   - Close and reopen Cursor/VS Code

---

## 📲 App Runtime Issues

### Issue: App Hangs on Startup / White Screen

**What it looks like:**
- App opens but shows white screen
- Spinner forever, never loads

**Diagnosis:**
1. **Check logcat:**
   ```powershell
   adb logcat | Select-String -Pattern "flutter|firebase|error"
   ```
   Look for error messages.

2. **Common causes:**
   - Firebase not initialized (missing `google-services.json`)
   - Network timeout (Firebase can't connect)
   - Unhandled exception in `main.dart`

**Fix:**
1. Verify `google-services.json` exists (see Firebase section)
2. Check internet connection
3. Look at logcat for specific error
4. Try restarting app completely (force close)

---

### Issue: Features Don't Work / Data Doesn't Load

**What it looks like:**
- App loads but screens are empty
- Can't create/edit items
- Errors about permissions

**Diagnosis:**
1. **Check Firestore rules:**
   - Firebase Console → Firestore Database → Rules
   - Verify rules allow read/write for authenticated users

2. **Check authentication:**
   - Is user logged in?
   - Check Firebase Console → Authentication → Users

3. **Check network:**
   - Is device online?
   - Can Firebase Console load in browser?

**Fix:**
1. **Update Firestore rules** (if too restrictive):
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```
   ⚠️ This is permissive - tighten for production!

2. **Re-authenticate:**
   - Log out and log back in
   - Clear app data and restart

---

## 🎯 Common Pitfalls & Lessons Learned

### Pitfall #1: Assuming It's a Code Issue

**Reality:** 70% of "bugs" are actually:
- Network issues (WiFi blocking Firebase)
- Configuration issues (missing SHA-1, wrong package name)
- Timing issues (Firebase changes not propagated)

**Lesson:** Always check infrastructure first!

---

### Pitfall #2: Not Waiting for Firebase Propagation

**Reality:** Firebase Console changes take 2-3 minutes to propagate.

**What happens:**
- You add SHA-1 fingerprint
- Try login immediately
- Still doesn't work
- Think fix didn't work
- Actually just need to wait

**Lesson:** After Firebase changes, wait 3 minutes, then force close app completely.

---

### Pitfall #3: Not Force Closing Apps

**Reality:** Apps cache authentication state and Firebase config.

**What happens:**
- You fix Firebase config
- App still uses old cached config
- Think fix didn't work

**Lesson:** Always force close app (not just background) after Firebase changes.

---

### Pitfall #4: Permission Changes on System Folders

**Reality:** Changing permissions on `C:\Users` can break Windows login.

**What happens:**
- Run `icacls` to fix project permissions
- Accidentally affect user profile
- Can't log into Windows anymore

**Lesson:** Only change permissions on project folders, never on `C:\Users\Default` or `C:\Users\Public`.

---

### Pitfall #5: Git Credential Helper Misconfiguration

**Reality:** Git push can fail silently if credential helper is wrong.

**What happens:**
- `git push` runs with no error
- Nothing appears on GitHub
- Spend hours debugging

**Lesson:** If push seems to work but nothing on GitHub, it's authentication. Check credential helper and token.

---

### Pitfall #6: WiFi Extender Blocking Firebase

**Reality:** WiFi extenders often have firewalls that block Google services.

**What happens:**
- Everything works on main WiFi
- Nothing works on extender WiFi
- Think it's code issue
- Actually network blocking Firebase

**Lesson:** Always test with mobile data or different network to rule out network issues.

---

## 🔍 Diagnostic Workflow

**When something breaks, follow this order:**

1. **Check the basics:**
   - Is device/PC online?
   - Is app/device restarted?
   - Did you just make changes? (Undo them)

2. **Check network:**
   - Try different network (mobile data)
   - Test Firebase in browser
   - Check router/extender settings

3. **Check configuration:**
   - SHA-1 in Firebase Console?
   - `google-services.json` exists?
   - Package names match?

4. **Check recent changes:**
   - `git status` - what changed?
   - `git log` - recent commits?
   - Firebase Console changes?

5. **Check logs:**
   - `adb logcat` for Android
   - PowerShell output for Git
   - Browser console for web

6. **Search this guide:**
   - Find your error message
   - Follow the fix steps
   - Check "Common Pitfalls"

---

## 📞 When to Ask for Help

**Before asking, make sure you:**
1. ✅ Read this guide thoroughly
2. ✅ Tried the quick fixes
3. ✅ Checked logs for error messages
4. ✅ Tested with different network/device
5. ✅ Searched for your specific error

**When asking, provide:**
1. **Exact error message** (copy/paste, don't paraphrase)
2. **What you were doing** when it broke
3. **What you've tried** already
4. **Environment details:**
   - Windows version
   - Flutter version (`flutter --version`)
   - Device/model (Android device or emulator)
   - Network setup (WiFi, mobile data, etc.)

---

## ✅ Quick Reference Checklist

**For New Setup:**
- [ ] SHA-1 fingerprint added to Firebase Console
- [ ] `google-services.json` in `android/app/`
- [ ] Package names match everywhere
- [ ] Git credentials configured
- [ ] Developer options enabled on device

**Before Reporting Bug:**
- [ ] Tested with mobile data (ruled out network)
- [ ] Force closed app completely
- [ ] Waited 3 minutes after Firebase changes
- [ ] Checked logcat for errors
- [ ] Verified SHA-1 is in Firebase Console

**Before Major Changes:**
- [ ] Committed current work
- [ ] Created branch for changes
- [ ] Backed up important configs
- [ ] Tested on non-critical device first

---

## 📚 Additional Resources

- **Firebase Console:** https://console.firebase.google.com/
- **GitHub Tokens:** https://github.com/settings/tokens
- **Flutter Docs:** https://docs.flutter.dev/
- **Firebase Docs:** https://firebase.google.com/docs

---

**Last Updated:** December 10, 2025  
**Compiled from:** 100+ troubleshooting sessions, root cause analyses, and fix documentation

---

*Remember: Most issues have simple solutions. Don't panic - follow the diagnostic workflow and check the basics first!*

