# Firebase Storage Rules - Debug Version

Use these rules to test step by step. Start with the simplest version and work up.

## Step 1: Test Basic Authentication (Copy this first)

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow all authenticated users to upload photos (for testing only)
    match /photos/{familyId}/{photoId} {
      allow read, write: if request.auth != null;
    }
    match /thumbnails/{familyId}/{photoId} {
      allow read, write: if request.auth != null;
    }
    match /families/{familyId}/voice_messages/{fileName} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**If this works**, the issue is with the family membership check. Move to Step 2.

**If this doesn't work**, the issue is with authentication itself.

## Step 2: Test Family Membership Check

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function to check if user document exists
    function userDocumentExists() {
      return request.auth != null && 
        exists(/databases/(default)/documents/users/$(request.auth.uid));
    }
    
    // Helper function to get user's family ID
    function getUserFamilyId() {
      return userDocumentExists() && 
        'familyId' in get(/databases/(default)/documents/users/$(request.auth.uid)).data ?
        get(/databases/(default)/documents/users/$(request.auth.uid)).data.familyId :
        null;
    }
    
    // Helper function to check if user belongs to a family
    function belongsToFamily(familyId) {
      return request.auth != null && 
        userDocumentExists() &&
        getUserFamilyId() != null &&
        getUserFamilyId() is string &&
        getUserFamilyId() == familyId;
    }
    
    match /photos/{familyId}/{photoId} {
      allow read, write: if belongsToFamily(familyId);
    }
    
    match /thumbnails/{familyId}/{photoId} {
      allow read, write: if belongsToFamily(familyId);
    }
    
    match /families/{familyId}/voice_messages/{fileName} {
      allow read, write: if belongsToFamily(familyId);
    }
  }
}
```

**If Step 1 worked but Step 2 doesn't**, the issue is:
- User document doesn't exist in Firestore
- User document doesn't have a `familyId` field
- The `familyId` in the storage path doesn't match the user's `familyId`

## Step 3: Check Your User Document

1. Go to Firebase Console → Firestore Database → Data
2. Navigate to `users/{yourUserId}`
3. Verify:
   - The document exists
   - It has a `familyId` field
   - The `familyId` value matches what's being used in the storage path

## Step 4: Final Secure Rules (Once Step 2 works)

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    function userDocumentExists() {
      return request.auth != null && 
        exists(/databases/(default)/documents/users/$(request.auth.uid));
    }
    
    function getUserFamilyId() {
      return userDocumentExists() && 
        'familyId' in get(/databases/(default)/documents/users/$(request.auth.uid)).data ?
        get(/databases/(default)/documents/users/$(request.auth.uid)).data.familyId :
        null;
    }
    
    function belongsToFamily(familyId) {
      return request.auth != null && 
        userDocumentExists() &&
        getUserFamilyId() != null &&
        getUserFamilyId() is string &&
        getUserFamilyId() == familyId;
    }
    
    match /photos/{familyId}/{photoId} {
      allow read: if belongsToFamily(familyId);
      allow write: if belongsToFamily(familyId);
      allow delete: if belongsToFamily(familyId);
    }
    
    match /thumbnails/{familyId}/{photoId} {
      allow read: if belongsToFamily(familyId);
      allow write: if belongsToFamily(familyId);
      allow delete: if belongsToFamily(familyId);
    }
    
    match /families/{familyId}/voice_messages/{fileName} {
      allow read: if belongsToFamily(familyId);
      allow write: if belongsToFamily(familyId);
      allow delete: if belongsToFamily(familyId);
    }
    
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

