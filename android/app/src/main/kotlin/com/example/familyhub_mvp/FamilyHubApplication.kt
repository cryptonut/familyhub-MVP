package com.example.familyhub_mvp

import android.app.Application
import android.util.Log
import com.google.android.recaptcha.Recaptcha
import com.google.android.recaptcha.RecaptchaClient
import com.google.android.recaptcha.RecaptchaAction
import com.google.android.recaptcha.RecaptchaException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Custom Application class to initialize reCAPTCHA Enterprise client
 * This is required for Firebase Auth to generate reCAPTCHA tokens on Android
 */
class FamilyHubApplication : Application() {
    private lateinit var recaptchaClient: RecaptchaClient
    private val recaptchaScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val TAG = "FamilyHubApplication"
    
    // reCAPTCHA Enterprise site key
    // Get this from Firebase Console > Authentication > Settings > reCAPTCHA provider
    private val RECAPTCHA_SITE_KEY = "6LeprxosAAAAACXWuPlrlx0zOyM3GpJOVhBHvJ5e"
    
    override fun onCreate() {
        super.onCreate()
        val currentPackage = packageName
        Log.i(TAG, "═══════════════════════════════════════")
        Log.i(TAG, "FamilyHubApplication.onCreate() - Initializing reCAPTCHA")
        Log.i(TAG, "  - Package name: $currentPackage")
        Log.i(TAG, "  - Site key: $RECAPTCHA_SITE_KEY")
        Log.i(TAG, "═══════════════════════════════════════")
        initializeRecaptchaClient()
    }
    
    private fun initializeRecaptchaClient() {
        recaptchaScope.launch {
            try {
                val currentPackage = this@FamilyHubApplication.packageName
                Log.d(TAG, "Initializing reCAPTCHA client...")
                Log.d(TAG, "  - Package: $currentPackage")
                Log.d(TAG, "  - Site key: $RECAPTCHA_SITE_KEY")
                
                recaptchaClient = Recaptcha.fetchClient(this@FamilyHubApplication, RECAPTCHA_SITE_KEY)
                
                Log.i(TAG, "═══════════════════════════════════════")
                Log.i(TAG, "✓✓✓ reCAPTCHA client initialized successfully ✓✓✓")
                Log.i(TAG, "  - Package: $currentPackage")
                Log.i(TAG, "  - Firebase Auth can now generate reCAPTCHA tokens")
                Log.i(TAG, "═══════════════════════════════════════")
            } catch (e: RecaptchaException) {
                val currentPackage = this@FamilyHubApplication.packageName
                Log.e(TAG, "═══════════════════════════════════════")
                Log.e(TAG, "✗✗✗ reCAPTCHA initialization FAILED ✗✗✗")
                Log.e(TAG, "  - Error: ${e.message}")
                Log.e(TAG, "  - Error code: ${e.errorCode}")
                Log.e(TAG, "  - Package: $currentPackage")
                Log.e(TAG, "═══════════════════════════════════════")
                Log.e(TAG, "CRITICAL: Verify reCAPTCHA key configuration in Google Cloud Console")
                Log.e(TAG, "  1. Package name must match: $currentPackage")
                Log.e(TAG, "  2. SHA-1 fingerprint must be registered")
                Log.e(TAG, "  3. Site key must be correct: $RECAPTCHA_SITE_KEY")
                Log.e(TAG, "═══════════════════════════════════════")
            } catch (e: Exception) {
                val currentPackage = this@FamilyHubApplication.packageName
                Log.e(TAG, "═══════════════════════════════════════")
                Log.e(TAG, "✗✗✗ reCAPTCHA initialization ERROR ✗✗✗")
                Log.e(TAG, "  - Error: ${e.message}")
                Log.e(TAG, "  - Package: $currentPackage")
                Log.e(TAG, "  - Exception type: ${e.javaClass.simpleName}")
                Log.e(TAG, "═══════════════════════════════════════")
            }
        }
    }
    
    /**
     * Execute reCAPTCHA action (e.g., LOGIN) to generate token
     * This is called automatically by Firebase Auth when needed
     */
    fun executeRecaptcha(
        action: RecaptchaAction = RecaptchaAction.LOGIN,
        timeout: Long = 10000L,
        onSuccess: (String) -> Unit,
        onError: (Exception) -> Unit
    ) {
        if (!::recaptchaClient.isInitialized) {
            Log.w(TAG, "reCAPTCHA client not initialized yet")
            onError(Exception("reCAPTCHA client not initialized"))
            return
        }
        
        recaptchaScope.launch {
            try {
                Log.d(TAG, "Executing reCAPTCHA action: $action with timeout: ${timeout}ms")
                recaptchaClient.execute(action, timeout = timeout)
                    .onSuccess { token ->
                        Log.i(TAG, "✓ reCAPTCHA token obtained successfully")
                        onSuccess(token)
                    }
                    .onFailure { exception ->
                        Log.e(TAG, "✗ reCAPTCHA execution failed: ${exception.message}")
                        onError(Exception(exception.message ?: "reCAPTCHA execution failed"))
                    }
            } catch (e: Exception) {
                Log.e(TAG, "✗ reCAPTCHA execution error: ${e.message}")
                onError(e)
            }
        }
    }
}

