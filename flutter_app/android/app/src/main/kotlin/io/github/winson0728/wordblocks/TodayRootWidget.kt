package io.github.winson0728.wordblocks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.util.Calendar
import java.util.TimeZone

/**
 * Home-screen widget that shows one root per day.
 *
 * The app saves the full list of daily roots (lib/platform/home_screen_widget.dart); the widget
 * picks today's entry itself so it changes at midnight without the app running.
 */
class TodayRootWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = pick(widgetData.getString("roots", null))
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.today_root_widget)
            if (today == null) {
                views.setTextViewText(R.id.widget_forms, "字根工坊")
                views.setTextViewText(R.id.widget_meaning, "打開 App 一次，就會顯示今日字根")
                views.setTextViewText(R.id.widget_words, "")
            } else {
                views.setTextViewText(R.id.widget_forms, today.getString("forms"))
                views.setTextViewText(R.id.widget_meaning, today.getString("meaning"))
                views.setTextViewText(R.id.widget_words, today.getString("words"))
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun pick(json: String?) = try {
        val roots = JSONArray(json ?: return null)
        if (roots.length() == 0) null else roots.getJSONObject((dayNumber() % roots.length()).toInt())
    } catch (e: Exception) {
        null
    }

    companion object {
        /** Days since 2024-01-01 for today's local date. Must match Lexicon.dayNumber in Dart. */
        fun dayNumber(): Long {
            val local = Calendar.getInstance()
            val utc = TimeZone.getTimeZone("UTC")
            val start = Calendar.getInstance(utc).apply { clear(); set(2024, Calendar.JANUARY, 1) }
            val today = Calendar.getInstance(utc).apply {
                clear()
                set(local.get(Calendar.YEAR), local.get(Calendar.MONTH), local.get(Calendar.DAY_OF_MONTH))
            }
            return (today.timeInMillis - start.timeInMillis) / 86_400_000L
        }
    }
}
