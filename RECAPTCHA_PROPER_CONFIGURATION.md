# Proper reCAPTCHA Configuration Guide

## When reCAPTCHA is Needed

reCAPTCHA is used by Firebase Auth when:
1. App Check is not working or not configured
2. Firebase Auth needs additional verification
3. Suspicious activity is detected

## Proper reCAPTCHA Setup

### Step 1: Get reCAPTCHA Keys from Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **Authentication** > **Settings** (gear icon)
4. Scroll to **reCAPTCHA provider** section
5. If not enabled, click **Enable**
6. Copy the **Site Key** and **Secret Key**

### Step 2: Verify reCAPTCHA Keys in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **Security** > **reCAPTCHA**
4. Find your reCAPTCHA keys
5. Verify they are **Active** and not restricted

### Step 3: Configure OAuth Client for reCAPTCHA

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Go to **APIs & Services** > **Credentials**
3. Find **OAuth 2.0 Client IDs** for your Android app
4. Verify:
   - Package name matches: `com.example.familyhub_mvp.test` (for qa flavor)
   - SHA-1 fingerprint is registered: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
   - SHA-256 fingerprint is registered (for App Check)

### Step 4: Verify API Key Allows reCAPTCHA

1. In Google Cloud Console > **APIs & Services** > **Credentials**
2. Find your Android API key
3. Under **API restrictions**, ensure:
   - **reCAPTCHA Enterprise API** is enabled (if using Enterprise)
   - **Identity Toolkit API** is enabled
   - **Firebase Authentication API** is enabled

### Step 5: Test reCAPTCHA

1. Rebuild app: `flutter clean && flutter run`
2. Check logs for reCAPTCHA token generation
3. If "empty reCAPTCHA token" persists, check:
   - Network connectivity to reCAPTCHA endpoints
   - API key restrictions
   - OAuth client configuration

## Alternative: Use App Check Instead

**Recommended**: If App Check works properly, reCAPTCHA is not needed:
- App Check provides better security
- No user interaction required
- Works automatically with Play Integrity

## Troubleshooting

### "empty reCAPTCHA token" Error

**Causes**:
1. reCAPTCHA keys not configured in Firebase Console
2. API key restrictions blocking reCAPTCHA API
3. OAuth client not configured correctly
4. Network issues preventing reCAPTCHA from loading
5. SHA-1 fingerprint mismatch

**Solutions**:
1. Enable reCAPTCHA in Firebase Console
2. Verify API key allows reCAPTCHA API
3. Check OAuth client configuration
4. Verify SHA-1 fingerprint is correct
5. Check network connectivity

