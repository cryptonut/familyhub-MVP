package com.example.familyhub_mvp.widgets

import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.widget.RemoteViews
import com.example.familyhub_mvp.R
import com.google.firebase.firestore.FirebaseFirestore
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
        val familyId = prefs.getString("widget_${appWidgetId}_familyId", null) ?: return
        val widgetSize = prefs.getString("widget_${appWidgetId}_size", "medium") ?: "medium"
        
        val layoutResId = when (widgetSize) {
            "small" -> R.layout.widget_family_hub_small
            "large" -> R.layout.widget_family_hub_large
            else -> R.layout.widget_family_hub_medium
        }
        
        val views = RemoteViews(context.packageName, layoutResId)
        val appWidgetManager = AppWidgetManager.getInstance(context)
        
        // Fetch upcoming events
        fetchUpcomingEvents(familyId, 3) { events ->
            if (events.isNotEmpty()) {
                val eventText = events.joinToString("\n") { event ->
                    "${dateFormat.format(event["startTime"] as Date)}: ${event["title"]}"
                }
                views.setTextViewText(R.id.widget_events, eventText)
            } else {
                views.setTextViewText(R.id.widget_events, "No upcoming events")
            }
            
            // Fetch unread message count
            fetchUnreadMessageCount(familyId) { count ->
                if (count > 0) {
                    views.setTextViewText(R.id.widget_message_count, count.toString())
                    views.setViewVisibility(R.id.widget_message_badge, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_message_badge, android.view.View.GONE)
                }
                
                // Update widget
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }

    private fun fetchUpcomingEvents(familyId: String, limit: Int, callback: (List<Map<String, Any>>) -> Unit) {
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

