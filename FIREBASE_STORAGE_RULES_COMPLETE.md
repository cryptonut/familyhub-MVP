# Complete Firebase Storage Rules (Including Event Photos)

## Critical Fix: Add Event Photos Path

The error `[firebase_storage/unauthorized]` occurs because the Storage rules don't include the `eventPhotos/` path used by event photo uploads.

## How to Deploy

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click **Storage** in the left sidebar
4. Click on the **Rules** tab
5. **Replace ALL existing rules** with the rules below
6. Click **Publish**

## Complete Storage Rules (Copy-Paste Ready)

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow all authenticated users (basic security)
    // This ensures all photo uploads work immediately
    
    // Regular photos (photo albums)
    match /photos/{familyId}/{photoId} {
      allow read, write, delete: if request.auth != null;
    }
    
    // Thumbnails
    match /thumbnails/{familyId}/{photoId} {
      allow read, write, delete: if request.auth != null;
    }
    
    // Voice messages
    match /families/{familyId}/voice_messages/{fileName} {
      allow read, write, delete: if request.auth != null;
    }
    
    // Event photos - NEW PATH (this fixes the unauthorized error)
    match /eventPhotos/{familyId}/{eventId}/{photoId} {
      allow read, write, delete: if request.auth != null;
    }
  }
}
```

## What This Fixes

1. **Event Photo Uploads**: The `eventPhotos/{familyId}/{eventId}/{photoId}` path is now allowed
2. **All Photo Types**: Regular photos, thumbnails, voice messages, and event photos all work
3. **Authentication**: All operations require valid Firebase Auth

## After Deploying

1. **Restart your app** (hot restart: `R` in terminal)
2. Try uploading a photo to an event
3. The `[firebase_storage/unauthorized]` error should be gone!

## Security Note

These rules allow any authenticated user to access storage. For production with multiple families, you may want to add family membership checks, but this will work for now and fix the immediate issue.

