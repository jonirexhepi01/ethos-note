package com.ethosnote.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.ethosnote.app.R
import java.util.Calendar

class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val prefs = context.getSharedPreferences(WidgetConstants.PREFS_NAME, Context.MODE_PRIVATE)

        when (intent.action) {
            WidgetConstants.ACTION_PREV -> {
                val offset = prefs.getInt(WidgetConstants.CALENDAR_OFFSET_KEY, 0)
                prefs.edit().putInt(WidgetConstants.CALENDAR_OFFSET_KEY, offset - 1).apply()
                refreshAllWidgets(context)
            }
            WidgetConstants.ACTION_NEXT -> {
                val offset = prefs.getInt(WidgetConstants.CALENDAR_OFFSET_KEY, 0)
                prefs.edit().putInt(WidgetConstants.CALENDAR_OFFSET_KEY, offset + 1).apply()
                refreshAllWidgets(context)
            }
            WidgetConstants.ACTION_TOGGLE_VIEW -> {
                val current = prefs.getString(WidgetConstants.CALENDAR_VIEW_MODE_KEY, "month") ?: "month"
                val newMode = if (current == "month") "week" else "month"
                prefs.edit()
                    .putString(WidgetConstants.CALENDAR_VIEW_MODE_KEY, newMode)
                    .putInt(WidgetConstants.CALENDAR_OFFSET_KEY, 0)
                    .apply()
                refreshAllWidgets(context)
            }
        }
    }

    private fun refreshAllWidgets(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, CalendarWidgetProvider::class.java))
        // Notify data changed for the grid
        mgr.notifyAppWidgetViewDataChanged(ids, R.id.calendar_grid)
        // Re-render header
        for (id in ids) {
            updateWidget(context, mgr, id)
        }
    }

    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
        val prefs = context.getSharedPreferences(WidgetConstants.PREFS_NAME, Context.MODE_PRIVATE)
        val viewMode = prefs.getString(WidgetConstants.CALENDAR_VIEW_MODE_KEY, "month") ?: "month"
        val offset = prefs.getInt(WidgetConstants.CALENDAR_OFFSET_KEY, 0)

        val views = RemoteViews(context.packageName, R.layout.widget_calendar)

        // Header title
        val cal = Calendar.getInstance()
        if (viewMode == "month") {
            cal.add(Calendar.MONTH, offset)
        } else {
            cal.add(Calendar.WEEK_OF_YEAR, offset)
        }
        val monthNames = arrayOf("Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno",
            "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre")
        val monthName = monthNames[cal.get(Calendar.MONTH)]
        val year = cal.get(Calendar.YEAR)
        views.setTextViewText(R.id.txt_month_year, "$monthName $year")

        // Toggle button label
        views.setTextViewText(R.id.btn_toggle_view, if (viewMode == "month") "Mese" else "Sett.")

        // Prev button
        views.setOnClickPendingIntent(R.id.btn_prev,
            buildActionIntent(context, WidgetConstants.ACTION_PREV, 200))

        // Next button
        views.setOnClickPendingIntent(R.id.btn_next,
            buildActionIntent(context, WidgetConstants.ACTION_NEXT, 201))

        // Toggle view button
        views.setOnClickPendingIntent(R.id.btn_toggle_view,
            buildActionIntent(context, WidgetConstants.ACTION_TOGGLE_VIEW, 202))

        // Setup RemoteViews adapter for the grid
        val serviceIntent = Intent(context, CalendarRemoteViewsService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.calendar_grid, serviceIntent)

        // Template for day click → deep link
        val deepLinkTemplate = Intent(Intent.ACTION_VIEW).apply {
            setClassName(context.packageName, "com.ethosnote.app.MainActivity")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val templatePendingIntent = PendingIntent.getActivity(
            context, 203, deepLinkTemplate,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        views.setPendingIntentTemplate(R.id.calendar_grid, templatePendingIntent)

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun buildActionIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, CalendarWidgetProvider::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
