# Firebase Storage CORS Configuration for Web

The photo upload is failing on web due to CORS (Cross-Origin Resource Sharing) restrictions. You need to configure CORS for Firebase Storage.

## Solution: Configure CORS for Firebase Storage

### Option 1: Using gsutil (Recommended)

1. **Install Google Cloud SDK** (if not already installed):
   - Download from: https://cloud.google.com/sdk/docs/install
   - Or use: `choco install gcloudsdk` (Windows with Chocolatey)

2. **Authenticate with Google Cloud**:
   ```bash
   gcloud auth login
   ```

3. **Set your Firebase project**:
   ```bash
   gcloud config set project family-hub-71ff0
   ```

4. **Create a CORS configuration file** (`cors.json`):
   ```json
   [
     {
       "origin": ["*"],
       "method": ["GET", "POST", "PUT", "DELETE", "HEAD"],
       "maxAgeSeconds": 3600,
       "responseHeader": ["Content-Type", "Authorization"]
     }
   ]
   ```

5. **Apply CORS configuration**:
   ```bash
   gsutil cors set cors.json gs://family-hub-71ff0.appspot.com
   ```

### Option 2: Using Firebase Console (Simpler but less control)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **family-hub-71ff0**
3. Go to **Storage** in the left sidebar
4. Click on the **Rules** tab
5. Make sure your rules allow uploads:
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

### Option 3: Quick Fix - Use Firebase Hosting CORS Headers

If you're using Firebase Hosting, you can add CORS headers in `firebase.json`:
```json
{
  "hosting": {
    "headers": [
      {
        "source": "**",
        "headers": [
          {
            "key": "Access-Control-Allow-Origin",
            "value": "*"
          }
        ]
      }
    ]
  }
}
```

## Verify CORS is Working

After applying CORS configuration, test the photo upload again. The CORS error should be resolved.

## Note

For production, you should restrict the `origin` in the CORS configuration to your specific domain instead of using `"*"`.

