# Root Cause Analysis: Why release/qa Works But develop Doesn't

## Key Finding

**Both `dev` and `qa` google-services.json files use the SAME app ID:**
- `1:559662117534:android:7b3b41176f0d550ee7c18f`

But for different packages:
- dev: `com.example.familyhub_mvp.dev` → OAuth client: `559662117534-pd7lihihfu9k46l0328bat6vhobs9cc0`
- qa: `com.example.familyhub_mvp.test` → OAuth client: `559662117534-g85j4ci8gricvad87cr51scq7u1rlrk0`

## Critical Question

**Why does the MainActivity workaround work in release/qa but NOT in develop?**

The code is identical. The difference must be:
1. **Build type** (release vs debug)
2. **Timing** (when MainActivity.onCreate() runs vs when Firebase Auth initializes)
3. **OAuth client configuration** (dev OAuth client might be misconfigured)

## Next Steps to Identify Root Cause

1. Check if MainActivity logs appear in release/qa logcat (they should)
2. Compare OAuth client configurations in Google Cloud Console
3. Check if there's a difference in Firebase initialization timing

## Hypothesis

The OAuth client for `com.example.familyhub_mvp.dev` might be missing or misconfigured in Google Cloud Console, causing Firebase Auth to require reCAPTCHA even with the workaround.

