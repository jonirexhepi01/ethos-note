package com.ethosnote.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import com.ethosnote.app.R
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "android.appwidget.action.APPWIDGET_UPDATE") {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, CalendarWidgetProvider::class.java)
            )
            mgr.notifyAppWidgetViewDataChanged(ids, R.id.cal_events_list)
        }
    }

    companion object {
        private val DAY_IDS = arrayOf(
            intArrayOf(R.id.day_0_0, R.id.day_0_1, R.id.day_0_2, R.id.day_0_3, R.id.day_0_4, R.id.day_0_5, R.id.day_0_6),
            intArrayOf(R.id.day_1_0, R.id.day_1_1, R.id.day_1_2, R.id.day_1_3, R.id.day_1_4, R.id.day_1_5, R.id.day_1_6),
            intArrayOf(R.id.day_2_0, R.id.day_2_1, R.id.day_2_2, R.id.day_2_3, R.id.day_2_4, R.id.day_2_5, R.id.day_2_6),
            intArrayOf(R.id.day_3_0, R.id.day_3_1, R.id.day_3_2, R.id.day_3_3, R.id.day_3_4, R.id.day_3_5, R.id.day_3_6),
            intArrayOf(R.id.day_4_0, R.id.day_4_1, R.id.day_4_2, R.id.day_4_3, R.id.day_4_4, R.id.day_4_5, R.id.day_4_6),
            intArrayOf(R.id.day_5_0, R.id.day_5_1, R.id.day_5_2, R.id.day_5_3, R.id.day_5_4, R.id.day_5_5, R.id.day_5_6),
        )

        private val DOT_IDS = arrayOf(
            intArrayOf(R.id.dot_0_0, R.id.dot_0_1, R.id.dot_0_2, R.id.dot_0_3, R.id.dot_0_4, R.id.dot_0_5, R.id.dot_0_6),
            intArrayOf(R.id.dot_1_0, R.id.dot_1_1, R.id.dot_1_2, R.id.dot_1_3, R.id.dot_1_4, R.id.dot_1_5, R.id.dot_1_6),
            intArrayOf(R.id.dot_2_0, R.id.dot_2_1, R.id.dot_2_2, R.id.dot_2_3, R.id.dot_2_4, R.id.dot_2_5, R.id.dot_2_6),
            intArrayOf(R.id.dot_3_0, R.id.dot_3_1, R.id.dot_3_2, R.id.dot_3_3, R.id.dot_3_4, R.id.dot_3_5, R.id.dot_3_6),
            intArrayOf(R.id.dot_4_0, R.id.dot_4_1, R.id.dot_4_2, R.id.dot_4_3, R.id.dot_4_4, R.id.dot_4_5, R.id.dot_4_6),
            intArrayOf(R.id.dot_5_0, R.id.dot_5_1, R.id.dot_5_2, R.id.dot_5_3, R.id.dot_5_4, R.id.dot_5_5, R.id.dot_5_6),
        )

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
            val prefs = HomeWidgetPlugin.getData(context)
            val bgColor = prefs.getInt("widget_bg", 0)
            val accentColor = prefs.getInt("widget_icon_bg", 0)

            val isNightMode = (context.resources.configuration.uiMode and
                    Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

            val effectiveBg = if (bgColor != 0) bgColor else if (isNightMode) 0xFF1C1B1F.toInt() else 0xFFFFFFFF.toInt()
            val effectiveAccent = if (accentColor != 0) accentColor else 0xFF1E88E5.toInt()
            val isLight = isLightColor(effectiveBg)
            val textColor = if (isLight) 0xFF1C1B1F.toInt() else 0xFFFFFFFF.toInt()
            val dimTextColor = if (isLight) 0x66000000 else 0x66FFFFFF
            val headerTextColor = if (isLight) 0xFF1C1B1F.toInt() else 0xFFE0E0E0.toInt()

            val views = RemoteViews(context.packageName, R.layout.widget_calendar)

            // Background
            views.setInt(R.id.cal_widget_root, "setBackgroundColor", effectiveBg)

            // Today's info
            val now = Calendar.getInstance()
            val monthYear = SimpleDateFormat("MMMM yyyy", Locale.getDefault()).format(now.time)
                .replaceFirstChar { it.uppercase() }
            views.setTextViewText(R.id.cal_month_year, monthYear)
            views.setTextColor(R.id.cal_month_year, headerTextColor)

            val todayStr = SimpleDateFormat("EEEE d", Locale.getDefault()).format(now.time)
                .replaceFirstChar { it.uppercase() }
            views.setTextViewText(R.id.cal_today_label, todayStr)
            views.setTextColor(R.id.cal_today_label, effectiveAccent)

            // Day of week headers
            val dowIds = intArrayOf(R.id.dow_0, R.id.dow_1, R.id.dow_2, R.id.dow_3, R.id.dow_4, R.id.dow_5, R.id.dow_6)
            val dowNames = arrayOf("L", "M", "M", "G", "V", "S", "D")
            for (i in 0..6) {
                views.setTextViewText(dowIds[i], dowNames[i])
                views.setTextColor(dowIds[i], dimTextColor)
            }

            // Build calendar grid
            val cal = Calendar.getInstance()
            cal.set(Calendar.DAY_OF_MONTH, 1)
            val firstDayOfWeek = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 // Monday = 0
            val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
            val todayDay = now.get(Calendar.DAY_OF_MONTH)
            val todayMonth = now.get(Calendar.MONTH)
            val todayYear = now.get(Calendar.YEAR)
            val currentMonth = cal.get(Calendar.MONTH)
            val currentYear = cal.get(Calendar.YEAR)

            // Load events from SharedPreferences
            val eventsJson = prefs.getString("cal_widget_events", "[]") ?: "[]"
            val eventDays = mutableSetOf<Int>()
            try {
                val arr = JSONArray(eventsJson)
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    val day = obj.getInt("day")
                    val month = obj.getInt("month")
                    val year = obj.getInt("year")
                    if (month == currentMonth + 1 && year == currentYear) {
                        eventDays.add(day)
                    }
                }
            } catch (_: Exception) {}

            // Previous month days
            val prevCal = Calendar.getInstance()
            prevCal.set(Calendar.DAY_OF_MONTH, 1)
            prevCal.add(Calendar.MONTH, -1)
            val prevDaysInMonth = prevCal.getActualMaximum(Calendar.DAY_OF_MONTH)

            // Fill grid
            var dayCounter = 1
            var nextMonthDay = 1
            for (row in 0..5) {
                for (col in 0..6) {
                    val cellPos = row * 7 + col
                    val dayId = DAY_IDS[row][col]
                    val dotId = DOT_IDS[row][col]

                    if (cellPos < firstDayOfWeek) {
                        // Previous month
                        val prevDay = prevDaysInMonth - firstDayOfWeek + cellPos + 1
                        views.setTextViewText(dayId, prevDay.toString())
                        views.setTextColor(dayId, dimTextColor)
                        views.setInt(dayId, "setBackgroundResource", 0)
                        views.setViewVisibility(dotId, android.view.View.INVISIBLE)
                    } else if (dayCounter <= daysInMonth) {
                        // Current month
                        views.setTextViewText(dayId, dayCounter.toString())

                        val isToday = dayCounter == todayDay && currentMonth == todayMonth && currentYear == todayYear
                        if (isToday) {
                            views.setInt(dayId, "setBackgroundResource", R.drawable.widget_cal_today_bg)
                            views.setInt(dayId, "setBackgroundColor", effectiveAccent)
                            views.setTextColor(dayId, if (isLightColor(effectiveAccent)) 0xFF000000.toInt() else 0xFFFFFFFF.toInt())
                        } else {
                            views.setInt(dayId, "setBackgroundResource", 0)
                            views.setTextColor(dayId, textColor)
                        }

                        // Event dot
                        if (eventDays.contains(dayCounter)) {
                            views.setViewVisibility(dotId, android.view.View.VISIBLE)
                            views.setInt(dotId, "setColorFilter", effectiveAccent)
                        } else {
                            views.setViewVisibility(dotId, android.view.View.INVISIBLE)
                        }

                        // Click opens calendar at date
                        val dateUri = "ethosnote://calendar/date/${currentYear}-${currentMonth + 1}-${dayCounter}"
                        views.setOnClickPendingIntent(dayId, buildDeepLinkIntent(context, dateUri, 100 + cellPos))

                        dayCounter++
                    } else {
                        // Next month
                        views.setTextViewText(dayId, nextMonthDay.toString())
                        views.setTextColor(dayId, dimTextColor)
                        views.setInt(dayId, "setBackgroundResource", 0)
                        views.setViewVisibility(dotId, android.view.View.INVISIBLE)
                        nextMonthDay++
                    }
                }
            }

            // Header click → open calendar
            views.setOnClickPendingIntent(R.id.cal_header,
                buildDeepLinkIntent(context, "ethosnote://calendar", 99))

            // Add event button
            views.setOnClickPendingIntent(R.id.cal_add_btn,
                buildDeepLinkIntent(context, "ethosnote://calendar/new", 98))
            views.setInt(R.id.cal_add_btn, "setColorFilter", effectiveAccent)

            // --- Upcoming events list ---
            // Theme divider and label
            val dividerColor = if (isLight) 0x1A000000 else 0x1AFFFFFF
            views.setInt(R.id.cal_divider, "setBackgroundColor", dividerColor)
            views.setTextColor(R.id.cal_events_label, if (isLight) 0x99000000.toInt() else 0x99FFFFFF.toInt())

            // Check if there are upcoming events
            val upcomingJson = prefs.getString("cal_widget_upcoming", "[]") ?: "[]"
            val hasEvents = try { JSONArray(upcomingJson).length() > 0 } catch (_: Exception) { false }

            if (hasEvents) {
                views.setViewVisibility(R.id.cal_events_list, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.cal_no_events, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.cal_events_list, android.view.View.GONE)
                views.setViewVisibility(R.id.cal_no_events, android.view.View.VISIBLE)
                views.setTextColor(R.id.cal_no_events, dimTextColor)
            }

            // Set up RemoteViews adapter for ListView
            val serviceIntent = Intent(context, CalendarWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.cal_events_list, serviceIntent)
            views.setEmptyView(R.id.cal_events_list, R.id.cal_no_events)

            // Set up fill-in intent template for list item clicks
            val clickTemplate = Intent(Intent.ACTION_VIEW).apply {
                setClassName(context.packageName, "com.ethosnote.app.MainActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val clickPending = PendingIntent.getActivity(
                context, 200, clickTemplate,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.cal_events_list, clickPending)

            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.cal_events_list)
        }

        private fun buildDeepLinkIntent(context: Context, uri: String, requestCode: Int): PendingIntent {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).apply {
                setClassName(context.packageName, "com.ethosnote.app.MainActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            return PendingIntent.getActivity(
                context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun isLightColor(color: Int): Boolean {
            val r = Color.red(color)
            val g = Color.green(color)
            val b = Color.blue(color)
            val luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
            return luminance > 0.5
        }
    }
}
