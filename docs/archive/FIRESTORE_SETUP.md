# Firestore Database Setup Guide

If you can't save tasks or calendar entries, you need to set up Firestore Database and configure security rules.

## Step 1: Create Firestore Database

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click on **Firestore Database** in the left sidebar
4. If you see "Create database", click it
5. Choose **Start in test mode** (for development)
6. Select a **location** (choose the closest to you)
7. Click **Enable**

## Step 2: Set Up Security Rules

1. In Firestore Database, click on the **Rules** tab
2. Replace the rules with the following:

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

3. Click **Publish**

## Step 3: Verify Setup

After setting up:

1. **Refresh your Flutter app** (hot restart: `R` in terminal)
2. Try creating a task or calendar event again
3. Check Firestore Database > Data tab to see if data is being saved

## Troubleshooting

### Error: "Permission denied"
- Make sure security rules are published
- Verify you're logged in (check Authentication > Users)
- Check that rules allow `request.auth != null`

### Error: "Database not found"
- Make sure Firestore is created (not just Realtime Database)
- Verify you selected the correct Firebase project

### Data not appearing
- Check browser console (F12) for errors
- Verify you're looking at the correct collection path: `families/{userId}/events` or `families/{userId}/tasks`
- Make sure you're authenticated (check if user appears in Authentication > Users)

## Test Mode vs Production

**Test mode** (current setup):
- Allows reads/writes for 30 days
- Good for development
- **⚠️ Not secure for production**

**Production rules** (for later):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /families/{familyId}/{document=**} {
      // Only allow access to users in the same family
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.familyId == familyId;
    }
  }
}
```

## Quick Check

To verify everything is working:

1. ✅ Firestore Database created
2. ✅ Security rules published
3. ✅ User authenticated (check Authentication > Users)
4. ✅ Try saving a task/event
5. ✅ Check Firestore > Data tab to see saved data

