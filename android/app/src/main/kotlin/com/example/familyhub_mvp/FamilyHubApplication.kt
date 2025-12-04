package com.example.familyhub_mvp

import android.app.Application
import android.util.Log

/**
 * Custom Application class
 * 
 * CRITICAL: reCAPTCHA initialization has been DISABLED to prevent login hangs.
 * Firebase Auth works without explicit reCAPTCHA initialization in code.
 */
class FamilyHubApplication : Application() {
    private val TAG = "FamilyHubApplication"
    
    override fun onCreate() {
        super.onCreate()
        // reCAPTCHA initialization is not needed - Firebase Auth handles it automatically
    }
}

