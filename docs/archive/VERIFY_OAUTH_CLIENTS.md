# How to Verify OAuth Clients Are Present

After re-downloading `google-services.json`, verify it has OAuth clients:

## Quick Check

Open `android/app/google-services.json` and look for line 15.

### ❌ BAD (Current State):
```json
"oauth_client": [],
```

### ✅ GOOD (After Re-download):
```json
"oauth_client": [
  {
    "client_id": "559662117534-xxxxx.apps.googleusercontent.com",
    "client_type": 1,
    "android_info": {
      "package_name": "com.example.familyhub_mvp",
      "certificate_hash": "bb:7a:6a:5f:57:f1:dd:0d:ed:14:2a:5c:6f:26:14:fd:54:c3:c7:1c"
    }
  },
  {
    "client_id": "559662117534-xxxxx.apps.googleusercontent.com",
    "client_type": 3
  }
]
```

## What to Look For

- `oauth_client` array should have **at least 2 items**
- One with `"client_type": 1` (Android client)
- One with `"client_type": 3` (Web client)
- The Android client should have `certificate_hash` matching your SHA-1

## If Still Empty

1. Wait 2-3 minutes after adding SHA-1 (Firebase needs time to generate)
2. Try re-downloading again
3. Add SHA-256 fingerprint as well (get it from `./gradlew signingReport`)
4. Re-download again

