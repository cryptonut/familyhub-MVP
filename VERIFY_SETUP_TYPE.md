# Firebase Setup Type: Manual Configuration

## Setup Method
**Manual configuration** - `google-services.json` was manually dropped into `android/app/`

## Evidence
- ✅ `google-services.json` exists in `android/app/`
- ✅ Google Services plugin applied in `android/app/build.gradle.kts`
- ✅ `firebase_options.dart` exists (but iOS has dummy values)
- ❌ No `.flutterfire/` directory (would exist if `flutterfire configure` was run)
- ✅ Uses standard `firebase_core` and `cloud_firestore` plugins

## How Android Reads Firebase Config
For Android, Firebase reads from **`google-services.json`** (not `firebase_options.dart`) when:
1. `google-services.json` is in `android/app/`
2. Google Services plugin is applied in `build.gradle.kts`

The `firebase_options.dart` is used as a fallback or for other platforms.

## The API Key Issue
- **Android** uses API key from `google-services.json`: `AIzaSyDLZ3mdwyumvm_oXPWBAUtANQBSlbFizyk`
- **Web** uses API key from `firebase_options.dart`: `AIzaSyC_WWJtrIRRMvRyjMe7WaeYQ0veE9cs-Mw`

This is why Chrome works but Android doesn't - they're using different API keys with different restrictions.

## To Fix Firestore on Android
Check if **Cloud Firestore API** is enabled for the **Android API key** (`AIzaSyDLZ3mdwyumvm_oXPWBAUtANQBSlbFizyk`) in Google Cloud Console.

