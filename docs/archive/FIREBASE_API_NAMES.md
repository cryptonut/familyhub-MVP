# Correct Firebase API Names in Google Cloud Console

When searching in the API restrictions dropdown, use these exact names:

## Required APIs

1. **Identity Toolkit API** ✅ (you already have this)
   - Used for: Firebase Authentication

2. **Cloud Firestore API**
   - Used for: Database operations
   - Search for: "Cloud Firestore" or "Firestore"

3. **Firebase Cloud Messaging API**
   - Used for: Push notifications
   - Search for: "Firebase Cloud Messaging" or "FCM"

4. **Cloud Storage JSON API** (for Firebase Storage)
   - Used for: File/photo storage
   - Search for: "Cloud Storage" or "Storage JSON"
   - Note: This is the Google Cloud Storage API that Firebase Storage uses

5. **Google Analytics API** (for Firebase Analytics)
   - Used for: Analytics
   - Search for: "Google Analytics" or "Analytics"
   - Note: Firebase Analytics might use this, or it might be automatically enabled

## Alternative: If You Can't Find Them

If you can't find these specific APIs:

1. **Check if APIs are enabled:**
   - In Google Cloud Console, go to **APIs & Services** > **Enabled APIs**
   - Search for "Firebase" or "Firestore" or "Storage"
   - Enable any that are listed but not enabled

2. **For Firebase Storage:**
   - Try searching for: "Cloud Storage" (without "JSON")
   - Or: "Storage API"
   - The full name might be: "Cloud Storage JSON API"

3. **For Analytics:**
   - Firebase Analytics might not require a separate API key restriction
   - It might be included automatically with Firebase services
   - You can skip this one if you can't find it

## Minimum Required APIs

At minimum, you need:
- ✅ **Identity Toolkit API** (for auth)
- ✅ **Cloud Firestore API** (for database)
- ✅ **Firebase Cloud Messaging API** (for notifications)

If you can't find Storage or Analytics APIs, start with these three and test. You can add Storage later if file uploads fail.

## How to Search

In the API restrictions dropdown:
1. Start typing the API name
2. The dropdown will filter as you type
3. Look for APIs that start with "Cloud" or "Firebase"

Common variations:
- "Cloud Firestore API" (not "Firestore API")
- "Cloud Storage JSON API" (not "Firebase Storage API")
- "Firebase Cloud Messaging API" (might show as "FCM API")

