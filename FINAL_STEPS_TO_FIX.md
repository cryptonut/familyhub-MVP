# Final Steps to Fix Firestore on Android

## ✅ Confirmed: API Restrictions Are Correct
- Cloud Firestore API is in the allowed list
- Identity Toolkit API is there
- 24 APIs total selected

## What to Check Now

### 1. Expand "Android apps" Section
Click on the "Android apps" section (it's selected but might be collapsed)
Verify it shows:
- **Package name**: `com.example.familyhub_mvp`
- **SHA-1 certificate fingerprint**: Should have a value

If SHA-1 is missing or wrong, that could block Android requests.

### 2. Save and Wait
- Click **"Save"** (blue button at bottom)
- Wait **2-3 minutes** for changes to propagate
- The note says "up to five minutes" but usually faster

### 3. Use "Refresh Session" in App
I added a new menu option specifically for this:

**In the Android app:**
1. Tap menu (three dots, top right)
2. Select **"Refresh Session"** (blue, with refresh icon)
3. Confirm "Sign Out & Refresh"
4. Sign back in with your credentials
5. This clears the persisted Auth session and forces fresh Firestore connection

### 4. What Should Happen
After Refresh Session:
- ✅ You'll see the login screen
- ✅ Sign in with your email/password
- ✅ Dashboard should load WITH data:
  - Family members (Kate, Lilly, you)
  - Wallet balance
  - Jobs/tasks
  - All your data

## If It Still Doesn't Work

Check the app logs for the exact error:
- Look for "Firestore error" messages
- Check the error code (unavailable, permission-denied, etc.)
- The enhanced logging I added will show exactly what's failing

The "Refresh Session" option is the key - it forces a completely fresh connection attempt after the API restrictions are saved.

