# Where to Add SHA-1 in reCAPTCHA Key Configuration

## Step-by-Step Location Guide

### Step 1: Click "Edit key"
On the reCAPTCHA key details page, click the **"Edit key"** button (top right, next to "Delete this key")

### Step 2: Find "Android app" Section
In the edit form, look for a section labeled:
- **"Android app"** or
- **"Android package names"** or
- **"App configuration"**

### Step 3: Add Package Name and SHA-1
In that section, you'll see fields for:
1. **Package name** field - Enter: `com.example.familyhub_mvp.dev`
2. **SHA-1 certificate fingerprint** field - Enter: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
3. **Enable package name verification** checkbox - Check this box

### Step 4: Add Multiple Package Names (If Supported)
If the form allows multiple entries, add:
- `com.example.familyhub_mvp.dev`
- `com.example.familyhub_mvp.test`
- `com.example.familyhub_mvp`

All with the same SHA-1: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`

## Is SHA-1 Already There?

**No, it's not automatically there.** You need to manually add it when editing the reCAPTCHA key.

The SHA-1 in `google-services.json` is for OAuth clients, not reCAPTCHA keys. They're separate configurations.

## What If You Don't See SHA-1 Field?

If the edit form doesn't show a SHA-1 field:
1. The key might be configured differently
2. You might need to use the "Integration" tab instead
3. Or you might need to configure it in Firebase Console instead

## Alternative: Configure in Firebase Console

If you can't find the SHA-1 field in Google Cloud Console:
1. Go to **Firebase Console** → **Authentication** → **Settings** → **reCAPTCHA**
2. Click **"Configure site keys"**
3. Edit the Android key there
4. Add package name and SHA-1

## Your SHA-1 Fingerprint

**Debug SHA-1 (for development):**
```
BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C
```

**Format:** You can enter it with or without colons:
- With colons: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
- Without colons: `BB7A6A5F57F1DD0DED142A5C6F2614FD54C3C71C`

Both formats work.

