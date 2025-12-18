# Google Maps API - Quick Setup Guide

## 🎯 What to Select in the Filter Dialog

When you see the "Filter" dialog with the list of Google Maps APIs, select these:

### ✅ **REQUIRED (Must Select)**
- **Maps SDK for Android** - This is the core API needed to display maps in your Android app

### ✅ **RECOMMENDED (Also Select)**
- **Geocoding API** - Converts addresses to coordinates (useful for location features)
- **Places API (New)** - Allows users to search for locations

### ❌ **NOT NEEDED (Skip These)**
- Directions API (only if you want route directions)
- Distance Matrix API (only if you need distance calculations)
- Maps Elevation API (not needed for basic maps)
- Maps Embed API (for web embeds, not mobile)
- Maps JavaScript API (for web, not Android)
- Geolocation API (different from Geocoding)

## 📋 Step-by-Step

1. **In the Filter dialog**, check these boxes:
   - ✅ Maps SDK for Android
   - ✅ Geocoding API
   - ✅ Places API (New)

2. Click **"OK"** (ignore the error about selecting at least one API - you are selecting them)

3. **Configure API Key Restrictions** (Important for security):
   - Go to [Google Cloud Console > Credentials](https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0)
   - Find your API key: `YOUR_GOOGLE_MAPS_API_KEY_HERE` (get it from Google Cloud Console)
   - Click on it to edit
   - **Application restrictions**: Select "Android apps"
     - Add package name: `com.example.familyhub_mvp`
     - Add SHA-1 fingerprint (same one from Firebase setup)
   - **API restrictions**: Select "Restrict key"
     - Choose: Maps SDK for Android, Geocoding API, Places API
   - Click **Save**

## ✅ What I've Already Done

I've updated your `android/app/src/main/AndroidManifest.xml` with:
- ✅ Google Maps API key: `YOUR_GOOGLE_MAPS_API_KEY_HERE` (configure in secrets.properties)
- ✅ Location permissions (ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION)

## 🚀 Next Steps

After selecting the APIs in the filter dialog:

```bash
flutter clean
flutter pub get
flutter run
```

## 💡 Important Notes

- This is a **different API key** from your Firebase Auth key
- Firebase Auth Key: `YOUR_FIREBASE_API_KEY` (for authentication - get from Firebase Console)
- Google Maps Key: `YOUR_GOOGLE_MAPS_API_KEY_HERE` (for maps - get from Google Cloud Console)
- Both are needed and serve different purposes

## 💰 Cost

- Maps SDK for Android: **Free** up to 28,000 map loads/month
- Geocoding API: **Free** up to 40,000 requests/month
- Places API: Pay-as-you-go after free tier

For a family app, you'll likely stay within free tiers.

