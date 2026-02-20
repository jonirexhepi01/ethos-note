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

class FlashNotesShortcutsProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val isNightMode = (context.resources.configuration.uiMode and
                Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_flash_shortcuts)

            // Apply dark/light background
            views.setInt(R.id.widget_root, "setBackgroundResource",
                if (isNightMode) R.drawable.widget_background_dark else R.drawable.widget_background)

            // Apply text colors
            val textColor = if (isNightMode) 0x99FFFFFF.toInt() else 0x99000000.toInt()
            views.setTextColor(R.id.label_text, textColor)
            views.setTextColor(R.id.label_photo, textColor)
            views.setTextColor(R.id.label_voice, textColor)
            views.setTextColor(R.id.label_event, textColor)

            // Text shortcut → ethosnote://flashnote/text
            views.setOnClickPendingIntent(R.id.btn_text,
                buildDeepLinkIntent(context, "ethosnote://flashnote/text", 0))

            // Photo shortcut → ethosnote://flashnote/photo
            views.setOnClickPendingIntent(R.id.btn_photo,
                buildDeepLinkIntent(context, "ethosnote://flashnote/photo", 1))

            // Voice shortcut → ethosnote://flashnote/voice
            views.setOnClickPendingIntent(R.id.btn_voice,
                buildDeepLinkIntent(context, "ethosnote://flashnote/voice", 2))

            // Event shortcut → ethosnote://calendar/new
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
