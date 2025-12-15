package com.example.familyhub_mvp.widgets

import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.widget.RemoteViews
import com.example.familyhub_mvp.R
import com.google.firebase.firestore.FirebaseFirestore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.*

/**
 * Service to update widget data from Firestore
 * 
 * Fetches hub data (events, messages, tasks) and updates widget views.
 * Runs periodically or on-demand when widget is added/updated.
 */
class WidgetUpdateService : Service() {

    private val firestore = FirebaseFirestore.getInstance()
    private val dateFormat = SimpleDateFormat("MMM d", Locale.getDefault())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val appWidgetId = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1) ?: return START_NOT_STICKY
        
        updateWidgetData(this, appWidgetId)
        
        return START_NOT_STICKY
    }

    private fun updateWidgetData(context: Context, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
        val hubId = prefs.getString("widget_${appWidgetId}_hubId", null) ?: return
        val hubName = prefs.getString("widget_${appWidgetId}_hubName", "Family Hub") ?: "Family Hub"
        val hubType = prefs.getString("widget_${appWidgetId}_hubType", "family") ?: "family"
        val widgetSize = prefs.getString("widget_${appWidgetId}_size", "medium") ?: "medium"
        
        val layoutResId = when (widgetSize) {
            "small" -> R.layout.widget_family_hub_small
            "large" -> R.layout.widget_family_hub_large
            else -> R.layout.widget_family_hub_medium
        }
        
        val views = RemoteViews(context.packageName, layoutResId)
        val appWidgetManager = AppWidgetManager.getInstance(context)
        
        // Try to get widget data from Flutter via method channel
        // If Flutter is not available, fall back to direct Firestore access
        tryGetWidgetDataFromFlutter(context, appWidgetId, hubId, hubName, hubType) { widgetData ->
            if (widgetData != null) {
                // Use data from Flutter
                views.setTextViewText(R.id.widget_hub_name, widgetData["hubName"] as? String ?: hubName)
                
                val events = widgetData["upcomingEvents"] as? List<Map<String, Any>> ?: emptyList()
                if (events.isNotEmpty()) {
                    val eventText = events.joinToString("\n") { event ->
                        val startTime = (event["startTime"] as? String)?.let {
                            try {
                                java.time.Instant.parse(it).atZone(java.time.ZoneId.systemDefault()).toLocalDateTime()
                            } catch (e: Exception) {
                                null
                            }
                        }
                        val formattedDate = startTime?.let { dateFormat.format(Date.from(java.time.Instant.parse(event["startTime"] as String))) } ?: ""
                        "$formattedDate: ${event["title"]}"
                    }
                    views.setTextViewText(R.id.widget_events, eventText)
                } else {
                    views.setTextViewText(R.id.widget_events, "No upcoming events")
                }
                
                val unreadCount = (widgetData["unreadMessageCount"] as? Number)?.toInt() ?: 0
                if (unreadCount > 0) {
                    views.setTextViewText(R.id.widget_message_count, unreadCount.toString())
                    views.setViewVisibility(R.id.widget_message_badge, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_message_badge, android.view.View.GONE)
                }
                
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } else {
                // Fallback to direct Firestore access (legacy)
                val familyId = prefs.getString("widget_${appWidgetId}_familyId", null)
                if (familyId != null) {
                    fetchUpcomingEventsLegacy(familyId, 3) { events ->
                        if (events.isNotEmpty()) {
                            val eventText = events.joinToString("\n") { event ->
                                "${dateFormat.format(event["startTime"] as Date)}: ${event["title"]}"
                            }
                            views.setTextViewText(R.id.widget_events, eventText)
                        } else {
                            views.setTextViewText(R.id.widget_events, "No upcoming events")
                        }
                        
                        fetchUnreadMessageCount(familyId) { count ->
                            if (count > 0) {
                                views.setTextViewText(R.id.widget_message_count, count.toString())
                                views.setViewVisibility(R.id.widget_message_badge, android.view.View.VISIBLE)
                            } else {
                                views.setViewVisibility(R.id.widget_message_badge, android.view.View.GONE)
                            }
                            
                            appWidgetManager.updateAppWidget(appWidgetId, views)
                        }
                    }
                } else {
                    // No data available
                    views.setTextViewText(R.id.widget_hub_name, hubName)
                    views.setTextViewText(R.id.widget_events, "No data available")
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                }
            }
        }
    }
    
    private fun tryGetWidgetDataFromFlutter(
        context: Context,
        appWidgetId: Int,
        hubId: String,
        hubName: String,
        hubType: String,
        callback: (Map<String, Any>?) -> Unit
    ) {
        try {
            // Try to get Flutter engine
            val flutterEngine = FlutterEngineCache.getInstance().get("default")
            if (flutterEngine != null) {
                val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.familyhub_mvp/widget")
                val args = mapOf(
                    "widgetId" to appWidgetId.toString(),
                    "hubId" to hubId,
                    "hubName" to hubName,
                    "hubType" to hubType,
                    "widgetSize" to "medium",
                    "displayOptions" to mapOf(
                        "events" to true,
                        "messages" to true,
                        "tasks" to false,
                        "photos" to false
                    )
                )
                
                channel.invokeMethod("getWidgetData", args, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (result is Map<*, *>) {
                            @Suppress("UNCHECKED_CAST")
                            callback(result as Map<String, Any>)
                        } else {
                            callback(null)
                        }
                    }
                    
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        callback(null)
                    }
                    
                    override fun notImplemented() {
                        callback(null)
                    }
                })
            } else {
                callback(null)
            }
        } catch (e: Exception) {
            callback(null)
        }
    }

    private fun fetchUpcomingEventsLegacy(familyId: String, limit: Int, callback: (List<Map<String, Any>>) -> Unit) {
        val now = Date()
        firestore.collection("families")
            .document(familyId)
            .collection("events")
            .whereGreaterThan("startTime", now)
            .orderBy("startTime")
            .limit(limit.toLong())
            .get()
            .addOnSuccessListener { snapshot ->
                val events = snapshot.documents.map { doc ->
                    val data = doc.data ?: emptyMap()
                    mapOf(
                        "title" to (data["title"] as? String ?: ""),
                        "startTime" to (data["startTime"] as? Date ?: now)
                    )
                }
                callback(events)
            }
            .addOnFailureListener {
                callback(emptyList())
            }
    }

    private fun fetchUnreadMessageCount(familyId: String, callback: (Int) -> Unit) {
        // TODO: Implement unread message count query
        // For now, return 0
        callback(0)
    }
}

