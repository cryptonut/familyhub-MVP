package com.example.familyhub_mvp.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.example.familyhub_mvp.R

/**
 * Widget Provider for Family Hub
 * 
 * Handles widget updates and tap actions for Family Hub widgets on the Android home screen.
 * Supports multiple widget instances (one per hub).
 */
class FamilyHubWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Update all widget instances
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        // Handle widget tap - open app with deep link
        if (intent.action == "com.example.familyhub_mvp.ACTION_WIDGET_TAP") {
            val hubId = intent.getStringExtra("hubId")
            val hubType = intent.getStringExtra("hubType")
            
            // Create deep link intent
            val deepLinkIntent = Intent(context, com.example.familyhub_mvp.MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("hubId", hubId)
                putExtra("hubType", hubType)
                data = android.net.Uri.parse("familyhub://hub/$hubId")
            }
            
            context.startActivity(deepLinkIntent)
        }
    }

    companion object {
        internal fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // Get widget configuration
            val prefs = context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
            val hubId = prefs.getString("widget_${appWidgetId}_hubId", null)
            val hubName = prefs.getString("widget_${appWidgetId}_hubName", "Family Hub")
            val hubType = prefs.getString("widget_${appWidgetId}_hubType", "family")
            
            if (hubId == null) {
                // Widget not configured yet - show placeholder
                val views = RemoteViews(context.packageName, R.layout.widget_family_hub_medium)
                views.setTextViewText(R.id.widget_hub_name, "Tap to configure")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }
            
            // Create RemoteViews based on widget size
            val widgetSize = prefs.getString("widget_${appWidgetId}_size", "medium")
            val layoutResId = when (widgetSize) {
                "small" -> R.layout.widget_family_hub_small
                "large" -> R.layout.widget_family_hub_large
                else -> R.layout.widget_family_hub_medium
            }
            
            val views = RemoteViews(context.packageName, layoutResId)
            
            // Set hub name
            views.setTextViewText(R.id.widget_hub_name, hubName)
            
            // Set tap action
            val tapIntent = Intent(context, FamilyHubWidgetProvider::class.java).apply {
                action = "com.example.familyhub_mvp.ACTION_WIDGET_TAP"
                putExtra("hubId", hubId)
                putExtra("hubType", hubType)
            }
            val tapPendingIntent = android.app.PendingIntent.getBroadcast(
                context,
                appWidgetId,
                tapIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, tapPendingIntent)
            
            // Update widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
            
            // Trigger data update via service
            val updateIntent = Intent(context, WidgetUpdateService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            context.startService(updateIntent)
        }
    }
}

