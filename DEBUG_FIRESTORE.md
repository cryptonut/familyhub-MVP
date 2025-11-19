# Debugging Firestore Issues

If Firestore database exists and rules are published but you still get errors, follow these steps:

## Step 1: Check Browser Console

1. Open your app in Chrome
2. Press **F12** to open DevTools
3. Go to the **Console** tab
4. Try to save a task or calendar event
5. Look for error messages - they will show the actual error code

Common error codes:
- `permission-denied` - Security rules blocking access
- `not-found` - Collection/document doesn't exist (but database does)
- `unavailable` - Network/connection issue
- `failed-precondition` - Index missing or other setup issue

## Step 2: Verify You're Logged In

1. In the browser console, type:
```javascript
firebase.auth().currentUser
```
2. You should see your user object, not `null`
3. If it's `null`, you're not logged in - sign in again

## Step 3: Check Firestore API is Enabled

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Go to **Project Settings** (gear icon)
4. Scroll to **Your apps** section
5. Make sure your **Web app** is listed
6. If not, add it (click Web icon `</>`)

## Step 4: Verify Security Rules Match Your Data Structure

Your rules should allow:
- `families/{familyId}/events` - for calendar
- `families/{familyId}/tasks` - for tasks
- `families/{familyId}/messages` - for chat
- `families/{familyId}/members` - for location

Make sure the rules use `{document=**}` to match nested collections.

## Step 5: Test Direct Firestore Access

In browser console, try:
```javascript
// This won't work directly, but check if Firestore is accessible
console.log('Firestore instance:', firebase.firestore());
```

## Step 6: Check Network Tab

1. In DevTools, go to **Network** tab
2. Filter by "firestore" or "googleapis"
3. Try saving a task
4. Look for failed requests (red)
5. Check the response for error details

## Common Solutions

### If you see "permission-denied":
- Rules might not be published (click "Publish" not just "Save")
- User might not be authenticated
- Rules might not match your data structure

### If you see "not-found":
- The collection path might be wrong
- The database might not be fully initialized
- Try creating a document manually in Firebase Console first

### If you see "unavailable":
- Network issue
- Firestore API might not be enabled
- Try refreshing the page

## Quick Test

After checking everything:
1. **Hot restart** the app (press `R` in terminal)
2. **Sign out and sign in again**
3. Try saving a task
4. Check browser console (F12) for the actual error code
5. Share the error code and I can help fix it!

