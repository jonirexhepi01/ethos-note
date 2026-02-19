package com.ethosnote.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.ethosnote.app.R
import org.json.JSONObject
import java.util.Calendar

class CalendarWidgetProvider : AppWidgetProvider() {

    companion object {
        private val DAY_IDS = intArrayOf(
            R.id.d0, R.id.d1, R.id.d2, R.id.d3, R.id.d4, R.id.d5, R.id.d6,
            R.id.d7, R.id.d8, R.id.d9, R.id.d10, R.id.d11, R.id.d12, R.id.d13,
            R.id.d14, R.id.d15, R.id.d16, R.id.d17, R.id.d18, R.id.d19, R.id.d20,
            R.id.d21, R.id.d22, R.id.d23, R.id.d24, R.id.d25, R.id.d26, R.id.d27,
            R.id.d28, R.id.d29, R.id.d30, R.id.d31, R.id.d32, R.id.d33, R.id.d34,
            R.id.d35, R.id.d36, R.id.d37, R.id.d38, R.id.d39, R.id.d40, R.id.d41
        )
        private val DOT_IDS = intArrayOf(
            R.id.e0, R.id.e1, R.id.e2, R.id.e3, R.id.e4, R.id.e5, R.id.e6,
            R.id.e7, R.id.e8, R.id.e9, R.id.e10, R.id.e11, R.id.e12, R.id.e13,
            R.id.e14, R.id.e15, R.id.e16, R.id.e17, R.id.e18, R.id.e19, R.id.e20,
            R.id.e21, R.id.e22, R.id.e23, R.id.e24, R.id.e25, R.id.e26, R.id.e27,
            R.id.e28, R.id.e29, R.id.e30, R.id.e31, R.id.e32, R.id.e33, R.id.e34,
            R.id.e35, R.id.e36, R.id.e37, R.id.e38, R.id.e39, R.id.e40, R.id.e41
        )
        private val ROW_IDS = intArrayOf(
            R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4, R.id.row_5
        )
        private val MONTH_NAMES = arrayOf(
            "Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno",
            "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre"
        )
    }

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
                val viewMode = prefs.getString(WidgetConstants.CALENDAR_VIEW_MODE_KEY, "month") ?: "month"
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
        for (id in ids) {
            updateWidget(context, mgr, id)
        }
    }

    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
        val prefs = context.getSharedPreferences(WidgetConstants.PREFS_NAME, Context.MODE_PRIVATE)
        val viewMode = prefs.getString(WidgetConstants.CALENDAR_VIEW_MODE_KEY, "month") ?: "month"
        val offset = prefs.getInt(WidgetConstants.CALENDAR_OFFSET_KEY, 0)

        val views = RemoteViews(context.packageName, R.layout.widget_calendar)

        // Parse events
        val eventsMap = parseEventsJson(prefs.getString(WidgetConstants.CALENDAR_EVENTS_KEY, null))

        // Header
        val cal = Calendar.getInstance()
        if (viewMode == "month") {
            cal.add(Calendar.MONTH, offset)
        } else {
            cal.add(Calendar.WEEK_OF_YEAR, offset)
        }
        val monthName = MONTH_NAMES[cal.get(Calendar.MONTH)]
        val year = cal.get(Calendar.YEAR)
        views.setTextViewText(R.id.txt_month_year, "$monthName $year")
        views.setTextViewText(R.id.btn_toggle_view, if (viewMode == "month") "Mese" else "Sett.")

        // Navigation buttons
        views.setOnClickPendingIntent(R.id.btn_prev,
            buildActionIntent(context, WidgetConstants.ACTION_PREV, 200))
        views.setOnClickPendingIntent(R.id.btn_next,
            buildActionIntent(context, WidgetConstants.ACTION_NEXT, 201))
        views.setOnClickPendingIntent(R.id.btn_toggle_view,
            buildActionIntent(context, WidgetConstants.ACTION_TOGGLE_VIEW, 202))

        // Build cells
        val isWeek = viewMode == "week"
        val cells = if (isWeek) buildWeekCells(offset) else buildMonthCells(offset)

        // Today info
        val today = Calendar.getInstance()
        val todayYear = today.get(Calendar.YEAR)
        val todayMonth = today.get(Calendar.MONTH) + 1
        val todayDay = today.get(Calendar.DAY_OF_MONTH)

        // Populate cells
        for (i in 0 until 42) {
            if (i < cells.size) {
                val cell = cells[i]
                views.setTextViewText(DAY_IDS[i], cell.dayNumber.toString())
                val textColor = when {
                    cell.isToday -> 0xFFF44336.toInt() // Red for today
                    !cell.isCurrentMonth -> 0x44000000 // Dim
                    else -> 0xFF000000.toInt()
                }
                views.setTextColor(DAY_IDS[i], textColor)

                // Today circle background
                if (cell.isToday) {
                    views.setInt(DAY_IDS[i], "setBackgroundResource", R.drawable.widget_calendar_today_circle)
                } else {
                    views.setInt(DAY_IDS[i], "setBackgroundResource", 0)
                }

                // Event dot
                val hasEvents = eventsMap.containsKey(cell.dateKey)
                views.setViewVisibility(DOT_IDS[i], if (hasEvents) View.VISIBLE else View.GONE)
                if (hasEvents) {
                    val colors = eventsMap[cell.dateKey]!!
                    val dotColor = if (colors.isNotEmpty()) colors[0] else 0xFF6366F1.toInt()
                    views.setInt(DOT_IDS[i], "setBackgroundColor", dotColor)
                }

                views.setViewVisibility(DAY_IDS[i], View.VISIBLE)
            } else {
                views.setTextViewText(DAY_IDS[i], "")
                views.setViewVisibility(DOT_IDS[i], View.GONE)
            }
        }

        // Row visibility: show all in month, only row 0 in week
        for (r in ROW_IDS.indices) {
            views.setViewVisibility(ROW_IDS[r], if (isWeek && r > 0) View.GONE else View.VISIBLE)
        }

        // Click on whole widget opens calendar in app
        val openAppIntent = Intent(Intent.ACTION_VIEW, Uri.parse("ethosnote://calendar")).apply {
            setClassName(context.packageName, "com.ethosnote.app.MainActivity")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val openAppPI = PendingIntent.getActivity(
            context, 300, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // Set click on each row to open app
        for (rowId in ROW_IDS) {
            views.setOnClickPendingIntent(rowId, openAppPI)
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun parseEventsJson(json: String?): Map<String, List<Int>> {
        if (json.isNullOrEmpty()) return emptyMap()
        val result = mutableMapOf<String, MutableList<Int>>()
        try {
            val root = JSONObject(json)
            val keys = root.keys()
            while (keys.hasNext()) {
                val dateKey = keys.next()
                val arr = root.getJSONArray(dateKey)
                val colors = mutableListOf<Int>()
                for (i in 0 until minOf(arr.length(), 3)) {
                    val event = arr.getJSONObject(i)
                    val category = event.optString("calendar", "")
                    colors.add(WidgetConstants.getCategoryColor(category))
                }
                result[dateKey] = colors
            }
        } catch (_: Exception) {}
        return result
    }

    private fun buildMonthCells(monthOffset: Int): List<CalendarCell> {
        val today = Calendar.getInstance()
        val cal = Calendar.getInstance().apply {
            add(Calendar.MONTH, monthOffset)
            set(Calendar.DAY_OF_MONTH, 1)
        }

        val year = cal.get(Calendar.YEAR)
        val month = cal.get(Calendar.MONTH)
        val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

        var firstDow = cal.get(Calendar.DAY_OF_WEEK) - Calendar.MONDAY
        if (firstDow < 0) firstDow += 7

        val cells = mutableListOf<CalendarCell>()

        // Previous month padding
        val prevCal = Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month)
            add(Calendar.MONTH, -1)
        }
        val prevMonthDays = prevCal.getActualMaximum(Calendar.DAY_OF_MONTH)
        val prevYear = prevCal.get(Calendar.YEAR)
        val prevMonth = prevCal.get(Calendar.MONTH) + 1

        for (i in firstDow - 1 downTo 0) {
            val day = prevMonthDays - i
            val key = "$prevYear-$prevMonth-$day"
            cells.add(CalendarCell(day, false, false, key, emptyList()))
        }

        // Current month
        val todayYear = today.get(Calendar.YEAR)
        val todayMonth = today.get(Calendar.MONTH) + 1
        val todayDay = today.get(Calendar.DAY_OF_MONTH)

        for (day in 1..daysInMonth) {
            val flutterMonth = month + 1
            val key = "$year-$flutterMonth-$day"
            val isToday = year == todayYear && flutterMonth == todayMonth && day == todayDay
            cells.add(CalendarCell(day, true, isToday, key, emptyList()))
        }

        // Next month padding to fill 42 cells
        val nextMonth = if (month == 11) 1 else month + 2
        val nextYear = if (month == 11) year + 1 else year
        val remaining = 42 - cells.size
        for (day in 1..remaining) {
            val key = "$nextYear-$nextMonth-$day"
            cells.add(CalendarCell(day, false, false, key, emptyList()))
        }

        return cells
    }

    private fun buildWeekCells(weekOffset: Int): List<CalendarCell> {
        val today = Calendar.getInstance()
        val cal = Calendar.getInstance().apply {
            val dow = get(Calendar.DAY_OF_WEEK)
            val daysFromMonday = if (dow == Calendar.SUNDAY) 6 else dow - Calendar.MONDAY
            add(Calendar.DAY_OF_YEAR, -daysFromMonday)
            add(Calendar.WEEK_OF_YEAR, weekOffset)
        }

        val todayYear = today.get(Calendar.YEAR)
        val todayMonth = today.get(Calendar.MONTH) + 1
        val todayDay = today.get(Calendar.DAY_OF_MONTH)

        val cells = mutableListOf<CalendarCell>()
        for (i in 0 until 7) {
            val year = cal.get(Calendar.YEAR)
            val month = cal.get(Calendar.MONTH) + 1
            val day = cal.get(Calendar.DAY_OF_MONTH)
            val key = "$year-$month-$day"
            val isToday = year == todayYear && month == todayMonth && day == todayDay
            cells.add(CalendarCell(day, true, isToday, key, emptyList()))
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return cells
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
