# Enable Email/Password Authentication in Firebase

If you're unable to create an account, you need to enable Email/Password authentication in Firebase Console.

## Step-by-Step Instructions

### 1. Go to Firebase Console
- Visit [https://console.firebase.google.com/](https://console.firebase.google.com/)
- Select your project: **family-hub-71ff0**

### 2. Navigate to Authentication
- In the left sidebar, click on **Authentication**
- If you see a "Get started" button, click it

### 3. Enable Email/Password Sign-in
- Click on the **Sign-in method** tab (or it may be called "Providers")
- You'll see a list of sign-in providers
- Find **Email/Password** in the list
- Click on it

### 4. Enable Email/Password
- Toggle the **Enable** switch to ON
- Make sure both options are enabled:
  - ✅ **Email/Password** (required)
  - ✅ **Email link (passwordless sign-in)** (optional, but can be enabled)
- Click **Save**

### 5. Verify It's Enabled
- You should see **Email/Password** with a green checkmark or "Enabled" status
- The status should show as "Enabled"

## Also Check: Firestore Database

Make sure Firestore is set up:

1. In Firebase Console, go to **Firestore Database**
2. If you see "Create database", click it
3. Choose **Start in test mode** (for development)
4. Select a location (choose the closest to you)
5. Click **Enable**

## Test Again

After enabling Email/Password authentication:

1. Refresh your Flutter app (hot restart: `R` in terminal or restart the app)
2. Try creating an account again
3. You should now be able to register successfully!

## Common Error Messages

- **"operation-not-allowed"**: Email/Password is not enabled (follow steps above)
- **"email-already-in-use"**: Account already exists, try signing in instead
- **"weak-password"**: Password must be at least 6 characters
- **"invalid-email"**: Email format is incorrect

## Still Having Issues?

1. Check the browser console (F12) for detailed error messages
2. Verify Firestore is created and in test mode
3. Make sure you're using the correct Firebase project
4. Try clearing browser cache and refreshing

