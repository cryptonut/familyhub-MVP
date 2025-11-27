# Quick Decision: What to Do with Application Restrictions

## You Have Two Options

### Option 1: Keep "None" (Easiest for Testing)
**Pros:**
- No SHA-1 to manage
- Works immediately
- Good for development/testing

**Steps:**
1. Keep "None" selected
2. Click "Save"
3. Wait 2-3 minutes
4. In app: Menu > "Refresh Session"
5. Sign back in
6. Test if Firestore works

**If this works:** The issue was the application restriction blocking requests.

### Option 2: Set "Android apps" with SHA-1 (More Secure)
**Pros:**
- More secure for production
- Restricts key to your specific app

**Steps:**
1. Select "Android apps" radio button
2. Click "Add an item"
3. Enter:
   - Package: `com.example.familyhub_mvp`
   - SHA-1: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`
4. Click "Save"
5. Wait 2-3 minutes
6. In app: Menu > "Refresh Session"
7. Sign back in

## My Recommendation

**Try Option 1 first** (keep "None"):
- Quickest test
- If Firestore works with "None", we know the issue was application restrictions
- Then you can add the Android apps restriction properly

## After Either Option

1. **Save** the API key
2. **Wait 2-3 minutes** for propagation
3. **Use "Refresh Session"** in the app (Menu > Refresh Session)
4. **Sign back in**
5. **Check if dashboard loads with data**

The "Refresh Session" option I added will force a fresh connection attempt after the restrictions are updated.

