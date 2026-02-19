package com.ethosnote.app.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.ethosnote.app.R
import org.json.JSONObject
import java.util.Calendar

data class CalendarCell(
    val dayNumber: Int,
    val isCurrentMonth: Boolean,
    val isToday: Boolean,
    val dateKey: String, // "year-month-day" matching Flutter format
    val eventColors: List<Int> // up to 3 category colors
)

class CalendarRemoteViewsFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private var cells: List<CalendarCell> = emptyList()
    private var eventsMap: Map<String, List<Int>> = emptyMap() // dateKey → list of colors

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    private fun loadData() {
        val prefs = context.getSharedPreferences(WidgetConstants.PREFS_NAME, Context.MODE_PRIVATE)
        val viewMode = prefs.getString(WidgetConstants.CALENDAR_VIEW_MODE_KEY, "month") ?: "month"
        val offset = prefs.getInt(WidgetConstants.CALENDAR_OFFSET_KEY, 0)

        // Parse events JSON
        eventsMap = parseEventsJson(prefs.getString(WidgetConstants.CALENDAR_EVENTS_KEY, null))

        cells = if (viewMode == "week") {
            buildWeekCells(offset)
        } else {
            buildMonthCells(offset)
        }
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
        val month = cal.get(Calendar.MONTH) // 0-based
        val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

        // Day of week for first day (Monday=1 in our grid)
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
            cells.add(CalendarCell(day, false, false, key, eventsMap[key] ?: emptyList()))
        }

        // Current month days
        val todayYear = today.get(Calendar.YEAR)
        val todayMonth = today.get(Calendar.MONTH) + 1
        val todayDay = today.get(Calendar.DAY_OF_MONTH)

        for (day in 1..daysInMonth) {
            val flutterMonth = month + 1
            val key = "$year-$flutterMonth-$day"
            val isToday = year == todayYear && flutterMonth == todayMonth && day == todayDay
            cells.add(CalendarCell(day, true, isToday, key, eventsMap[key] ?: emptyList()))
        }

        // Next month padding to fill 42 cells (6 rows)
        val nextMonth = if (month == 11) 1 else month + 2
        val nextYear = if (month == 11) year + 1 else year
        val remaining = 42 - cells.size
        for (day in 1..remaining) {
            val key = "$nextYear-$nextMonth-$day"
            cells.add(CalendarCell(day, false, false, key, eventsMap[key] ?: emptyList()))
        }

        return cells
    }

    private fun buildWeekCells(weekOffset: Int): List<CalendarCell> {
        val today = Calendar.getInstance()
        val cal = Calendar.getInstance().apply {
            // Go to Monday of current week
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
            cells.add(CalendarCell(day, true, isToday, key, eventsMap[key] ?: emptyList()))
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return cells
    }

    override fun getCount(): Int = cells.size

    override fun getViewAt(position: Int): RemoteViews {
        val cell = cells[position]
        val views = RemoteViews(context.packageName, R.layout.widget_calendar_cell)

        // Day number
        if (cell.dayNumber > 0) {
            views.setTextViewText(R.id.txt_day_number, cell.dayNumber.toString())
            views.setViewVisibility(R.id.txt_day_number, View.VISIBLE)
        } else {
            views.setTextViewText(R.id.txt_day_number, "")
        }

        // Dim non-current-month days
        val textColor = when {
            !cell.isCurrentMonth -> 0x44000000
            else -> 0xFF000000.toInt()
        }
        views.setTextColor(R.id.txt_day_number, textColor)

        // Today circle
        views.setViewVisibility(R.id.today_circle, if (cell.isToday) View.VISIBLE else View.GONE)

        // Event dots
        val dotIds = listOf(R.id.dot1, R.id.dot2, R.id.dot3)
        for (i in dotIds.indices) {
            if (i < cell.eventColors.size) {
                views.setViewVisibility(dotIds[i], View.VISIBLE)
                views.setInt(dotIds[i], "setBackgroundColor", cell.eventColors[i])
            } else {
                views.setViewVisibility(dotIds[i], View.GONE)
            }
        }

        // Fill-in intent for click → deep link to that date
        val fillIntent = Intent().apply {
            data = Uri.parse("ethosnote://calendar/${cell.dateKey}")
        }
        views.setOnClickFillInIntent(R.id.txt_day_number, fillIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    override fun onDestroy() {}
}
