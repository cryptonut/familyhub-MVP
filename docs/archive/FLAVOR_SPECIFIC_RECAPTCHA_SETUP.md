# Flavor-Specific reCAPTCHA Setup

## The Issue

Your app has **three flavors** with different package names:
- **dev**: `com.example.familyhub_mvp.dev`
- **qa**: `com.example.familyhub_mvp.test`  
- **prod**: `com.example.familyhub_mvp`

## What This Means for reCAPTCHA

The reCAPTCHA key in Google Cloud Console needs to support **all three package names**.

## What I've Done

✅ Updated `FamilyHubApplication.kt` to log the package name so we can see which flavor is running
✅ The same site key will work for all flavors IF the key is configured correctly

## What You Need to Do in Google Cloud Console

### Option 1: Configure One Key for All Packages (Recommended)

1. Go to: https://console.cloud.google.com/security/recaptcha
2. Click on your key: `6LeprxosAAAAACXWuPlrlx0zOyM3GpJOVhBHvJ5e`
3. Look for **"Android app"** configuration section
4. Add **all three package names**:
   - `com.example.familyhub_mvp.dev`
   - `com.example.familyhub_mvp.test`
   - `com.example.familyhub_mvp`
5. Add SHA-1 fingerprint: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
6. Save

### Option 2: Create Separate Keys (If Option 1 Doesn't Work)

If the console doesn't allow multiple package names on one key:
1. Create **three separate reCAPTCHA keys** (one per flavor)
2. I'll update the code to use different keys per flavor

## How to Test

1. Run with qa flavor: `flutter run --flavor qa`
2. Check logs for: `Package: com.example.familyhub_mvp.test`
3. Try logging in
4. Check if reCAPTCHA initializes successfully

## Current Status

- ✅ Code is flavor-aware (logs package name)
- ⚠️ Need to configure Google Cloud Console for all three package names
- ✅ Same site key can work for all if configured correctly

## Next Steps

1. Check Google Cloud Console to see if you can add multiple package names to one key
2. If yes → Add all three package names
3. If no → Tell me and I'll implement separate keys per flavor

The code is ready - it just needs the console configuration to match all three flavors.

