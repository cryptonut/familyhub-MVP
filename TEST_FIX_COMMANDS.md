# Commands to Test Gemini3's Fix

## 1. Switch to Fix Branch
```bash
git checkout cursor/resolve-persistent-error-in-dev-branch-gemini-3-pro-preview-417c
```

## 2. Clean and Rebuild
```bash
flutter clean
flutter pub get
```

## 3. Run App (Dev Flavor)
```bash
flutter run --flavor dev --debug
```

## 4. Alternative: Build APK First
```bash
flutter build apk --flavor dev --debug
```

## What to Look For

### ✅ Success Indicators:
- No "Channel shutdownNow invoked" errors
- No multiple simultaneous "Waiting for gRPC channel" messages
- Logs show: "Query already in progress for {uid}, waiting for existing query..." (deduplication working)
- Logs show: "Returning cached user model for {uid}" (caching working)
- Firestore queries succeed
- User data loads successfully
- Authentication completes without timeout

### ❌ If Still Failing:
- Check logs for API key restriction errors
- See `ROOT_CAUSE_FIX_API_KEY_RESTRICTIONS.md` for external fixes needed
- May need to fix API key restrictions in Google Cloud Console

## Full Test Sequence
```bash
# 1. Switch to fix branch
git checkout cursor/resolve-persistent-error-in-dev-branch-gemini-3-pro-preview-417c

# 2. Clean build
flutter clean
flutter pub get

# 3. Run app
flutter run --flavor dev --debug

# 4. Watch logs for:
#    - No channel reset errors
#    - Query deduplication messages
#    - Successful Firestore queries
#    - Authentication completing
```

