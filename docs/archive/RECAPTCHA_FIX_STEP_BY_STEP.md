# reCAPTCHA Fix - Step-by-Step Instructions

## You Have Two Options

### OPTION 1: Disable reCAPTCHA (FASTEST - 2 minutes)
**Use this if you just want authentication to work immediately.**

### OPTION 2: Complete reCAPTCHA Setup (PROPER - 10 minutes)
**Use this if you want to properly integrate reCAPTCHA Enterprise.**

---

## OPTION 1: Disable reCAPTCHA for Email/Password Auth

### Step 1: Go to Firebase Console
1. Open: https://console.firebase.google.com/
2. Select project: **family-hub-71ff0**

### Step 2: Navigate to Authentication Settings
1. Click **"Authentication"** in left sidebar
2. Click the **gear icon (⚙️)** at the top right (next to "Authentication")
3. Click **"Settings"** from the dropdown

### Step 3: Disable reCAPTCHA
1. Scroll down to find **"reCAPTCHA provider"** section
2. Look for **"Email/Password"** authentication method
3. Find the toggle/switch for reCAPTCHA
4. **Turn it OFF** (disable reCAPTCHA for email/password)
5. Click **"Save"**

### Step 4: Test
1. Wait 1-2 minutes for changes to propagate
2. Restart your app
3. Try logging in - should work now

**DONE. Authentication should work immediately.**

---

## OPTION 2: Complete reCAPTCHA Enterprise Setup

### Step 1: Get Your reCAPTCHA Site Key
1. Go to: https://console.cloud.google.com/security/recaptcha
2. Select project: **family-hub-71ff0**
3. Find your reCAPTCHA key (the one showing "Incomplete")
4. Click on it
5. Copy the **Site Key** (starts with `6L...`)

### Step 2: Add reCAPTCHA SDK to Your App
1. Open: `android/app/build.gradle.kts`
2. Add these dependencies (in the `dependencies` block):
```kotlin
dependencies {
    // ... existing dependencies ...
    
    // reCAPTCHA Enterprise SDK
    implementation("com.google.android.recaptcha:recaptcha:18.8.1")
    
    // Kotlin Coroutines (if not already present)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    
    // Core library desugaring (required for reCAPTCHA SDK)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

3. Enable desugaring in `compileOptions`:
```kotlin
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
    isCoreLibraryDesugaringEnabled = true
}
```

### Step 3: Create Application Class
1. Create file: `android/app/src/main/kotlin/com/example/familyhub_mvp/FamilyHubApplication.kt`
2. Add this code (replace `YOUR_SITE_KEY` with the key from Step 1):
```kotlin
package com.example.familyhub_mvp

import android.app.Application
import android.util.Log
import com.google.android.recaptcha.Recaptcha
import com.google.android.recaptcha.RecaptchaClient
import com.google.android.recaptcha.RecaptchaAction
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class FamilyHubApplication : Application() {
    private lateinit var recaptchaClient: RecaptchaClient
    private val recaptchaScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val TAG = "FamilyHubApplication"
    
    // REPLACE THIS WITH YOUR ACTUAL SITE KEY FROM STEP 1
    private val RECAPTCHA_SITE_KEY = "YOUR_SITE_KEY"
    
    override fun onCreate() {
        super.onCreate()
        initializeRecaptchaClient()
    }
    
    private fun initializeRecaptchaClient() {
        recaptchaScope.launch {
            try {
                recaptchaClient = Recaptcha.fetchClient(this@FamilyHubApplication, RECAPTCHA_SITE_KEY)
                Log.i(TAG, "✓ reCAPTCHA client initialized")
            } catch (e: Exception) {
                Log.e(TAG, "✗ reCAPTCHA initialization failed: ${e.message}")
            }
        }
    }
    
    fun executeRecaptcha(action: RecaptchaAction, onSuccess: (String) -> Unit, onError: (Exception) -> Unit) {
        if (!::recaptchaClient.isInitialized) {
            onError(Exception("reCAPTCHA client not initialized"))
            return
        }
        
        recaptchaScope.launch {
            recaptchaClient.execute(action, timeout = 10000L)
                .onSuccess { token ->
                    onSuccess(token)
                }
                .onFailure { exception ->
                    onError(Exception(exception.message))
                }
        }
    }
}
```

### Step 4: Update AndroidManifest.xml
1. Open: `android/app/src/main/AndroidManifest.xml`
2. Find the `<application>` tag
3. Add `android:name` attribute:
```xml
<application
    android:name=".FamilyHubApplication"
    android:label="@string/app_name"
    ...>
```

### Step 5: Complete Key Configuration in Google Cloud Console
1. Go back to: https://console.cloud.google.com/security/recaptcha
2. Click on your reCAPTCHA key
3. Under **"Integration"** → **"Android app"**:
   - Click **"View instructions"**
   - Add package name: `com.example.familyhub_mvp.test` (for qa flavor)
   - Add SHA-1: `BB:7A:6A:5F:57:F1:DD:0D:ED:14:2A:5C:6F:26:14:FD:54:C3:C7:1C`
4. Under **"Configuration"** → **"Actions"**:
   - Click **"View instructions"**
   - This will show you how to call `execute()` - you've already done this in Step 3

### Step 6: Build and Test
1. Run: `flutter clean`
2. Run: `flutter pub get`
3. Run: `flutter run --flavor qa`
4. The app will now call reCAPTCHA execute on login
5. Check Google Cloud Console - the key should show as "Complete" after first use

---

## Which Option Should You Choose?

**Choose OPTION 1 if:**
- You just want authentication to work NOW
- You don't need reCAPTCHA Enterprise features
- You want the fastest solution

**Choose OPTION 2 if:**
- You want proper reCAPTCHA Enterprise integration
- You need reCAPTCHA for security/abuse prevention
- You're willing to spend 10 minutes setting it up

## My Recommendation

**Start with OPTION 1** to get authentication working immediately, then implement OPTION 2 later if you need reCAPTCHA features.

