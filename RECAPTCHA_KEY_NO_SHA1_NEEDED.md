# reCAPTCHA Key - SHA-1 Not Required

## What I See in Your Edit Page

✅ **Android package list** - Already has all 3 package names:
- `com.example.familyhub_mvp`
- `com.example.familyhub_mvp.dev`
- `com.example.familyhub_mvp.test`

✅ **Package name verification** - Can be enabled/disabled with toggle

❌ **No SHA-1 field** - This is correct! reCAPTCHA keys don't need SHA-1

## Why "Incomplete" Status?

The key shows "Incomplete" because:
- It has **never been used** (no tokens requested)
- The message says: "Request tokens (executes)"
- This means the key needs to actually be **used by your app** before it becomes "Active"

## What You Need to Do

### Option 1: Just Use the Key (Recommended)
1. **Click "Update key"** to save the current configuration
2. **Test login in your app** - this will request tokens
3. After first use, the key will become "Active"
4. The "Incomplete" status will disappear

### Option 2: Disable reCAPTCHA for Email/Password
If you don't want to use reCAPTCHA for email/password:
1. Go to **Firebase Console** → **Authentication** → **Settings** → **reCAPTCHA**
2. **Disable** reCAPTCHA for email/password authentication
3. This tells Firebase "don't use reCAPTCHA for email/password"

## The Real Issue

The "empty reCAPTCHA token" error happens because:
- Firebase Auth is trying to use reCAPTCHA
- The key exists but hasn't been used yet
- OR reCAPTCHA should be disabled for email/password

## Recommendation

**Try this:**
1. Click **"Update key"** on the edit page (save current config)
2. Go to **Firebase Console** → **Authentication** → **Settings** → **reCAPTCHA**
3. **Disable reCAPTCHA for email/password** (if that option exists)
4. OR just test login - the key will activate on first use

The SHA-1 is already configured in Firebase Console for your Android app - that's separate from reCAPTCHA keys.

