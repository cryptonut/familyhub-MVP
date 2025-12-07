# Firestore Rules Fix - Admin Job Deletion

## Issue
Admin users (like Simon Case) cannot delete active jobs even though they have full administrative privileges. The Firestore rules only allow the job creator to delete tasks.

## Fix
Updated the Firestore rules to allow admins to delete any job, similar to how admins can delete events.

## Changes Made

### 1. Added Admin Helper Function
Added a global `isAdmin()` helper function to check if a user has admin role:

```javascript
// Helper function to check if user is Admin (safely handles missing document)
function isAdmin() {
  return isAuthenticated() && 
    userDocumentExists() &&
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['admin', 'Admin']);
}
```

### 2. Updated Task Delete Rule
Modified the task delete rule to allow both creators and admins:

**Before:**
```javascript
allow delete: if belongsToFamily(familyId) && 
  resource.data.createdBy == request.auth.uid;
```

**After:**
```javascript
allow delete: if belongsToFamily(familyId) && 
  (resource.data.createdBy == request.auth.uid ||
   // Allow admin to delete any job for cleanup/admin operations
   isAdmin());
```

## How to Deploy

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click **Firestore Database** in the left sidebar
4. Click on the **Rules** tab
5. Copy the updated rules from `firestore.rules` file
6. Replace ALL existing rules
7. Click **Publish**

## What This Fixes

- **Admin users can now delete any job** in their family, not just jobs they created
- **Maintains security**: Non-admin users can still only delete their own jobs
- **Consistent with events**: Same permission pattern as event deletion (admins can delete events)
- **Enables cleanup operations**: Admins can clean up duplicate or problematic jobs

## Testing

After deploying:
1. Log in as an admin user (Simon Case)
2. Navigate to Jobs screen
3. Try to delete an active job created by another user
4. Deletion should now work successfully

## Security Notes

- Only users with 'admin' or 'Admin' role can delete jobs they didn't create
- Users must still belong to the family (enforced by `belongsToFamily()`)
- Regular users can only delete jobs they created (original behavior preserved)

