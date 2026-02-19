package com.ethosnote.app.widget

object WidgetConstants {
    const val PREFS_NAME = "HomeWidgetPreferences"
    const val CALENDAR_EVENTS_KEY = "calendar_widget_events"
    const val CALENDAR_VIEW_MODE_KEY = "calendar_widget_view_mode"
    const val CALENDAR_OFFSET_KEY = "calendar_widget_offset"

    const val ACTION_PREV = "com.ethosnote.app.widget.ACTION_PREV"
    const val ACTION_NEXT = "com.ethosnote.app.widget.ACTION_NEXT"
    const val ACTION_TOGGLE_VIEW = "com.ethosnote.app.widget.ACTION_TOGGLE_VIEW"
    const val ACTION_DAY_CLICK = "com.ethosnote.app.widget.ACTION_DAY_CLICK"

    const val DEEP_LINK_SCHEME = "ethosnote"

    // Category colors (ARGB)
    val CATEGORY_COLORS = mapOf(
        "Personale" to 0xFF4CAF50.toInt(),
        "Personal" to 0xFF4CAF50.toInt(),
        "Lavoro" to 0xFF2196F3.toInt(),
        "Work" to 0xFF2196F3.toInt(),
        "Famiglia" to 0xFF9C27B0.toInt(),
        "Family" to 0xFF9C27B0.toInt(),
        "Compleanno" to 0xFFE91E63.toInt(),
        "Birthday" to 0xFFE91E63.toInt()
    )

    fun getCategoryColor(category: String?): Int {
        if (category == null) return 0xFF6366F1.toInt()
        return CATEGORY_COLORS[category] ?: 0xFF6366F1.toInt()
    }
}
