# Firestore Security Rules for Production Mode

Since you set up Firestore in production mode, you need to update the security rules to allow authenticated users to save data.

## Update Security Rules

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click **Firestore Database** in the left sidebar
4. Click on the **Rules** tab
5. Replace the existing rules with the following:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Family data - authenticated users can read/write their family data
    match /families/{familyId}/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

6. Click **Publish**

## What These Rules Do

- **Users collection**: Users can only read/write their own user document
- **Families collection**: Any authenticated user can read/write data in their family collections (events, tasks, messages, etc.)

## Test After Updating

1. **Refresh your Flutter app** (hot restart: `R` in terminal)
2. Try saving a task or calendar event
3. It should work now!

## Security Note

These rules allow any authenticated user to write to the families collection. For a production app with multiple families, you'd want more restrictive rules that check if the user belongs to the family. But for now, this will work for development and single-family use.

## More Secure Rules (Optional - for later)

If you want to restrict access to only users in the same family:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /families/{familyId}/{document=**} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.familyId == familyId;
    }
  }
}
```

But for now, the simpler rules above will work fine!

