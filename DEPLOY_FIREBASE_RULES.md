# Deploy Firebase & Firestore Rules

This guide will help you deploy the latest Firestore and Storage rules to Firebase.

## Current Status

✅ **Firestore Rules:** Complete and up-to-date in `firestore.rules`
✅ **Storage Rules:** Complete and up-to-date in `storage.rules`
✅ **Includes all fixes:** Admin delete, chess games, profile photos, event templates, etc.

---

## Method 1: Deploy via Firebase Console (Recommended - No CLI Needed)

### Deploy Firestore Rules:

1. **Open Firebase Console:**
   - Go to: https://console.firebase.google.com/
   - Select your Firebase project

2. **Navigate to Firestore Rules:**
   - Click **Firestore Database** in left sidebar
   - Click on **Rules** tab

3. **Copy Rules:**
   - Open `firestore.rules` file in this project
   - Select all content (Ctrl+A) and copy (Ctrl+C)

4. **Paste Rules:**
   - In Firebase Console, delete all existing rules
   - Paste the copied rules

5. **Publish:**
   - Click **Publish** button
   - Wait for confirmation

### Deploy Storage Rules:

1. **Navigate to Storage Rules:**
   - Click **Storage** in left sidebar
   - Click on **Rules** tab

2. **Copy Rules:**
   - Open `storage.rules` file in this project
   - Select all content (Ctrl+A) and copy (Ctrl+C)

3. **Paste Rules:**
   - In Firebase Console, delete all existing rules
   - Paste the copied rules

4. **Publish:**
   - Click **Publish** button
   - Wait for confirmation

---

## Method 2: Deploy via Firebase CLI (If Installed)

### Install Firebase CLI (if not installed):

```powershell
npm install -g firebase-tools
```

### Login to Firebase:

```powershell
firebase login
```

### Deploy Rules:

```powershell
# Deploy both Firestore and Storage rules
firebase deploy --only firestore:rules,storage:rules

# Or deploy individually:
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
```

---

## What's Included in These Rules

### Firestore Rules Include:

✅ **User Authentication & Authorization**
- Users can read/write their own data
- Family-based access control
- Admin/Banker role permissions

✅ **Tasks/Jobs:**
- Admin can delete any task (fix applied)
- Family members can complete open tasks
- Proper claim/assignment handling

✅ **Calendar Events:**
- Family collaboration on events
- Admin cleanup permissions
- Event-specific chat

✅ **Chat & Messaging:**
- Family messages
- Private messages
- Message reactions
- Message replies (threading)

✅ **Games:**
- Chess games collection
- Chess matchmaking queue
- Game stats
- Proper player access control

✅ **Photos:**
- Photo albums
- Photo comments
- Family-based access

✅ **Shopping:**
- Shopping lists
- Shopping items
- Shopping categories
- Shopping receipts

✅ **Wallet & Payments:**
- Payout requests
- Recurring payments
- Pocket money payments
- Banker/Admin controls

✅ **Hubs:**
- Hub creation and management
- Hub invites
- Hub messages

✅ **Other Features:**
- Event templates
- Location requests
- Notifications
- Video calls
- Privacy activity tracking

### Storage Rules Include:

✅ **Profile Photos:**
- Path: `profile_photos/{userId}/{photoId}.jpg`
- Users can upload/delete their own profile photos
- All authenticated users can read (for family visibility)

✅ **Event Photos:**
- Path: `eventPhotos/{familyId}/{eventId}/{photoId}`
- Authenticated family members only

✅ **Album Photos:**
- Path: `photos/{familyId}/{photoId}`
- Authenticated family members only

✅ **Thumbnails:**
- Path: `thumbnails/{familyId}/{photoId}`
- Authenticated family members only

✅ **Voice Messages:**
- Path: `families/{familyId}/voice_messages/{fileName}`
- Authenticated family members only

---

## Verification

After deploying:

1. **Test Firestore Access:**
   - Try creating a task
   - Try deleting a task as admin
   - Try accessing family data

2. **Test Storage Access:**
   - Try uploading a profile photo
   - Try viewing photos
   - Check for permission errors

3. **Check Rules Status:**
   - In Firebase Console → Firestore → Rules, verify "Last published" shows recent date
   - In Firebase Console → Storage → Rules, verify "Last published" shows recent date

---

## Troubleshooting

**If rules don't seem to apply:**
1. Wait 1-2 minutes (rules can take time to propagate)
2. Force close and restart your app
3. Check Firebase Console for any rule syntax errors
4. Verify you're authenticated as the correct user

**If you get permission errors:**
1. Check that rules were published successfully
2. Verify user is authenticated (`request.auth != null`)
3. Check that user belongs to the family (`belongsToFamily()` check)
4. Verify user role if admin permissions are needed

---

## Quick Deploy Script

If you want to create a script to open the rules files for easy copy-paste:

**Create `open_rules_for_deploy.ps1`:**
```powershell
# Open rules files in default editor for easy copy-paste
notepad firestore.rules
notepad storage.rules
```

Then:
1. Run the script
2. Copy each file's contents
3. Paste into Firebase Console
4. Publish

---

**Last Updated:** December 10, 2025  
**Rules Version:** Complete with all fixes and features

