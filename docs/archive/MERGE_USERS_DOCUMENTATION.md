# Merge Users Feature Documentation

## Overview

The Merge Users feature allows administrators to merge two user accounts into one. This is useful for resolving duplicate accounts, consolidating user data, or fixing account issues.

## Access

- **Location**: Developer Menu → Merge Users
- **Access Level**: Available to all Admin users
- **Screen**: `lib/screens/admin/merge_users_screen.dart`

## Features

1. **Load Two Users**: Enter two user IDs to compare and merge
2. **Select UID to Keep**: Choose which user ID will be preserved (the other will be deleted)
3. **Field-by-Field Selection**: Choose which user's value to use for each field
4. **Automatic Role Merging**: Roles from both users are automatically combined
5. **Notification Updates**: All notifications are automatically updated to point to the kept user
6. **Real-time Logging**: See detailed logs of the merge process

## How to Use

### Step 1: Access the Feature

1. Open the app and navigate to the home screen
2. Open the menu (hamburger menu or drawer)
3. Select **"Developer Menu"** (available to all Admins)
4. Select **"Merge Users"**

### Step 2: Enter User IDs

1. Enter the first user ID in the **"User ID 1"** field
2. Enter the second user ID in the **"User ID 2"** field
3. Click **"Load Users"** to fetch both user documents
4. Wait for both users to load (you'll see their display names and emails)

### Step 3: Select UID to Keep

- Choose which user ID will be preserved
- The selected UID will become the merged user's ID
- The other user ID will be deleted after the merge

### Step 4: Select Field Values

For each field, choose which user's value to use:

- **Email**: Select which email address to keep
- **Display Name**: Select which display name to use
- **Photo URL**: Select which photo URL to keep
- **Family ID**: Select which family ID to use
- **Relationship**: Select which relationship value to keep
- **Birthday**: Select which birthday to use
- **Birthday Notifications**: Select which setting to use
- **Calendar Sync**: Select which calendar sync settings to keep
- **Local Calendar ID**: Select which local calendar ID to use
- **Google Calendar ID**: Select which Google calendar ID to use
- **Location Permission**: Select which location permission setting to use

**Note**: Roles are automatically merged - all roles from both users will be combined.

### Step 5: Review and Merge

1. Review all your selections
2. Click **"Merge Users"**
3. Confirm the merge in the warning dialog
4. Wait for the merge to complete
5. Review the merge log for details

## What Gets Merged

### User Document Fields

All fields in the user document can be individually selected:
- `uid` (determined by which UID you choose to keep)
- `email`
- `displayName`
- `photoUrl`
- `familyId`
- `relationship`
- `birthday`
- `birthdayNotificationsEnabled`
- `calendarSyncEnabled`
- `localCalendarId`
- `googleCalendarId`
- `lastSyncedAt`
- `locationPermissionGranted`
- `roles` (automatically merged - union of both users' roles)
- `createdAt` (uses the earlier date from both users)

### Automatic Updates

The merge process automatically:
1. **Updates Notifications**: All notifications with `userId` matching the deleted user are updated to point to the kept user
2. **Deletes Old User**: The user document for the deleted UID is removed from Firestore
3. **Preserves Data**: All selected field values are merged into the kept user document

## Important Notes

### ⚠️ Irreversible Action

- **This action cannot be undone**
- The deleted user document is permanently removed
- Make sure you've selected the correct UID to keep before confirming

### ⚠️ Firebase Auth Accounts

- **This feature only merges Firestore user documents**
- **Firebase Auth accounts are NOT merged automatically**
- If you need to merge Firebase Auth accounts, you must:
  1. Delete the Firebase Auth account for the user you're removing (via Firebase Console)
  2. Or keep both Auth accounts and let users sign in with either email

### ⚠️ Related Data

The merge process handles:
- ✅ User document fields
- ✅ Notifications (automatically updated)
- ❌ Family data (not affected - familyId is preserved)
- ❌ Tasks, Events, Messages (not moved - they remain associated with the familyId)
- ❌ Photos, Calendar events, etc. (not moved - they remain in the family)

### Best Practices

1. **Backup First**: Consider exporting user data before merging
2. **Verify User IDs**: Double-check both user IDs before loading
3. **Review Field Values**: Carefully review each field selection
4. **Check Family Impact**: Ensure the kept user's familyId is correct
5. **Test in Dev**: Test the merge process in a development environment first

## Technical Details

### Implementation

- **Service**: Uses `AuthService` and `FirebaseFirestore` directly
- **Location**: `lib/screens/admin/merge_users_screen.dart`
- **Dependencies**: 
  - `cloud_firestore` for database operations
  - `auth_service.dart` for user model handling

### Merge Process Flow

1. Load both user documents from Firestore
2. Display user data for comparison
3. Allow field-by-field selection
4. Build merged user document with selected values
5. Update user document in Firestore
6. Update all notifications to point to kept user
7. Delete old user document
8. Log all operations

### Error Handling

- Validates that both user IDs are provided
- Ensures user IDs are different
- Checks that both users exist before merging
- Provides detailed error messages if merge fails
- Logs all operations for debugging

## Troubleshooting

### "User not found" Error

- Verify both user IDs are correct
- Ensure both users exist in Firestore
- Check that you have permission to read user documents

### "Permission denied" Error

- Ensure you have Admin role
- Verify Firestore security rules allow user document updates
- Check that you have permission to delete user documents

### Merge Fails Partway Through

- Check the merge log for specific error details
- Verify network connectivity
- Ensure Firestore is accessible
- Check Firebase Console for any service issues

## Related Features

- **Delete User**: Use this feature to completely remove a user (Admin Menu → Delete User)
- **Fix Family Link**: Use this to fix family associations (Developer Menu → Fix Family Link)
- **Role Management**: Manage user roles (Admin Menu → Manage Roles)

## Support

For issues or questions:
1. Check the merge log for detailed error messages
2. Review Firestore security rules
3. Verify Firebase Console for service status
4. Check app logs for additional debugging information


