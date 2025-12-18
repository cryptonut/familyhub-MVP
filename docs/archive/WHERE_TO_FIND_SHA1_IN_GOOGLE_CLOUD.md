# Where to Find/Add SHA-1 in Google Cloud Console

## Current Situation
I can see "Application restrictions" is set to **"None"** - that's why you don't see SHA-1.

## How to See/Add SHA-1

### Step 1: Select "Android apps"
In the "Application restrictions" section:
1. Click the radio button for **"Android apps"** (instead of "None")
2. This will reveal fields to add package name and SHA-1

### Step 2: Add Your Android App Details
After selecting "Android apps", you'll see:
- An "Add an item" button or existing entries
- Fields for:
  - **Package name**: `com.example.familyhub_mvp`
  - **SHA-1 certificate fingerprint**: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`

### Step 3: Enter the Details
From the Firebase Console you showed earlier:
- **Package name**: `com.example.familyhub_mvp`
- **SHA-1**: `bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c`

### Step 4: Save
Click "Save" at the bottom and wait 2-3 minutes.

## Alternative: Keep "None" for Testing
If you want to test quickly without restrictions:
1. Keep "None" selected
2. Click "Save"
3. Test the app
4. Once working, switch to "Android apps" and add the restrictions

## Why "None" Might Be the Issue
If "None" was selected but Firestore still fails, the issue might be:
- API restrictions (but we confirmed Cloud Firestore API is there)
- Network/connectivity
- Propagation delay
- Stale app session

Try selecting "Android apps" and adding the SHA-1, or keep "None" and use "Refresh Session" in the app.

