# Check API Key Restrictions - Critical Step

## Good News
✅ Cloud Firestore API is **enabled** in your project (150 requests showing)
✅ Identity Toolkit API is **enabled** (32 requests showing)

## But There's Still an Issue

The APIs are enabled for the **project**, but the **specific API key** might have restrictions that block Firestore.

## What to Check Now

From the Credentials page you're on:

1. **Click on the Android key** `AIzaSyDnHlg-5GNajYwXWrtVLRJvOpkV0UEFcV4`
   - Don't just view it in the modal
   - Actually click to open the full edit page

2. **Look for "API restrictions" section**
   - Should show either "Don't restrict key" or a list of APIs
   - If it lists APIs, make sure **"Cloud Firestore API"** is in the list
   - Not just "Identity Toolkit API"

3. **Look for "Application restrictions" section**
   - Should be "None" for development
   - Or "Android apps" with your package name
   - NOT "HTTP referrers" (that blocks Android)

## Common Issue

Even though Firestore API is enabled for the project, the **key itself** might be restricted to only "Identity Toolkit API", which would explain:
- ✅ Auth works (Identity Toolkit enabled)
- ❌ Firestore fails (Cloud Firestore not in key restrictions)

## Quick Fix

If "API restrictions" shows only Identity Toolkit:
1. Click "Edit API key" (pencil icon)
2. Under "API restrictions", select "Don't restrict key" (for development)
3. OR add "Cloud Firestore API" to the allowed list
4. Save
5. Wait 1-2 minutes for propagation
6. Try "Refresh Session" in the app

Let me know what the "API restrictions" section shows for that specific key!

