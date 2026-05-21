package com.example.flutter_application_1

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class VardiyaWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("VardiyaWidgetPrefs", Context.MODE_PRIVATE)
            val vardiyaText = prefs.getString("vardiya_text", "Uygulama bekleniyor...") ?: "Uygulama bekleniyor..."
            val vardiyaTuru = prefs.getString("vardiya_tur", "tatil") ?: "tatil"

            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            // Kısa vardiya adı
            val kisaAd = when {
                vardiyaTuru.contains("gunduz") -> "☀️ Gündüz"
                vardiyaTuru.contains("gece") -> "🌙 Gece"
                vardiyaTuru.contains("nobet") -> "🏥 Nöbet"
                else -> "🌿 Tatil"
            }

            // Renk (hex string → Color)
            val bgColor = when {
                vardiyaTuru.contains("gunduz") -> android.graphics.Color.parseColor("#FF6B35")
                vardiyaTuru.contains("gece") -> android.graphics.Color.parseColor("#1A1A2E")
                vardiyaTuru.contains("nobet") -> android.graphics.Color.parseColor("#5E35B1")
                else -> android.graphics.Color.parseColor("#2C3E50")
            }

            views.setInt(R.id.widget_root, "setBackgroundColor", bgColor)
            views.setTextViewText(R.id.widget_shift_type, kisaAd)
            views.setTextViewText(R.id.widget_time_range, vardiyaText)

            // Uygulamayı açan tıklama
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}