# Get Debug Token - Simple Method

## Option 1: Capture from Logcat (Easiest)

Run this command while your app is running:

```bash
adb logcat -s FirebaseAppCheck:D | findstr /i "token"
```

Or capture full logcat and search:

```bash
adb logcat -d > logcat.txt
```

Then open `logcat.txt` and search for "token" or "AppCheck"

## Option 2: Check Your IDE Console

When you run `flutter run --flavor qa`, the token should appear in your IDE's console output. Look for:
- "🔑 APP CHECK DEBUG TOKEN"
- "Token: [long-string]"

## Option 3: Temporarily Disable App Check (Test if it's the issue)

If you want to test if App Check is causing the auth timeout, I can comment it out temporarily. This will tell us if App Check is the root cause.

## The Token Format

The debug token looks like a UUID:
```
a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

It will be logged automatically when App Check initializes in debug mode.

