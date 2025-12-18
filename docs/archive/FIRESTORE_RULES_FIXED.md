# Fixed Firestore Security Rules

The current rules are blocking the family invitation feature. Update your Firestore security rules to allow users to verify invitation codes.

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
      // Users can read/write their own data
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Users can read other users' documents (needed to verify familyId for invitations)
      // But only the familyId field is needed, so we allow read access
      allow read: if request.auth != null;
    }
    
    // Family data - authenticated users can read/write their family data
    match /families/{familyId}/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

6. Click **Publish**

## What Changed

- **Before**: Users could only read their own user document
- **After**: Users can read any user document (to verify familyId exists for invitations)
- **Security**: Users can still only write to their own user document

## Why This Is Needed

When a user joins a family by invitation code:
1. The app needs to verify the invitation code (familyId) exists
2. It queries the `users` collection to find a user with that familyId
3. The old rules blocked this query, causing "permission denied" errors

## Test After Updating

1. **Refresh your Flutter app** (hot restart: `R` in terminal)
2. Try the invitation flow again
3. The permission errors should be resolved

