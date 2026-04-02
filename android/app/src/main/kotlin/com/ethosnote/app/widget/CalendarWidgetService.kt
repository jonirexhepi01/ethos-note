package com.ethosnote.app.widget

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.ethosnote.app.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class CalendarWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CalendarEventFactory(applicationContext)
    }
}

class CalendarEventFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    data class EventItem(
        val title: String,
        val hour: Int,
        val minute: Int,
        val day: Int,
        val month: Int,
        val year: Int,
        val calendar: String,
        val completed: Boolean
    )

    private val items = mutableListOf<EventItem>()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items.clear()
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            val json = prefs.getString("cal_widget_upcoming", "[]") ?: "[]"
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                items.add(EventItem(
                    title = obj.optString("title", ""),
                    hour = obj.optInt("hour", 0),
                    minute = obj.optInt("minute", 0),
                    day = obj.optInt("day", 1),
                    month = obj.optInt("month", 1),
                    year = obj.optInt("year", 2026),
                    calendar = obj.optString("calendar", "Personale"),
                    completed = obj.optBoolean("completed", false)
                ))
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() { items.clear() }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_calendar_event_item)
        if (position >= items.size) return views
        val event = items[position]

        // Time text
        val timeStr = String.format("%02d:%02d", event.hour, event.minute)
        views.setTextViewText(R.id.event_time, timeStr)

        // Date label (show day/month if not today)
        val now = java.util.Calendar.getInstance()
        val isToday = event.day == now.get(java.util.Calendar.DAY_OF_MONTH) &&
                event.month == now.get(java.util.Calendar.MONTH) + 1 &&
                event.year == now.get(java.util.Calendar.YEAR)
        val dateStr = if (isToday) "Oggi" else String.format("%d/%02d", event.day, event.month)
        views.setTextViewText(R.id.event_date, dateStr)

        // Title
        views.setTextViewText(R.id.event_title, event.title)

        // Colors from theme
        val prefs = HomeWidgetPlugin.getData(context)
        val bgColor = prefs.getInt("widget_bg", 0)
        val accentColor = prefs.getInt("widget_icon_bg", 0)
        val effectiveBg = if (bgColor != 0) bgColor else 0xFFFFFFFF.toInt()
        val effectiveAccent = if (accentColor != 0) accentColor else 0xFF1E88E5.toInt()
        val isLight = isLightColor(effectiveBg)
        val textColor = if (isLight) 0xFF1C1B1F.toInt() else 0xFFFFFFFF.toInt()
        val dimColor = if (isLight) 0x99000000.toInt() else 0x99FFFFFF.toInt()

        views.setTextColor(R.id.event_title, if (event.completed) dimColor else textColor)
        views.setTextColor(R.id.event_time, effectiveAccent)
        views.setTextColor(R.id.event_date, dimColor)

        // Accent dot
        views.setInt(R.id.event_dot, "setColorFilter", effectiveAccent)

        // Fill intent for click
        val fillIntent = Intent().apply {
            data = Uri.parse("ethosnote://calendar/date/${event.year}-${event.month}-${event.day}")
        }
        views.setOnClickFillInIntent(R.id.event_item_root, fillIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false

    private fun isLightColor(color: Int): Boolean {
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5
    }
}
