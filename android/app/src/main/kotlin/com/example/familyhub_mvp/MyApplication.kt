package com.example.familyhub_mvp

import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import io.flutter.app.FlutterApplication

/**
 * Custom Application class to disable app verification BEFORE MainActivity runs.
 * 
 * This is critical because Firebase Auth may initialize reCAPTCHA during
 * Flutter engine initialization, which happens before MainActivity.onCreate().
 * 
 * By disabling app verification in Application.onCreate(), we catch Firebase Auth
 * before it can initialize reCAPTCHA, preventing "empty reCAPTCHA token" errors.
 */
class MyApplication : FlutterApplication() {
    private val TAG = "MyApplication"
    private var appVerificationDisabled = false

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate() called - Application starting")
        Log.d(TAG, "Attempting to disable app verification EARLIEST possible time")
        
        // Try immediately - this runs before MainActivity
        disableAppVerification()
        
        // Also try after a tiny delay in case Firebase isn't ready yet
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (!appVerificationDisabled) {
                Log.d(TAG, "Retry in Application: Attempting to disable app verification")
                disableAppVerification()
            }
        }, 100)
        
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (!appVerificationDisabled) {
                Log.d(TAG, "Retry 2 in Application (500ms): Attempting to disable app verification")
                disableAppVerification()
            }
        }, 500)
    }

    private fun disableAppVerification() {
        try {
            Log.d(TAG, "Attempting to get FirebaseAuth instance in Application...")
            val auth = FirebaseAuth.getInstance()
            Log.d(TAG, "FirebaseAuth instance obtained in Application")

            val settings = auth.firebaseAuthSettings
            Log.d(TAG, "FirebaseAuthSettings obtained in Application")

            // Disable app verification to bypass reCAPTCHA token requirement
            // This prevents the "empty reCAPTCHA token" error that causes 30-second login timeouts
            settings.setAppVerificationDisabledForTesting(true)
            appVerificationDisabled = true

            Log.i(TAG, "✓✓✓ SUCCESS: App verification disabled in Application class ✓✓✓")
            Log.i(TAG, "This should prevent 'empty reCAPTCHA token' errors")
            Log.i(TAG, "Application.onCreate() runs BEFORE MainActivity.onCreate()")
        } catch (e: Exception) {
            Log.e(TAG, "✗✗✗ FAILED to disable app verification in Application ✗✗✗")
            Log.e(TAG, "Error: ${e.message}")
            Log.e(TAG, "Exception type: ${e.javaClass.simpleName}")
            Log.e(TAG, "Stack trace: ${e.stackTraceToString()}")
            // Don't throw - MainActivity will also try
            Log.d(TAG, "MainActivity will also attempt to disable app verification")
        }
    }
}
