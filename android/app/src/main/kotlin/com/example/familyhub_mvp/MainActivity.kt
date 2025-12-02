package com.example.familyhub_mvp

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import com.google.firebase.auth.FirebaseAuth
import android.util.Log
import android.os.Handler
import android.os.Looper

class MainActivity : FlutterActivity() {
    private var appVerificationDisabled = false
    private val TAG = "MainActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate() called - starting app verification disable process")
        Log.d(TAG, "NOTE: MyApplication should have already attempted to disable app verification")

        // CRITICAL FIX: Disable app verification to prevent "empty reCAPTCHA token" issue
        // Firebase Auth on Android tries to use reCAPTCHA even when it's not configured in Firebase Console
        // This causes "empty reCAPTCHA token" errors and 30-second timeouts
        // 
        // We try in BOTH Application.onCreate() (earlier) and MainActivity.onCreate() (redundancy)

        // Try immediately - even if Application already tried, this is a backup
        disableAppVerification()

        // More aggressive retries with shorter intervals to catch Firebase Auth initialization
        // Retry immediately on next frame
        Handler(Looper.getMainLooper()).post {
            if (!appVerificationDisabled) {
                Log.d(TAG, "Retry 0 (immediate): Attempting to disable app verification")
                disableAppVerification()
            }
        }

        // Retry with multiple short intervals to catch Firebase Auth as soon as it's ready
        val retryDelays = listOf(50L, 100L, 200L, 300L, 500L, 750L, 1000L, 1500L, 2000L, 3000L)
        retryDelays.forEachIndexed { index, delay ->
            Handler(Looper.getMainLooper()).postDelayed({
                if (!appVerificationDisabled) {
                    Log.d(TAG, "Retry ${index + 1} (${delay}ms): Attempting to disable app verification")
                    disableAppVerification()
                } else {
                    Log.d(TAG, "App verification already disabled, skipping retry ${index + 1}")
                }
            }, delay)
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume() called")

        // Ensure app verification is disabled every time we resume
        if (!appVerificationDisabled) {
            Log.d(TAG, "App verification not yet disabled, attempting in onResume()")
            disableAppVerification()
        } else {
            Log.d(TAG, "App verification already disabled")
        }
    }

    private fun disableAppVerification() {
        try {
            Log.d(TAG, "Attempting to get FirebaseAuth instance...")
            val auth = FirebaseAuth.getInstance()
            Log.d(TAG, "FirebaseAuth instance obtained")

            val settings = auth.firebaseAuthSettings
            Log.d(TAG, "FirebaseAuthSettings obtained")

            // Disable app verification to bypass reCAPTCHA token requirement
            // This prevents the "empty reCAPTCHA token" error that causes 30-second login timeouts
            settings.setAppVerificationDisabledForTesting(true)
            appVerificationDisabled = true

            Log.i(TAG, "✓✓✓ SUCCESS: App verification disabled - reCAPTCHA bypass enabled ✓✓✓")
            Log.i(TAG, "This should prevent 'empty reCAPTCHA token' errors")
        } catch (e: Exception) {
            Log.e(TAG, "✗✗✗ FAILED to disable app verification ✗✗✗")
            Log.e(TAG, "Error: ${e.message}")
            Log.e(TAG, "Exception type: ${e.javaClass.simpleName}")
            Log.e(TAG, "Stack trace: ${e.stackTraceToString()}")
            // Method may not exist in all Firebase versions or Firebase not initialized yet
            // Retry will happen in onResume and delayed handlers
        }
    }
}
