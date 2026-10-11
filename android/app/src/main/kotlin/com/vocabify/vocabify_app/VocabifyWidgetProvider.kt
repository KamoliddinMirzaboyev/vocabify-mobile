package com.vocabify.vocabify_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class VocabifyWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.vocabify_widget).apply {
                // Open App on Widget Click
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("vocabify://study")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                setOnClickPendingIntent(R.id.widget_action, pendingIntent)

                val word = widgetData.getString("widget_word", null) ?: "Vocabify"
                val translation = widgetData.getString("widget_translation", null)
                    ?: "Har kuni yangi so'zlarni oson yodlang!"
                val pronunciation = widgetData.getString("widget_pronunciation", null) ?: ""
                val example = widgetData.getString("widget_example", null) ?: ""
                val streak = widgetData.getInt("widget_streak", 0)
                val dueCount = widgetData.getInt("widget_due_count", 0)

                setTextViewText(R.id.widget_word, word)
                setTextViewText(R.id.widget_translation, translation)

                if (pronunciation.isNotBlank()) {
                    setTextViewText(R.id.widget_pronunciation, pronunciation)
                    setViewVisibility(R.id.widget_pronunciation, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_pronunciation, View.GONE)
                }

                if (example.isNotBlank()) {
                    setTextViewText(R.id.widget_example, "\"$example\"")
                    setViewVisibility(R.id.widget_example, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_example, View.GONE)
                }

                setTextViewText(
                    R.id.widget_streak,
                    if (streak > 0) "🔥 $streak kun" else "🔥 0 kun"
                )

                setTextViewText(
                    R.id.widget_due,
                    if (dueCount > 0) "⏰ Bugun: $dueCount ta takrorlash" else "✓ Barchasi takrorlandi"
                )
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
