# Verify SHA-1 Fingerprint Match

## Firebase Console Shows:
✅ **Package name**: `com.example.familyhub_mvp`
✅ **SHA-1 fingerprint**: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`

## Now Check Google Cloud Console

Go back to the **Google Cloud Console > Credentials > Edit API key** page and verify:

### In the "Android apps" section:
1. **Package name** should be: `com.example.familyhub_mvp`
2. **SHA-1** should be: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`

### If They Don't Match:
- The API key restrictions might be blocking your Android app
- Even though Cloud Firestore API is allowed, the app restriction could be rejecting requests

### How to Fix:
1. In Google Cloud Console, click on "Android apps" section
2. Click "Add an item" or edit existing
3. Enter:
   - Package name: `com.example.familyhub_mvp`
   - SHA-1: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`
4. Click "Save"
5. Wait 2-3 minutes

### Alternative: For Testing
If you want to test quickly, you can temporarily:
1. Set "Application restrictions" to **"None"**
2. Save
3. Test the app
4. Once working, add back the Android apps restriction with correct SHA-1

## After Saving
1. Wait 2-3 minutes for propagation
2. In the app: Menu > "Refresh Session"
3. Sign back in
4. Firestore should now work!

The SHA-1 fingerprint must match exactly between Firebase and Google Cloud Console for Android to work.

