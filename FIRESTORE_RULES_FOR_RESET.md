# Firestore Security Rules for Database Reset

The database reset feature requires additional permissions to delete data. Update your Firestore security rules to allow users to delete their own data.

## Updated Security Rules

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click **Firestore Database** in the left sidebar
4. Click on the **Rules** tab
5. Replace the existing rules with the following:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Users can read/write their own data (including delete)
      allow read, write, delete: if request.auth != null && request.auth.uid == userId;
      
      // Users can read other users' documents (needed to verify familyId for invitations)
      allow read: if request.auth != null;
    }
    
    // Family data - authenticated users can read/write/delete their family data
    match /families/{familyId}/{document=**} {
      allow read, write, delete: if request.auth != null;
    }
    
    // Family wallet documents
    match /families/{familyId} {
      allow read, write, delete: if request.auth != null;
    }
    
    // Notifications collection - users can delete their own notifications
    match /notifications/{notificationId} {
      allow read, write, delete: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
  }
}
```

6. Click **Publish**

## What Changed

- **Users collection**: Explicitly allows `delete` operation for own user document
- **Family data**: Explicitly allows `delete` operation for family collections
- **Family wallet**: Added explicit rule for family wallet documents
- **Notifications**: Added rules to allow users to delete their own notifications

## Why This Is Needed

The database reset feature needs to:
1. Delete the user's own document from `users` collection
2. Delete all documents in family subcollections (tasks, events, messages, etc.)
3. Delete the family wallet document
4. Delete user's notifications

Without these permissions, the reset will fail with "permission-denied" errors.

## Test After Updating

1. **Refresh your Flutter app** (hot restart: `R` in terminal)
2. Try the database reset feature again
3. The permission errors should be resolved

## Security Note

These rules allow authenticated users to delete their own data. This is safe for development/testing. For production, you may want to add additional checks to ensure users can only delete data from their own family.

