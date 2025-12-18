# Quick Fix: Check API Key Restrictions

## The Problem
Network connectivity is OK, but Firebase Auth times out. This means the API key likely has restrictions blocking authentication requests.

## Easy Way to Check (From Firebase Console)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: **family-hub-71ff0**
3. Click the **gear icon** ⚙️ next to "Project Overview"
4. Click **"Project settings"**
5. Scroll to **"Your apps"** section
6. Click on your **Android app** (com.example.familyhub_mvp)
7. Look for **"API restrictions"** or **"Key restrictions"** - if you see any restrictions, that's the problem

## OR Check Google Cloud Console (Alternative)

1. In Firebase Console, click the gear icon ⚙️
2. Click **"Project settings"**
3. Look for a link that says **"Open in Google Cloud Console"** or similar
4. Click it
5. In Google Cloud Console, go to **"APIs & Services"** > **"Credentials"** (left sidebar)
6. Find API key: **YOUR_FIREBASE_API_KEY**
7. Click on it
8. Check:
   - **API restrictions**: Should be "Don't restrict key" OR include "Identity Toolkit API"
   - **Application restrictions**: Should be "None" OR include your Android app

## Quick Test

If you can't access these settings, try this:
1. Create a **NEW** Firebase project (temporary test)
2. Add Android app with same package name
3. Download new `google-services.json`
4. Replace the current one
5. Try login

If login works with new project → API key restrictions in original project
If login still fails → Different issue (network/firewall)

