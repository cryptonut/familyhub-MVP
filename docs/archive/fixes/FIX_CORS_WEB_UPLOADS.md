# Fix CORS for Web Photo Uploads

## The Problem
Photo uploads fail on web due to CORS (Cross-Origin Resource Sharing) restrictions. This is **only a web issue** - mobile apps don't have this problem.

## Solution Options

### ✅ **EASIEST: Test on Android Emulator (No CORS Issues)**
Since CORS only affects web, you can test photo uploads on mobile:
1. Launch emulator: `flutter emulators --launch pixel6`
2. Run app: `flutter run`
3. Photo uploads will work perfectly!

### Option 1: Install Google Cloud SDK (For Web Fix)

#### Step 1: Download Google Cloud SDK
1. Go to: https://cloud.google.com/sdk/docs/install
2. Click **"Download for Windows"**
3. Download the installer (`.exe` file)
4. Run the installer and follow the prompts
5. **Important**: Check the box to "Add to PATH" during installation

#### Step 2: Restart Your Terminal
Close and reopen PowerShell/VS Code terminal after installation.

#### Step 3: Initialize Google Cloud SDK
```powershell
gcloud init
```
- Choose "Create a new configuration"
- Select your Google account
- Choose project: `family-hub-71ff0`

#### Step 4: Authenticate
```powershell
gcloud auth login
```
This will open a browser for authentication.

#### Step 5: Apply CORS Configuration
```powershell
gsutil cors set cors.json gs://family-hub-71ff0.appspot.com
```

### Option 2: Use Firebase Console (Limited - Storage Rules Only)

**Note**: Firebase Console doesn't directly set CORS, but you can verify Storage rules:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Go to **Storage** → **Rules** tab
4. Ensure rules allow uploads:
   ```javascript
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /photos/{familyId}/{photoId} {
         allow read: if request.auth != null;
         allow write: if request.auth != null;
       }
       match /thumbnails/{familyId}/{photoId} {
         allow read: if request.auth != null;
         allow write: if request.auth != null;
       }
     }
   }
   ```

**However**, Storage rules ≠ CORS configuration. You still need `gsutil` for CORS.

### Option 3: Deploy to Production (Firebase Hosting)

If you deploy to Firebase Hosting, CORS might be handled differently. But for local development, you still need CORS configured.

## Quick Test: Verify Installation

After installing Google Cloud SDK:
```powershell
gcloud --version
gsutil --version
```

If these commands work, you're ready to apply CORS!

## Recommended Approach

**For Development**: Test on Android emulator (no CORS issues)
**For Production**: Install Google Cloud SDK and configure CORS properly

## Current Status

- ✅ Chess game is functional
- ✅ Android emulator is set up
- ⚠️ Web photo uploads need CORS configuration (or test on mobile)

