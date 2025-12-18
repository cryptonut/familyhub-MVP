# Firebase Storage Rules - Complete (Including Profile Photos)

## Critical Fix: Add Profile Photos Path

The error `[firebase_storage/unauthorized]` occurs when uploading profile photos because the Storage rules don't include the `profile_photos/` path.

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
    
    // Event photos
    match /eventPhotos/{familyId}/{eventId}/{photoId} {
      allow read, write, delete: if request.auth != null;
    }
    
    // Profile photos - NEW PATH (fixes avatar upload unauthorized error)
    // Path: profile_photos/{userId}/{photoId}.jpg
    match /profile_photos/{userId}/{photoId} {
      // Allow read for all authenticated users (profiles are visible to family)
      allow read: if request.auth != null;
      
      // Allow write/delete only for the user's own profile photo
      allow write, delete: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## What This Fixes

1. **Profile Photo Uploads**: The `profile_photos/{userId}/{photoId}` path is now allowed
   - Users can upload their own profile photos
   - Users can only modify their own profile photos (write/delete restricted to owner)
   - All authenticated users can read profile photos (for displaying in family views)

2. **All Photo Types**: Regular photos, thumbnails, voice messages, event photos, and profile photos all work

3. **Security**: Profile photo uploads are restricted to the photo owner

## Path Details

- **Path Pattern**: `profile_photos/{userId}/{photoId}.jpg`
- **Used by**: `ProfilePhotoService.uploadProfilePhoto()` and `ProfilePhotoService.uploadProfilePhotoWeb()`
- **Upload Location**: Line 34 in `lib/services/profile_photo_service.dart`

## After Deploying

1. **Restart your app** (hot restart: `R` in terminal)
2. Try uploading a profile photo via long-press on avatar
3. The `[firebase_storage/unauthorized]` error should be gone!

## Security Notes

- **Profile Photos**: Users can only upload/modify their own profile photos
- **Read Access**: All authenticated users can read profile photos (needed for displaying in family views)
- **Other Paths**: All other paths remain accessible to authenticated users (for now)

For production with multiple families, you may want to add family membership checks to the read rules, but this configuration will work for now and fix the immediate unauthorized error.

