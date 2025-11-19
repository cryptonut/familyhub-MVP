# Verify Firestore Database is Set Up

The "Firestore database not found" error means Firestore isn't accessible. Let's verify it's set up correctly.

## Step 1: Verify Firestore Exists

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Click **Firestore Database** in the left sidebar
4. You should see:
   - **Data** tab (shows your collections)
   - **Rules** tab (shows security rules)
   - **Indexes** tab
   - **Usage** tab

If you see "Create database" instead, click it and create the database.

## Step 2: Check Security Rules

1. Click the **Rules** tab
2. Make sure the rules are published (not just saved)
3. The rules should allow authenticated users:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /families/{familyId}/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

4. Click **Publish** if you made changes

## Step 3: Verify You're Using the Correct Project

Make sure your Firebase web config in `lib/firebase_options.dart` matches your project:
- Project ID: `family-hub-71ff0`
- Check the API key matches what's in Firebase Console

## Step 4: Check Browser Console

1. Open browser DevTools (F12)
2. Go to **Console** tab
3. Look for any Firebase/Firestore errors
4. The actual error code will help diagnose the issue

## Common Issues

### Issue: Database exists but still getting error
- **Solution**: Make sure security rules are published (not just saved)
- **Solution**: Clear browser cache and refresh

### Issue: Permission denied
- **Solution**: Update security rules to allow authenticated users
- **Solution**: Make sure you're logged in

### Issue: Wrong project
- **Solution**: Verify project ID in `firebase_options.dart` matches Firebase Console

## Quick Test

After verifying everything:
1. Hot restart the app (press `R` in terminal)
2. Sign in again
3. Try saving a task
4. Check browser console (F12) for actual error messages

