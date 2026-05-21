package com.example.flutter_application_1

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.vardiya.widget/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val vardiyaText = call.argument<String>("vardiya") ?: "Yükleniyor..."
                val vardiyaTuru = call.argument<String>("tur") ?: "tatil"
                saveWidgetDataAndUpdate(vardiyaText, vardiyaTuru)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveWidgetDataAndUpdate(vardiyaText: String, vardiyaTuru: String) {
        val prefs = getSharedPreferences("VardiyaWidgetPrefs", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("vardiya_text", vardiyaText)
            .putString("vardiya_tur", vardiyaTuru)
            .apply()

        // Widget'ı güncelle
        val intent = Intent(this, VardiyaWidgetProvider::class.java)
        intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        val ids = AppWidgetManager.getInstance(this)
            .getAppWidgetIds(ComponentName(this, VardiyaWidgetProvider::class.java))
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        sendBroadcast(intent)
    }
}
