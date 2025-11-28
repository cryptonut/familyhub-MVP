# Complete Firebase Storage Security Rules

These rules allow authenticated family members to upload and download photos, thumbnails, and voice messages. The rules match the security pattern used in your Firestore rules and cover ALL storage paths used in the codebase.

## How to Deploy

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click **Storage** in the left sidebar
4. Click on the **Rules** tab
5. Replace ALL existing rules with the rules below
6. Click **Publish**

## Complete Storage Rules

**Current Working Version (Simple Auth):**
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow all authenticated users (basic security)
    match /photos/{familyId}/{photoId} {
      allow read, write, delete: if request.auth != null;
    }
    match /thumbnails/{familyId}/{photoId} {
      allow read, write, delete: if request.auth != null;
    }
    match /families/{familyId}/voice_messages/{fileName} {
      allow read, write, delete: if request.auth != null;
    }
  }
}
```

**Enhanced Version with Family Checks (Use once uploads are working):**
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user document exists
    function userDocumentExists() {
      return isAuthenticated() && 
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
      return isAuthenticated() && 
        userDocumentExists() &&
        getUserFamilyId() != null &&
        getUserFamilyId() == familyId;
    }
    
    // ============================================
    // PHOTOS STORAGE
    // Path: photos/{familyId}/{photoId}.jpg
    // ============================================
    match /photos/{familyId}/{photoId} {
      // Allow read if user belongs to the family
      allow read: if belongsToFamily(familyId);
      
      // Allow write (upload) if user belongs to the family
      // Note: customMetadata is accessed via metadata.customMetadata['key'] in Storage rules
      allow write: if belongsToFamily(familyId) && 
        (request.resource.metadata.customMetadata['uploadedBy'] == request.auth.uid ||
         request.resource.metadata.customMetadata.uploadedBy == request.auth.uid);
      
      // Allow delete if user uploaded the photo
      allow delete: if belongsToFamily(familyId) && 
        (resource.metadata.customMetadata['uploadedBy'] == request.auth.uid ||
         resource.metadata.customMetadata.uploadedBy == request.auth.uid);
    }
    
    // ============================================
    // THUMBNAILS STORAGE
    // Path: thumbnails/{familyId}/{photoId}.jpg
    // ============================================
    match /thumbnails/{familyId}/{photoId} {
      // Allow read if user belongs to the family
      allow read: if belongsToFamily(familyId);
      
      // Allow write (upload) if user belongs to the family
      // Thumbnails are created automatically with photos, so we allow writes
      // for family members (metadata may not always be set for thumbnails)
      allow write: if belongsToFamily(familyId);
      
      // Allow delete if user belongs to the family
      // (Thumbnails are deleted when photos are deleted)
      allow delete: if belongsToFamily(familyId);
    }
    
    // ============================================
    // VOICE MESSAGES STORAGE
    // Path: families/{familyId}/voice_messages/{fileName}
    // Used by: VoiceRecordingService.uploadVoiceMessage()
    // ============================================
    match /families/{familyId}/voice_messages/{fileName} {
      // Allow read if user belongs to the family
      allow read: if belongsToFamily(familyId);
      
      // Allow write (upload) if user belongs to the family
      // Voice messages are uploaded by authenticated family members
      allow write: if belongsToFamily(familyId) && 
        request.auth.uid != null;
      
      // Allow delete if user belongs to the family
      // (Users can delete their own voice messages)
      allow delete: if belongsToFamily(familyId);
    }
    
    // ============================================
    // DENY ALL OTHER PATHS
    // ============================================
    // Any other storage paths are denied by default
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## What These Rules Cover

### Storage Paths Used in Your Codebase:

1. **Photos** (`photos/{familyId}/{photoId}.jpg`)
   - Used by: `PhotoService.uploadPhoto()` and `PhotoService.uploadPhotoWeb()`
   - Permissions: Family members can read/write, only uploader can delete

2. **Thumbnails** (`thumbnails/{familyId}/{photoId}.jpg`)
   - Used by: `PhotoService.uploadPhoto()` and `PhotoService.uploadPhotoWeb()`
   - Permissions: Family members can read/write/delete (auto-created with photos)

3. **Voice Messages** (`families/{familyId}/voice_messages/{fileName}`)
   - Used by: `VoiceRecordingService.uploadVoiceMessage()`
   - Permissions: Family members can read/write/delete

### Security Features:

- **Family-based access**: Only users in the same family can access files
- **Ownership checks**: Users can only delete files they uploaded (for photos)
- **Authentication required**: All operations require valid Firebase Auth
- **Safe document access**: Helper functions safely handle missing user documents
- **Default deny**: Any paths not explicitly allowed are denied

## Important Notes

1. **Storage Bucket Must Exist**: Make sure Firebase Storage is enabled in your Firebase project
   - Go to Firebase Console > Storage > Get Started
   - Choose the same location as your Firestore database

2. **Metadata Requirements**: 
   - Photos must have `customMetadata.uploadedBy` set to the user's UID
   - This is already handled in `PhotoService` (lines 52, 144)

3. **First Upload**: The "object-not-found" error during upload typically means:
   - Storage rules are blocking the upload (most common)
   - Storage bucket doesn't exist
   - User doesn't belong to the family specified in the path

## Comparison to Firestore Rules

These Storage rules follow the same security pattern as your Firestore rules:
- Same helper functions (`belongsToFamily`, `getUserFamilyId`, etc.)
- Same family membership verification
- Same safe document access patterns

## Troubleshooting

### Error: "object-not-found" (Code: -13010)
**Most Common Cause**: Storage rules are blocking the upload

**Solutions**:
1. Verify Storage rules are published in Firebase Console
2. Check that your user document has a `familyId` field
3. Ensure the `familyId` in the storage path matches your user's `familyId`
4. Verify Firebase Storage is enabled and the bucket exists

### Error: "Permission denied"
**Solutions**:
1. Verify you're logged in (`request.auth != null`)
2. Check that your user document exists in Firestore
3. Ensure your user document has a `familyId` field
4. Verify the `familyId` in the storage path matches your user's `familyId`

### Error: "The server has terminated the upload session"
**Solutions**:
1. Check your network connection
2. Try uploading a smaller image first
3. Verify Storage bucket exists and is accessible
4. Check Firebase Console for any service outages

### Error: "Metadata uploadBy mismatch"
**Solutions**:
1. Ensure `PhotoService` sets `customMetadata.uploadedBy` to the user's UID
2. This should already be handled in your code (lines 52, 144 of `photo_service.dart`)
