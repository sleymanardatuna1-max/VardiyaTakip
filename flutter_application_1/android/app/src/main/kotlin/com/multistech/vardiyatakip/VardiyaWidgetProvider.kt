package com.multistech.vardiyatakip

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class VardiyaWidgetProvider : AppWidgetProvider() {

    // EKLENEN KISIM: Gece 00:00'da gün değişimini yakalar ve widget'ı tetikler
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_DATE_CHANGED || intent.action == Intent.ACTION_TIMEZONE_CHANGED) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, VardiyaWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            // EKLENEN KISIM: Bugünün tarihini (Örn: 2026-05-24) formatında alıyoruz
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val bugunStr = sdf.format(Date())

            // EKLENEN KISIM: 30 günlük listemizin olduğu yeni hafızaya bağlanıyoruz
            val prefs = context.getSharedPreferences("VardiyaWidgetData", Context.MODE_PRIVATE)
            
            // Bugünün tarihine denk gelen vardiyayı çekiyoruz
            val vardiyaText = prefs.getString("${bugunStr}_vardiya", "Hesaplanıyor...") ?: "Hesaplanıyor..."
            val vardiyaTuru = prefs.getString("${bugunStr}_tur", "tatil") ?: "tatil"

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