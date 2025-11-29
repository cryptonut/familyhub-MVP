# Fix: API Key Blocking Dev App

## The Error
```
AuthException(unknown): An internal error has occurred. 
[ Requests from this Android client application com.example.familyhub_mvp.dev are blocked.
```

## Root Cause
The API key `AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4` has **Application restrictions** that only allow the **prod** package name, not dev/test.

## Solution: Update API Key Restrictions

### Step 1: Go to Google Cloud Console
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **APIs & Services** → **Credentials** (left sidebar)

### Step 2: Find the Android API Key
1. Look for API key: `AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4`
   - It might show as truncated: `AIzaSyDLZ3...`
2. **Click on the key** to open edit page

### Step 3: Update Application Restrictions

**Option A: For Development (Easiest - Recommended)**
1. Under **"Application restrictions"**, select **"None"**
2. Click **"Save"**
3. Wait 2-3 minutes for propagation

**Option B: Add All Package Names (More Secure)**
1. Under **"Application restrictions"**, select **"Android apps"**
2. You should see one entry for prod:
   - Package: `com.example.familyhub_mvp`
   - SHA-1: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`
3. Click **"Add an item"** and add **Dev app:
   - Package: `com.example.familyhub_mvp.dev`
   - SHA-1: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`
4. Click **"Add an item"** again and add **Test app:
   - Package: `com.example.familyhub_mvp.test`
   - SHA-1: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`
5. Click **"Save"**
6. Wait 2-3 minutes for propagation

### Step 4: Verify API Restrictions
While you're there, check **"API restrictions"**:
- Should be **"Don't restrict key"** OR
- Should include: **Cloud Firestore API** and **Identity Toolkit API**

### Step 5: Test
After saving:
1. Wait 2-3 minutes
2. Try logging into dev app again
3. Should work now!

## Why This Happens
When you set up application restrictions with only the prod package name, Firebase blocks requests from dev/test apps because they have different package names. All three apps need to be in the allowed list, or restrictions need to be set to "None" for development.

