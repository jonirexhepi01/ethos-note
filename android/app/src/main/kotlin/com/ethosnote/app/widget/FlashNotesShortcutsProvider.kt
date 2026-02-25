package com.ethosnote.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.widget.RemoteViews
import com.ethosnote.app.R
import es.antonborri.home_widget.HomeWidgetPlugin

class FlashNotesShortcutsProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = HomeWidgetPlugin.getData(context)
        val bgColor = prefs.getInt("widget_bg", 0)
        val iconBg = prefs.getInt("widget_icon_bg", 0)
        val sepColor = prefs.getInt("widget_sep", 0)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_flash_shortcuts)

            // Background
            if (bgColor != 0) {
                views.setInt(R.id.widget_root, "setBackgroundColor", bgColor)
            } else {
                // Fallback: dark/light based on system setting
                val isNightMode = (context.resources.configuration.uiMode and
                        Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
                views.setInt(R.id.widget_root, "setBackgroundResource",
                    if (isNightMode) R.drawable.widget_background_dark else R.drawable.widget_background)
            }

            // Icon circles
            if (iconBg != 0) {
                for (id in listOf(R.id.circle_text, R.id.circle_photo,
                                  R.id.circle_voice, R.id.circle_event)) {
                    views.setInt(id, "setColorFilter", iconBg)
                }
            }

            // Separator
            if (sepColor != 0) {
                views.setInt(R.id.separator, "setBackgroundColor", sepColor)
            }

            // Deep links
            views.setOnClickPendingIntent(R.id.btn_text,
                buildDeepLinkIntent(context, "ethosnote://flashnote/text", 0))

            views.setOnClickPendingIntent(R.id.btn_photo,
                buildDeepLinkIntent(context, "ethosnote://flashnote/photo", 1))

            views.setOnClickPendingIntent(R.id.btn_voice,
                buildDeepLinkIntent(context, "ethosnote://flashnote/voice", 2))

            views.setOnClickPendingIntent(R.id.btn_event,
                buildDeepLinkIntent(context, "ethosnote://calendar/new", 3))

            appWidgetManager.updateAppWidget(widgetId, views)
        }
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
}
