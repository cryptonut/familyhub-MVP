# Professional Setup Guide - FamilyHub MVP

This guide ensures your app is properly configured for professional development and deployment.

## 🔴 Critical Issues to Fix

### 1. Firebase SHA-1 Fingerprint (REQUIRED)

**Error**: `DEVELOPER_ERROR` and `ConnectionResult{statusCode=DEVELOPER_ERROR}`

**Your SHA-1**: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`

**Steps**:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Click ⚙️ **Project Settings**
4. Scroll to **Your apps** → Android app: **com.example.familyhub_mvp**
5. Click **Add fingerprint**
6. Paste: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
7. Click **Save**
8. **Wait 2-3 minutes** for propagation

### 2. OAuth Client Configuration

The `DEVELOPER_ERROR` also indicates OAuth clients may not be properly configured.

**Check**:
1. Firebase Console → **Authentication** → **Sign-in method**
2. Ensure **Email/Password** is enabled
3. Check **Authorized domains** include your app's domain

### 3. Package Name Verification

Verify package name matches exactly:
- **Expected**: `com.example.familyhub_mvp`
- **Check in**: `android/app/build.gradle.kts` → `applicationId`
- **Check in**: `android/app/google-services.json` → `package_name`

## ✅ Pre-Launch Checklist

### Firebase Configuration
- [ ] SHA-1 fingerprint added to Firebase Console
- [ ] SHA-256 fingerprint added (for production)
- [ ] Email/Password authentication enabled
- [ ] Firestore Database created and rules configured
- [ ] Firebase Storage enabled (if using voice notes/images)
- [ ] `google-services.json` is in `android/app/` directory

### Android Configuration
- [ ] `minSdkVersion` is appropriate (check `android/app/build.gradle.kts`)
- [ ] `targetSdkVersion` matches latest Android version
- [ ] All required permissions in `AndroidManifest.xml`:
  - [ ] `INTERNET`
  - [ ] `RECORD_AUDIO` (for voice notes)
  - [ ] `ACCESS_FINE_LOCATION` (if using location)
  - [ ] `POST_NOTIFICATIONS` (for notifications)

### Code Quality
- [ ] Error handling implemented for all async operations
- [ ] Loading states properly managed
- [ ] Timeout mechanisms in place
- [ ] User-friendly error messages
- [ ] Proper logging for debugging

## 🛠️ Testing Checklist

### Before Release
- [ ] App launches without hanging
- [ ] Login/Registration works
- [ ] Firebase Auth connects successfully
- [ ] Firestore reads/writes work
- [ ] Voice notes record and play
- [ ] All screens load properly
- [ ] No console errors in production mode

### Error Scenarios to Test
- [ ] No internet connection
- [ ] Invalid credentials
- [ ] Firebase service unavailable
- [ ] Permission denied scenarios
- [ ] App backgrounded/foregrounded

## 📱 Device Setup

### Physical Device
1. Enable **Developer Options** on phone
2. Enable **USB Debugging**
3. Connect via USB
4. Authorize computer when prompted
5. Run `flutter devices` to verify connection

### Emulator
1. Use x86_64 system image (faster)
2. Enable hardware acceleration
3. Allocate sufficient RAM (4GB+)
4. Use cold boot if experiencing issues

## 🔧 Common Issues & Solutions

### Issue: App Hangs on Login Screen
**Cause**: Firebase Auth waiting for reCAPTCHA verification
**Solution**: Add SHA-1 fingerprint (see above)

### Issue: `DEVELOPER_ERROR`
**Cause**: Missing SHA-1 or OAuth client misconfiguration
**Solution**: 
1. Add SHA-1 fingerprint
2. Wait 2-3 minutes
3. Restart app completely

### Issue: Firestore Connection Errors
**Cause**: Network issues or security rules
**Solution**: 
1. Check internet connection
2. Verify Firestore rules allow access
3. Check Firebase project is active

### Issue: Voice Notes Not Working
**Cause**: Missing microphone permission
**Solution**: Verify `RECORD_AUDIO` in `AndroidManifest.xml`

## 🚀 Production Readiness

### Before Publishing
1. **Change package name** from `com.example.familyhub_mvp` to your actual package
2. **Generate release keystore** and add SHA-1/SHA-256 to Firebase
3. **Update Firebase rules** for production (not test mode)
4. **Enable App Check** for additional security
5. **Test on multiple devices** and Android versions
6. **Review all error messages** for user-friendliness
7. **Add analytics** for crash reporting (Firebase Crashlytics)

### Security Checklist
- [ ] Firestore rules properly restrict access
- [ ] User data is properly validated
- [ ] Sensitive operations require authentication
- [ ] API keys are not exposed in code
- [ ] OAuth clients properly configured

## 📝 Next Steps

1. **Immediate**: Add SHA-1 fingerprint to Firebase Console
2. **Short-term**: Implement comprehensive error handling
3. **Medium-term**: Add proper logging and monitoring
4. **Long-term**: Set up CI/CD and automated testing

