package com.ethosnote.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.ethosnote.app.R

class QuickFlashNoteBarProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_flash_bar)

            // Entire bar clicks → open flash note text mode
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("ethosnote://flashnote/text")).apply {
                setClassName(context.packageName, "com.ethosnote.app.MainActivity")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 100, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.quick_flash_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
