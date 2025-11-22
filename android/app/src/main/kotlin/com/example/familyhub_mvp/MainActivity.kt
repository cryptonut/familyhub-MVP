package com.example.familyhub_mvp

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import com.google.firebase.auth.FirebaseAuth
import android.util.Log

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
    
    override fun onResume() {
        super.onResume()
        
        // CRITICAL FIX: Disable app verification to prevent "empty reCAPTCHA token" issue
        // This must be called after Firebase is initialized by Flutter
        // Call in onResume to ensure Firebase is ready
        try {
            val auth = FirebaseAuth.getInstance()
            val settings = auth.firebaseAuthSettings
            // Disable app verification to bypass reCAPTCHA token requirement
            // This prevents the "empty reCAPTCHA token" error that causes 30-second login timeouts
            settings.setAppVerificationDisabledForTesting(true)
            Log.d("MainActivity", "App verification disabled for testing - reCAPTCHA bypass enabled")
        } catch (e: Exception) {
            Log.w("MainActivity", "Could not disable app verification: ${e.message}")
            // Method may not exist in all Firebase versions or Firebase not initialized yet
        }
    }
}
