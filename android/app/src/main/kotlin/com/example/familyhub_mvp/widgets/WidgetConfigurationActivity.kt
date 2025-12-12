package com.example.familyhub_mvp.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.Spinner
import android.widget.TextView
import com.example.familyhub_mvp.R
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

/**
 * Configuration Activity for Family Hub Widget
 * 
 * Allows users to select which hub to display in the widget,
 * choose widget size, and configure display options.
 */
class WidgetConfigurationActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Set result to CANCELED in case user backs out
        setResult(RESULT_CANCELED)
        
        // Get widget ID from intent
        val intent = intent
        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
        }

        // If no valid widget ID, finish
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        // Set up UI (simplified - will be enhanced with proper layout)
        setContentView(R.layout.activity_widget_config)
        
        val hubSpinner = findViewById<Spinner>(R.id.hub_spinner)
        val sizeSpinner = findViewById<Spinner>(R.id.size_spinner)
        val saveButton = findViewById<Button>(R.id.save_button)
        
        // Load user's hubs
        loadUserHubs { hubs ->
            val adapter = ArrayAdapter(
                this,
                android.R.layout.simple_spinner_item,
                hubs.map { it["name"] as String }
            )
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            hubSpinner.adapter = adapter
        }
        
        // Widget size options
        val sizeAdapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            listOf("Small (1x1)", "Medium (2x1)", "Large (2x2)")
        )
        sizeAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        sizeSpinner.adapter = sizeAdapter
        
        // Save button click
        saveButton.setOnClickListener {
            saveWidgetConfiguration()
        }
    }

    private fun loadUserHubs(callback: (List<Map<String, Any>>) -> Unit) {
        val userId = auth.currentUser?.uid ?: return
        
        // Load user's hubs from Firestore
        // TODO: Implement proper hub loading based on your data structure
        // For now, return empty list
        callback(emptyList())
    }

    private fun saveWidgetConfiguration() {
        val prefs = getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        
        // Save widget configuration
        // TODO: Get selected hub and size from UI
        val hubId = "default_hub" // Placeholder
        val hubName = "Family Hub" // Placeholder
        val hubType = "family" // Placeholder
        val widgetSize = "medium" // Placeholder
        
        editor.putString("widget_${appWidgetId}_hubId", hubId)
        editor.putString("widget_${appWidgetId}_hubName", hubName)
        editor.putString("widget_${appWidgetId}_hubType", hubType)
        editor.putString("widget_${appWidgetId}_size", widgetSize)
        editor.apply()
        
        // Update widget
        val appWidgetManager = AppWidgetManager.getInstance(this)
        FamilyHubWidgetProvider.updateAppWidget(this, appWidgetManager, appWidgetId)
        
        // Return result
        val resultValue = Intent().apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        setResult(RESULT_OK, resultValue)
        finish()
    }
}

