package com.vaultvoice.vaultvoice.quickcapture

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.vaultvoice.vaultvoice.R

/** Home-screen widget: static "Record" button that opens the Record screen. */
class RecordWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val views = RemoteViews(context.packageName, R.layout.lumen_record_widget)
        views.setOnClickPendingIntent(
            R.id.lumen_record_widget_root,
            QuickCaptureIntents.pendingIntent(context, QuickCaptureStore.Entry.ANDROID_WIDGET),
        )
        appWidgetManager.updateAppWidget(appWidgetIds, views)
    }
}
