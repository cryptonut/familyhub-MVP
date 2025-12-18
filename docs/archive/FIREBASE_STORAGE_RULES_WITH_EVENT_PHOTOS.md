# Firebase Storage Rules - Complete (Including Event Photos)

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
    // Allow all authenticated users (basic security for now)
    // This ensures event photos work immediately
    
    // Regular photos
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
    
    // Event photos - NEW PATH FOR EVENT PHOTOS
    match /eventPhotos/{familyId}/{eventId}/{photoId} {
      allow read, write, delete: if request.auth != null;
    }
  }
}
```

## What This Adds

The new rule for **event photos**:
- **Path**: `eventPhotos/{familyId}/{eventId}/{photoId}`
- **Permissions**: All authenticated users can read/write/delete
- **Used by**: `CalendarService.uploadEventPhoto()` and `CalendarService.uploadEventPhotoWeb()`

## Security Note

These rules allow any authenticated user to access storage. For production, you may want to add family membership checks, but this will work for now and fix the unauthorized error.

## After Deploying

1. **Restart your app** (hot restart: `R` in terminal)
2. Try uploading a photo to an event
3. It should work now!

