# Firebase Storage Security Rules for Profile Photos

This document contains the Firebase Storage security rules needed to allow authenticated users to upload their own profile images.

## How to Deploy

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click **Storage** in the left sidebar
4. Click on the **Rules** tab
5. Replace ALL existing rules with the rules below
6. Click **Publish**

## Storage Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile photos - users can upload/read/delete their own profile photos
    match /profile_photos/{userId}/{photoId} {
      // Allow read if authenticated
      allow read: if request.auth != null;
      
      // Allow write (create/update) only if:
      // 1. User is authenticated
      // 2. The userId in the path matches the authenticated user's ID
      allow write: if request.auth != null && 
                      request.auth.uid == userId &&
                      request.resource.size < 5 * 1024 * 1024 && // 5MB max
                      request.resource.contentType.matches('image/.*');
      
      // Allow delete only if user owns the photo
      allow delete: if request.auth != null && 
                       request.auth.uid == userId;
    }
    
    // Family photos - allow authenticated family members to upload/read
    match /photos/{familyId}/{photoId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
                      request.resource.size < 10 * 1024 * 1024 && // 10MB max
                      request.resource.contentType.matches('image/.*');
      allow delete: if request.auth != null;
    }
    
    // Thumbnails - same rules as photos
    match /thumbnails/{familyId}/{photoId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
                      request.resource.size < 2 * 1024 * 1024 && // 2MB max for thumbnails
                      request.resource.contentType.matches('image/.*');
      allow delete: if request.auth != null;
    }
    
    // Event photos - allow authenticated users to upload
    match /event_photos/{eventId}/{photoId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
                      request.resource.size < 10 * 1024 * 1024 && // 10MB max
                      request.resource.contentType.matches('image/.*');
      allow delete: if request.auth != null;
    }
  }
}
```

## What These Rules Do

- **Profile Photos** (`profile_photos/{userId}/{photoId}`):
  - Users can only upload/delete photos in their own folder
  - All authenticated users can read profile photos
  - Maximum file size: 5MB
  - Only image files allowed

- **Family Photos** (`photos/{familyId}/{photoId}`):
  - Any authenticated user can upload/read/delete
  - Maximum file size: 10MB
  - Only image files allowed

- **Thumbnails** (`thumbnails/{familyId}/{photoId}`):
  - Same as family photos but with 2MB max size

- **Event Photos** (`event_photos/{eventId}/{photoId}`):
  - Any authenticated user can upload/read/delete
  - Maximum file size: 10MB
  - Only image files allowed

## Testing

After deploying these rules:

1. **Refresh your Flutter app** (hot restart: `R` in terminal)
2. Try uploading a profile photo by long-pressing on your avatar
3. The upload should now work without "unauthorized" errors

## Security Notes

- These rules ensure users can only upload to their own profile photo folder
- File size limits prevent abuse
- Content type validation ensures only images are uploaded
- For production, you may want to add family membership checks for family photos
