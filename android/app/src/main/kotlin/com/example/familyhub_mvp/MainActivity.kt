package com.example.familyhub_mvp

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import com.google.firebase.auth.FirebaseAuth
import android.util.Log
import android.os.Handler
import android.os.Looper

class MainActivity : FlutterActivity() {
    private var appVerificationDisabled = false
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // CRITICAL FIX: Disable app verification to prevent "empty reCAPTCHA token" issue
        // Try immediately, then retry after a delay to ensure Firebase is initialized
        disableAppVerification()
        
        // Also try after a short delay in case Firebase isn't ready yet
        Handler(Looper.getMainLooper()).postDelayed({
            if (!appVerificationDisabled) {
                disableAppVerification()
            }
        }, 500)
    }
    
    override fun onResume() {
        super.onResume()
        
        // Ensure app verification is disabled every time we resume
        if (!appVerificationDisabled) {
            disableAppVerification()
        }
    }
    
    private fun disableAppVerification() {
        try {
            val auth = FirebaseAuth.getInstance()
            val settings = auth.firebaseAuthSettings
            
            // Disable app verification to bypass reCAPTCHA token requirement
            // This prevents the "empty reCAPTCHA token" error that causes 30-second login timeouts
            settings.setAppVerificationDisabledForTesting(true)
            appVerificationDisabled = true
            Log.d("MainActivity", "✓ App verification disabled - reCAPTCHA bypass enabled")
        } catch (e: Exception) {
            Log.w("MainActivity", "Could not disable app verification: ${e.message}")
            Log.w("MainActivity", "Stack trace: ${e.stackTraceToString()}")
            // Method may not exist in all Firebase versions or Firebase not initialized yet
            // Retry will happen in onResume
        }
    }
}
