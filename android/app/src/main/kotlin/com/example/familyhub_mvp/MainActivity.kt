package com.example.familyhub_mvp

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity - Standard Flutter Activity
 * 
 * reCAPTCHA Enterprise is now handled by the Flutter package (recaptcha_enterprise_flutter)
 * initialized in main.dart before Firebase Auth. No workarounds needed.
 * 
 * Also handles deep links from widgets.
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.familyhub_mvp/deep_link"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialDeepLink") {
                // Get deep link from intent if available
                val intent = intent
                val deepLink = getDeepLinkFromIntent(intent)
                result.success(deepLink)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLink(intent)
    }

    private fun handleDeepLink(intent: Intent?) {
        if (intent == null) return
        
        val deepLink = getDeepLinkFromIntent(intent)
        if (deepLink != null) {
            // Send deep link to Flutter
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onDeepLink", deepLink)
            }
        }
    }

    private fun getDeepLinkFromIntent(intent: Intent): String? {
        // Check for deep link from widget tap
        val hubId = intent.getStringExtra("hubId")
        val hubType = intent.getStringExtra("hubType")
        
        if (hubId != null) {
            return if (hubType != null) {
                "familyhub://hub/$hubId?type=$hubType"
            } else {
                "familyhub://hub/$hubId"
            }
        }
        
        // Check for URI from deep link intent filter
        val data: Uri? = intent.data
        return data?.toString()
    }
}
