# Firestore Security Rules for Hubs

The hubs feature requires permissions to create and manage hubs. Update your Firestore security rules to allow this.

## Updated Security Rules

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click **Firestore Database** in the left sidebar
4. Click on the **Rules** tab
5. Add the hubs rules to your existing rules (or replace with the complete rules below):

### Complete Rules (includes all previous rules + hubs):

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
    
    // Hubs collection - users can create, read, and manage their own hubs
    match /hubs/{hubId} {
      // Users can create hubs (they become the creator)
      allow create: if request.auth != null && 
                     request.resource.data.creatorId == request.auth.uid;
      
      // Users can read hubs they created or are members of
      allow read: if request.auth != null && 
                   (resource.data.creatorId == request.auth.uid || 
                    request.auth.uid in resource.data.memberIds);
      
      // Users can update hubs they created
      allow update: if request.auth != null && 
                     resource.data.creatorId == request.auth.uid;
      
      // Users can delete hubs they created
      allow delete: if request.auth != null && 
                     resource.data.creatorId == request.auth.uid;
    }
    
    // Hub invites collection - for email/SMS invites
    match /hubInvites/{inviteId} {
      // Hub creators can create invites
      allow create: if request.auth != null;
      
      // Anyone can read invites (needed to accept them)
      // But we'll verify the invite in the app code
      allow read: if true; // Public read for invite links
      
      // Users can update invites they created (to mark as accepted)
      // Also allow users to update invites sent to their email/phone
      allow update: if request.auth != null && 
                     (resource.data.inviterId == request.auth.uid ||
                      request.resource.data.userId == request.auth.uid);
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

### Just the Hubs Rules (if you want to add to existing rules):

```javascript
// Hubs collection - users can create, read, and manage their own hubs
match /hubs/{hubId} {
  // Users can create hubs (they become the creator)
  allow create: if request.auth != null && 
                 request.resource.data.creatorId == request.auth.uid;
  
  // Users can read hubs they created or are members of
  allow read: if request.auth != null && 
               (resource.data.creatorId == request.auth.uid || 
                request.auth.uid in resource.data.memberIds);
  
  // Users can update hubs they created
  allow update: if request.auth != null && 
                 resource.data.creatorId == request.auth.uid;
  
  // Users can delete hubs they created
  allow delete: if request.auth != null && 
                 resource.data.creatorId == request.auth.uid;
}
```

6. Click **Publish**

## What Changed

- **Hubs collection**: Added rules to allow users to:
  - Create hubs (where they are the creator)
  - Read hubs they created or are members of
  - Update hubs they created
  - Delete hubs they created

## Why This Is Needed

When creating a hub:
1. The user needs to create a document in the `hubs` collection
2. The user must be the creator (creatorId must match their user ID)
3. Users can only manage hubs they created
4. Users can read hubs they are members of (for viewing hub dashboards)

## Test After Updating

1. **Refresh your Flutter app** (hot restart: `R` in terminal)
2. Try creating a new hub
3. The permission error should be resolved

## Security Note

These rules ensure:
- Only authenticated users can create hubs
- Users can only create hubs where they are the creator
- Users can only read hubs they created or are members of
- Only hub creators can update or delete hubs

