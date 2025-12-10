# Deploy Firestore Rules via Firebase Console

Since the Firebase CLI may be caching, here's how to deploy directly via the console:

## Steps:

1. **Open Firebase Console:**
   - Go to: https://console.firebase.google.com/project/family-hub-71ff0/firestore/rules

2. **Copy the rules from the file:**
   - The `firestore.rules` file is open in Notepad
   - Select ALL (Ctrl+A) and Copy (Ctrl+C)

3. **In Firebase Console:**
   - Delete ALL existing rules in the editor
   - Paste the copied rules (Ctrl+V)
   - Click **Publish** button
   - Wait for confirmation

4. **Verify:**
   - Look for "Last published" timestamp at the top
   - Search for "openMatchmakingEnabled" in the rules (Ctrl+F)
   - Should see it in the `families/{familyId}` update rule around line 90-93

## For Storage Rules:

1. Go to: https://console.firebase.google.com/project/family-hub-71ff0/storage/rules
2. Copy from `storage.rules` file
3. Paste and Publish
4. Check "Last published" timestamp

## What to Look For:

In the `families/{familyId}` section, you should see:
```
allow update: if belongsToFamily(familyId) && (
  // Update walletBalance (existing rule)
  (request.resource.data.walletBalance is number && ...) ||
  // Update openMatchmakingEnabled (admin only)
  (isAdmin() &&
   request.resource.data.diff(resource.data).affectedKeys().hasOnly(['openMatchmakingEnabled']) &&
   request.resource.data.openMatchmakingEnabled is bool) ||
  ...
);
```

