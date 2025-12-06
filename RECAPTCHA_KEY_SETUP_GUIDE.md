# reCAPTCHA Key Setup Guide - Complete Instructions

## Where to Add SHA-1 Fingerprint

### Step 1: Edit the Key
1. On the reCAPTCHA key details page, click **"Edit key"** button (top right)
2. This will open the key configuration

### Step 2: Add Android App Configuration
In the edit screen, you'll see:
- **App package name** field - Add your package name here
- **SHA-1 certificate fingerprint** field - Add your SHA-1 here

**For Dev Flavor:**
- Package name: `com.example.familyhub_mvp.dev`
- SHA-1: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`

**For QA/Test Flavor:**
- Package name: `com.example.familyhub_mvp.test`
- SHA-1: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C` (same SHA-1)

**For Prod Flavor:**
- Package name: `com.example.familyhub_mvp`
- SHA-1: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C` (same SHA-1)

### Step 3: Enable Package Name Verification
- Check the box to enable package name verification
- This ensures only your app can use this key

## Do You Need Separate Keys?

### Option A: One Key for All Flavors (Recommended)
You can add **multiple package names** to the same key:
- `com.example.familyhub_mvp.dev`
- `com.example.familyhub_mvp.test`
- `com.example.familyhub_mvp`

All with the same SHA-1 fingerprint.

**Advantages:**
- Simpler to manage
- One key to configure
- Works for all flavors

### Option B: Separate Keys for Each Flavor
Create separate keys:
- "FamilyHub Dev reCAPTCHA Key" → `com.example.familyhub_mvp.dev`
- "FamilyHub Test reCAPTCHA Key" → `com.example.familyhub_mvp.test`
- "FamilyHub Prod reCAPTCHA Key" → `com.example.familyhub_mvp`

**Advantages:**
- Better isolation
- Can disable one without affecting others
- More granular control

## Recommendation

**Use Option A (one key with multiple package names)** - simpler and works fine for your use case.

## Step-by-Step Instructions

1. **Click "Edit key"** on the reCAPTCHA key details page
2. **Find "Android app" or "Package names" section**
3. **Add package names:**
   - `com.example.familyhub_mvp.dev`
   - `com.example.familyhub_mvp.test`
   - `com.example.familyhub_mvp`
4. **Add SHA-1 fingerprint:** `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
5. **Enable package name verification**
6. **Save**

After saving, wait 1-2 minutes for changes to propagate, then test login.

