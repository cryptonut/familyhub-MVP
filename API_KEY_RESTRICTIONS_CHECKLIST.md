# API Key Restrictions Checklist

## What You're Seeing
✅ Cloud Firestore API enabled (150 requests)
✅ Identity Toolkit API enabled (32 requests)
❌ But Firestore still unavailable on Android

## The Issue
APIs are enabled for the **project**, but the **API key** might have restrictions.

## Step-by-Step Check

### 1. Open the Android Key for Editing
- From Credentials page, **click** (don't just view) the Android key
- Look for: `AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4`
- Click the **pencil/edit icon** or click the key name

### 2. Check "API restrictions"
Look for this section. It will show either:
- **"Don't restrict key"** ✅ (allows all APIs)
- **"Restrict key"** with a list of APIs

If it's restricted, the list should include:
- ✅ Identity Toolkit API (for Auth - already working)
- ✅ **Cloud Firestore API** (for Firestore - needs to be here!)

If Cloud Firestore API is **NOT** in the list, that's the problem!

### 3. Check "Application restrictions"
Should be one of:
- **"None"** ✅ (for development)
- **"Android apps"** with `com.example.familyhub_mvp` + SHA-1
- ❌ **NOT "HTTP referrers"** (blocks Android)

### 4. How to Fix

If Cloud Firestore API is missing from API restrictions:

**Option A: For Development (Easiest)**
1. Click "Edit API key"
2. Under "API restrictions", select **"Don't restrict key"**
3. Click "Save"
4. Wait 1-2 minutes

**Option B: Keep Restrictions (More Secure)**
1. Click "Edit API key"
2. Under "API restrictions", select "Restrict key"
3. Click in the API list field
4. Search for and add "Cloud Firestore API"
5. Make sure both are checked:
   - Identity Toolkit API
   - Cloud Firestore API
6. Click "Save"
7. Wait 1-2 minutes

### 5. Test
After saving:
1. Wait 1-2 minutes for changes to propagate
2. In the app, use "Refresh Session" (menu > Refresh Session)
3. Sign back in
4. Dashboard should now load with data

## Why This Happens
Firebase auto-creates keys with minimal restrictions. The Android key might have been created with only Identity Toolkit API allowed, which is why:
- ✅ Auth works (Identity Toolkit enabled)
- ❌ Firestore fails (Cloud Firestore not in key restrictions)

Let me know what the "API restrictions" section shows!

