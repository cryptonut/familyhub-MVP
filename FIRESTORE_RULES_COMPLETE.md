# Complete Firestore Security Rules

This file contains all the Firestore security rules needed for the Family Hub MVP application.

## How to Deploy

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click **Firestore Database** in the left sidebar
4. Click on the **Rules** tab
5. Replace ALL existing rules with the rules below
6. Click **Publish**

## Complete Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to get user's family ID
    function getUserFamilyId() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.familyId;
    }
    
    // Helper function to check if user belongs to a family
    function belongsToFamily(familyId) {
      return isAuthenticated() && getUserFamilyId() == familyId;
    }
    
    // Helper function to check if user is Banker or Admin
    function isBankerOrAdmin() {
      return isAuthenticated() && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles.hasAny(['banker', 'admin']);
    }
    
    // Users collection - users can read/write their own data
    match /users/{userId} {
      allow read: if isAuthenticated() && request.auth.uid == userId;
      allow write: if isAuthenticated() && request.auth.uid == userId;
      
      // Allow Bankers/Admins to update roles field of other users in their family
      allow update: if isAuthenticated() && 
        request.auth.uid == userId ||
        (isBankerOrAdmin() && 
         belongsToFamily(resource.data.familyId) &&
         request.resource.data.diff(resource.data).affectedKeys().hasOnly(['roles']));
    }
    
    // Family collections - tasks, events, messages, etc.
    match /families/{familyId} {
      // Allow read if user belongs to the family
      allow read: if belongsToFamily(familyId);
      
      // Tasks subcollection
      match /tasks/{taskId} {
        allow read: if belongsToFamily(familyId);
        allow create: if belongsToFamily(familyId) && 
          request.resource.data.createdBy == request.auth.uid;
        allow update: if belongsToFamily(familyId) && 
          (resource.data.createdBy == request.auth.uid ||
           resource.data.claimedBy == request.auth.uid ||
           resource.data.assignedTo == request.auth.uid);
        allow delete: if belongsToFamily(familyId) && 
          resource.data.createdBy == request.auth.uid;
      }
      
      // Calendar events subcollection
      match /events/{eventId} {
        allow read: if belongsToFamily(familyId);
        allow write: if belongsToFamily(familyId);
      }
      
      // Chat messages subcollection
      match /messages/{messageId} {
        allow read: if belongsToFamily(familyId);
        allow create: if belongsToFamily(familyId) && 
          request.resource.data.senderId == request.auth.uid;
        allow update: if belongsToFamily(familyId) && 
          resource.data.senderId == request.auth.uid;
        allow delete: if belongsToFamily(familyId) && 
          resource.data.senderId == request.auth.uid;
      }
      
      // Payout requests subcollection
      match /payoutRequests/{requestId} {
        allow create: if belongsToFamily(familyId) && 
          request.resource.data.userId == request.auth.uid &&
          request.resource.data.status == 'pending' &&
          request.resource.data.amount is number &&
          request.resource.data.amount > 0;
        allow read: if belongsToFamily(familyId) && 
          (resource.data.userId == request.auth.uid || isBankerOrAdmin());
        allow update: if belongsToFamily(familyId) && 
          isBankerOrAdmin() &&
          resource.data.userId == request.resource.data.userId &&
          resource.data.amount == request.resource.data.amount;
        allow delete: if false; // No delete (keep for history)
      }
      
      // Approved payouts subcollection
      match /payouts/{payoutId} {
        allow create: if belongsToFamily(familyId) && isBankerOrAdmin() &&
          request.resource.data.userId is string &&
          request.resource.data.amount is number &&
          request.resource.data.amount > 0;
        allow read: if belongsToFamily(familyId) && 
          (resource.data.userId == request.auth.uid || isBankerOrAdmin());
        allow update: if false; // Immutable records
        allow delete: if false; // Immutable records
      }
      
      // Recurring payments subcollection
      match /recurringPayments/{paymentId} {
        allow create: if belongsToFamily(familyId) && isBankerOrAdmin() &&
          request.resource.data.fromUserId == request.auth.uid &&
          request.resource.data.toUserId is string &&
          request.resource.data.amount is number &&
          request.resource.data.amount > 0 &&
          request.resource.data.frequency in ['weekly', 'monthly'] &&
          request.resource.data.isActive == true;
        allow read: if belongsToFamily(familyId) && 
          (resource.data.toUserId == request.auth.uid || 
           resource.data.fromUserId == request.auth.uid ||
           isBankerOrAdmin());
        allow update: if belongsToFamily(familyId) && isBankerOrAdmin() &&
          resource.data.fromUserId == request.resource.data.fromUserId &&
          resource.data.toUserId == request.resource.data.toUserId &&
          resource.data.amount == request.resource.data.amount &&
          resource.data.frequency == request.resource.data.frequency;
        allow delete: if false; // Keep for history
      }
      
      // Pocket money payments subcollection
      match /pocketMoneyPayments/{paymentRecordId} {
        allow create: if belongsToFamily(familyId) && isBankerOrAdmin() &&
          request.resource.data.fromUserId is string &&
          request.resource.data.toUserId is string &&
          request.resource.data.amount is number &&
          request.resource.data.amount > 0;
        allow read: if belongsToFamily(familyId) && 
          (resource.data.toUserId == request.auth.uid || 
           resource.data.fromUserId == request.auth.uid ||
           isBankerOrAdmin());
        allow update: if false; // Immutable records
        allow delete: if false; // Immutable records
      }
      
      // Family wallet document
      match /wallet/{walletId} {
        allow read: if belongsToFamily(familyId);
        allow write: if belongsToFamily(familyId) && isBankerOrAdmin();
      }
      
      // Notifications subcollection
      match /notifications/{notificationId} {
        allow read: if belongsToFamily(familyId) && 
          resource.data.userId == request.auth.uid;
        allow create: if belongsToFamily(familyId);
        allow update: if belongsToFamily(familyId) && 
          resource.data.userId == request.auth.uid;
        allow delete: if belongsToFamily(familyId) && 
          resource.data.userId == request.auth.uid;
      }
      
      // Hubs subcollection
      match /hubs/{hubId} {
        allow read: if belongsToFamily(familyId);
        allow create: if belongsToFamily(familyId) && 
          request.resource.data.createdBy == request.auth.uid;
        allow update: if belongsToFamily(familyId) && 
          (resource.data.createdBy == request.auth.uid ||
           resource.data.members.hasAny([request.auth.uid]));
        allow delete: if belongsToFamily(familyId) && 
          resource.data.createdBy == request.auth.uid;
      }
      
      // Hub invites subcollection
      match /hubInvites/{inviteId} {
        allow read: if belongsToFamily(familyId);
        allow create: if belongsToFamily(familyId);
        allow update: if belongsToFamily(familyId);
        allow delete: if belongsToFamily(familyId);
      }
    }
    
    // Notifications collection (top-level, for backward compatibility)
    match /notifications/{notificationId} {
      allow read: if isAuthenticated() && resource.data.userId == request.auth.uid;
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && resource.data.userId == request.auth.uid;
      allow delete: if isAuthenticated() && resource.data.userId == request.auth.uid;
    }
    
    // Hubs collection (top-level, for backward compatibility)
    match /hubs/{hubId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && request.resource.data.createdBy == request.auth.uid;
      allow update: if isAuthenticated() && 
        (resource.data.createdBy == request.auth.uid ||
         resource.data.members.hasAny([request.auth.uid]));
      allow delete: if isAuthenticated() && resource.data.createdBy == request.auth.uid;
    }
    
    // Hub invites collection (top-level, for backward compatibility)
    match /hubInvites/{inviteId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update: if isAuthenticated();
      allow delete: if isAuthenticated();
    }
  }
}
```

## Important Notes

1. **Family Membership Check**: The rules use `belongsToFamily(familyId)` to ensure users can only access data from their own family.

2. **Tasks**: Users can read all tasks in their family, but can only create/update/delete tasks they created or are assigned to.

3. **Banker/Admin Privileges**: Bankers and Admins have additional permissions for:
   - Updating user roles
   - Approving/rejecting payout requests
   - Creating recurring payments
   - Managing family wallet

4. **Indexes Required**: Some queries may require composite indexes. If you see index errors, create them in the Firebase Console under Firestore > Indexes.

## Common Indexes Needed

If you get index errors, create these composite indexes:

1. **Tasks by familyId and createdAt**:
   - Collection: `families/{familyId}/tasks`
   - Fields: `createdAt` (Descending)

2. **Payout requests by status and createdAt**:
   - Collection: `families/{familyId}/payoutRequests`
   - Fields: `status` (Ascending), `createdAt` (Ascending)

3. **Notifications by userId, type, and createdAt**:
   - Collection: `notifications`
   - Fields: `userId` (Ascending), `type` (Ascending), `createdAt` (Descending)

## Testing

After deploying these rules:
1. Refresh your Flutter app (hot restart: `R` in terminal)
2. Try loading tasks - they should load now
3. Try creating a task - it should work
4. Test payout requests and recurring payments

