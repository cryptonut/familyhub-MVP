# Google Maps API Setup Guide

## API Key
Your Google Maps API Key: `YOUR_GOOGLE_MAPS_API_KEY_HERE`

## Which APIs to Select

Based on your app's usage (displaying family member locations on a map), here's what you need:

### ✅ **Minimum Required (Select This)**
- **Maps SDK for Android** - Required for displaying maps in your Android app

### 🎯 **Recommended (Also Select These)**
- **Geocoding API** - Useful for converting addresses to coordinates and vice versa
- **Places API (New)** - If you want users to search for locations

### 📋 **Optional (Select If Needed Later)**
- **Directions API** - If you want to show routes between locations
- **Distance Matrix API** - If you want to calculate distances between multiple points
- **Maps JavaScript API** - Only if you have a web version

## Quick Setup Steps

### 1. Select APIs in Google Cloud Console
In the filter dialog you're seeing:
1. ✅ Check **"Maps SDK for Android"** (REQUIRED)
2. ✅ Check **"Geocoding API"** (Recommended)
3. ✅ Check **"Places API (New)"** (Recommended)
4. Click **"OK"**

### 2. Configure API Key Restrictions
After selecting APIs, configure the key:
1. Go to [Google Cloud Console > Credentials](https://console.cloud.google.com/apis/credentials?project=family-hub-71ff0)
2. Find your API key: `YOUR_GOOGLE_MAPS_API_KEY_HERE` (get it from Google Cloud Console)
3. Click on it to edit
4. Set **Application restrictions**:
   - Select "Android apps"
   - Add package name: `com.example.familyhub_mvp`
   - Add your SHA-1 fingerprint (same one used for Firebase)
5. Set **API restrictions**:
   - Select "Restrict key"
   - Choose the APIs you enabled (Maps SDK for Android, Geocoding, Places)
6. Click **Save**

### 3. Add API Key to Android App
Add the key to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- ... existing permissions ... -->
    
    <application
        android:label="familyhub_mvp"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Add this meta-data tag inside <application> -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
        
        <!-- ... rest of application ... -->
    </application>
</manifest>
```

### 4. Add Location Permissions
Make sure you have location permissions in `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add these permissions -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    
    <!-- ... rest of manifest ... -->
</manifest>
```

### 5. Rebuild and Test
```bash
flutter clean
flutter pub get
flutter run
```

## Cost Considerations

- **Maps SDK for Android**: Free up to 28,000 map loads per month
- **Geocoding API**: Free up to 40,000 requests per month
- **Places API**: Pay-as-you-go after free tier

For a family app, you'll likely stay within free tiers.

## Troubleshooting

If maps don't load:
1. Verify API key is correct in AndroidManifest.xml
2. Check API restrictions allow your package name and SHA-1
3. Ensure "Maps SDK for Android" is enabled in Google Cloud Console
4. Check logs for API key errors
5. Wait a few minutes after enabling APIs for changes to propagate

## Note: Different from Firebase API Key

This is a **different API key** from your Firebase Authentication key:
- **Firebase Auth Key**: `YOUR_FIREBASE_API_KEY` (for authentication - get from Firebase Console)
- **Google Maps Key**: `YOUR_GOOGLE_MAPS_API_KEY_HERE` (for maps - get from Google Cloud Console)

Both are needed and serve different purposes.

