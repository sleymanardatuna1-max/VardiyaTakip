package com.multistech.vardiyatakip

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
            // Dart tarafında ismini updateWidgetData yapmıştık
            if (call.method == "updateWidgetData") { 
                // Flutter'dan gelen 30 günlük haritayı karşılıyoruz
                val data = call.arguments as Map<String, Map<String, String>>
                
                // Verileri Android hafızasına kaydediyoruz
                val prefs = getSharedPreferences("VardiyaWidgetData", Context.MODE_PRIVATE)
                val editor = prefs.edit()

                for ((dateKey, info) in data) {
                    editor.putString("${dateKey}_vardiya", info["vardiya"])
                    editor.putString("${dateKey}_tur", info["tur"])
                }
                editor.apply()

                // Widget'ı güncellemesi için tetikliyoruz
                val intent = Intent(this, VardiyaWidgetProvider::class.java)
                intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val ids = AppWidgetManager.getInstance(this).getAppWidgetIds(ComponentName(this, VardiyaWidgetProvider::class.java))
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                sendBroadcast(intent)

                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}