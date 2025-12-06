# FIX: Add SHA-1 to DEV App

## The Problem

You're running with `--flavor dev`, which uses package: **`com.example.familyhub_mvp.dev`**

But the SHA-1 fingerprint is only added to: **`com.example.familyhub_mvp`**

## The Fix

### Step 1: Click on "FamilyHub Dev" App

In Firebase Console Project Settings:
1. In the "Android apps" list, click on **"FamilyHub Dev"** (the second one: `com.example.familyhub_mvp.dev`)
2. This will show its details panel

### Step 2: Add SHA-1 to Dev App

1. Scroll to **"SHA certificate fingerprints"** section
2. Click **"Add fingerprint"**
3. Paste: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
4. Click **"Save"**

### Step 3: Also Add to Test App (if needed)

If you use `--flavor qa` or `--flavor test`:
1. Click on **"FamilyHub Test"** (`com.example.familyhub_mvp.test`)
2. Add the same SHA-1 fingerprint

## Why This Matters

- Each flavor has a **different package name**
- Each package name needs its **own SHA-1 fingerprint** in Firebase
- `develop` branch with `--flavor dev` uses `com.example.familyhub_mvp.dev`
- That app doesn't have SHA-1 → Firebase Auth can't verify it → "empty reCAPTCHA token"

## After Adding SHA-1

1. Wait 2-3 minutes
2. Rebuild: `flutter clean && flutter pub get && flutter run --flavor dev --dart-define=FLAVOR=dev`
3. Login should work!

---

**This is why `release/qa` works (different flavor/app) but `develop` with dev flavor doesn't!**

