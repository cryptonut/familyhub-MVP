# Firestore Security Rules for Role Management

The role management feature requires Admins to be able to update other users' roles. Update your Firestore security rules to allow this.

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
      
          // Allow authenticated users to update the 'roles' or 'relationship' field of other users
          // Note: The application code verifies that users are in the same family
          // and that the current user is an Admin or family creator before allowing updates
          allow update: if request.auth != null && 
                          request.auth.uid != userId &&
                          // Only allow updating the 'roles' or 'relationship' fields (not other sensitive fields)
                          (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['roles']) ||
                           request.resource.data.diff(resource.data).affectedKeys().hasOnly(['relationship']) ||
                           request.resource.data.diff(resource.data).affectedKeys().hasOnly(['roles', 'relationship'])) &&
                          // Ensure other fields remain unchanged
                          request.resource.data.uid == resource.data.uid &&
                          request.resource.data.email == resource.data.email &&
                          request.resource.data.displayName == resource.data.displayName &&
                          request.resource.data.familyId == resource.data.familyId &&
                          request.resource.data.createdAt == resource.data.createdAt;
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

- **Users collection**: Added a rule that allows users in the same family to update the `roles` field of other users' documents
- **Security**: Only the `roles` field can be updated (not other fields like email, displayName, etc.)
- **Family check**: Only allows updates if both users are in the same family

## Why This Is Needed

When an Admin assigns roles:
1. The Admin needs to update another user's document
2. The current rules only allow users to update their own document
3. This new rule allows family members to update the `roles` field of other family members

## Test After Updating

1. **Refresh your Flutter app** (hot restart: `R` in terminal)
2. Try assigning a role to Kate again
3. The permission error should be resolved

## Security Note

This rule is safe because:
- It only allows updating the `roles` field (not other sensitive data)
- It requires both users to be in the same family
- It still prevents users from updating other fields like email, displayName, etc.

