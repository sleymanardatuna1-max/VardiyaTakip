import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models.dart';
import '../main.dart';

const _widgetChannel = MethodChannel('com.vardiya.widget/update');

class ShiftService {
  static final ShiftService _instance = ShiftService._internal();
  factory ShiftService() => _instance;
  ShiftService._internal();

  ShiftCalculator? calculator;
  Map<String, double> mesaiKayitlari = {};
  List<String> kayitliOzelDongu = [];

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final mesaiString = prefs.getString('mesai_verileri');
    if (mesaiString != null) {
      mesaiKayitlari = Map<String, double>.from(jsonDecode(mesaiString));
    }

    final kayitliTarih = prefs.getString('baslangic_tarihi');
    final kayitliSistemIndex = prefs.getInt('vardiya_sistemi') ?? 0;

    final ozelDonguString = prefs.getString('ozel_dongu');
    if (ozelDonguString != null) {
      kayitliOzelDongu = List<String>.from(jsonDecode(ozelDonguString));
    }

    VardiyaSistemi kayitliSistem = VardiyaSistemi.values[kayitliSistemIndex];

    if (kayitliTarih != null) {
      calculator = ShiftCalculator(DateTime.parse(kayitliTarih), kayitliSistem, ozelDongu: kayitliOzelDongu);
    } else {
      calculator = ShiftCalculator(DateTime.now(), VardiyaSistemi.sistem12_24);
    }
  }

  Future<void> saveSettings(DateTime initialDate, VardiyaSistemi system, List<String> customCycle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baslangic_tarihi', initialDate.toIso8601String());
    await prefs.setInt('vardiya_sistemi', system.index);
    await prefs.setString('ozel_dongu', jsonEncode(customCycle));

    kayitliOzelDongu = List.from(customCycle);
    calculator = ShiftCalculator(initialDate, system, ozelDongu: kayitliOzelDongu);
  }

  Future<void> saveMesai(String tarihKey, double? saat) async {
    if (saat != null && saat > 0) {
      mesaiKayitlari[tarihKey] = saat;
    } else {
      mesaiKayitlari.remove(tarihKey);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mesai_verileri', jsonEncode(mesaiKayitlari));
  }

  Future<void> widgetGuncelle() async {
    if (calculator == null) return;
    try {
      Map<String, dynamic> gelecekVardiyalar = {};
      DateTime bugun = DateTime.now();
      for (int i = 0; i < 30; i++) {
        DateTime hedef = bugun.add(Duration(days: i));
        String tarihKey = "${hedef.year}-${hedef.month.toString().padLeft(2, '0')}-${hedef.day.toString().padLeft(2, '0')}";
        String vardiyaMetni = calculator!.getShiftType(hedef);
        String tur = 'tatil';
        if (vardiyaMetni.contains('Gündüz')) tur = 'gunduz';
        else if (vardiyaMetni.contains('Akşam')) tur = 'aksam';
        else if (vardiyaMetni.contains('Gece')) tur = 'gece';
        else if (vardiyaMetni.contains('Nöbet')) tur = 'nobet';
        gelecekVardiyalar[tarihKey] = {
          'vardiya': vardiyaMetni.replaceAll('\n', ' '),
          'tur': tur
        };
      }
      await _widgetChannel.invokeMethod('updateWidgetData', gelecekVardiyalar);
    } catch (e) {
      // Widget güncellenemedi — sessizce geç
    }
  }

  Future<void> gelecekBildirimleriKur() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    if (calculator == null) return;

    for (int i = 0; i < 7; i++) {
      DateTime kontrolGunu = DateTime.now().add(Duration(days: i));
      String vardiya = calculator!.getShiftType(kontrolGunu);

      if (!vardiya.contains("Tatil")) {
        int baslangicSaati = vardiya.contains("Gündüz") ? 8 : 20;
        if (vardiya.contains("Nöbet")) baslangicSaati = 8;

        DateTime bildirimZamani = DateTime(
          kontrolGunu.year,
          kontrolGunu.month,
          kontrolGunu.day,
          baslangicSaati
        ).subtract(const Duration(hours: 2));

        if (bildirimZamani.isAfter(DateTime.now())) {
          await flutterLocalNotificationsPlugin.zonedSchedule(
            i,
            'Vardiya Hatırlatıcı',
            '$vardiya vardiyanız 2 saat sonra başlıyor!',
            tz.TZDateTime.from(bildirimZamani, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'vardiya_kanali',
                'Vardiya Bildirimleri',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    }
  }

  String sistemAdiGetir(VardiyaSistemi sistem) {
    switch (sistem) {
      case VardiyaSistemi.sistem12_24: return "12/24 (1 Gündüz, 1 Gece, 1 Tatil)";
      case VardiyaSistemi.sistem12_36: return "12/36 (1 Gündüz, 1 Gece, 2 Tatil)";
      case VardiyaSistemi.sistem24_48: return "24/48 (24 Saat Nöbet, 2 Tatil)";
      case VardiyaSistemi.ikiGunduz_ikiGece_ikiTatil: return "2'li Sistem (2 Gündüz, 2 Gece, 2 Tatil)";
      case VardiyaSistemi.ozelDuzen: return "Özel Vardiya (Kendin Yarat)";
    }
  }

  String ayIsmiGetir(int ay) {
    const aylar = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
    return aylar[ay - 1];
  }

  String gunIsmiGetir(int haftaninGunu) {
    const gunler = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
    return gunler[haftaninGunu - 1];
  }

  IconData ikonGetir(String vardiya) {
    if (vardiya.contains("Gündüz")) return Icons.wb_sunny;
    if (vardiya.contains("Akşam")) return Icons.wb_twilight;
    if (vardiya.contains("Gece")) return Icons.nightlight_round;
    if (vardiya.contains("Nöbet")) return Icons.local_hospital;
    if (vardiya.contains("Tatil")) return Icons.weekend;
    return Icons.help_outline;
  }

  Color ikonRengiGetir(String vardiya) {
    if (vardiya.contains("Gündüz")) return const Color(0xFFFFB74D);
    if (vardiya.contains("Akşam")) return const Color(0xFFFF8A65);
    if (vardiya.contains("Gece")) return const Color(0xFF42A5F5);
    if (vardiya.contains("Nöbet")) return const Color(0xFFAB47BC);
    if (vardiya.contains("Tatil")) return const Color(0xFF66BB6A);
    return const Color(0xFFBDBDBD);
  }

  Color noktaRengiGetir(String vardiya) {
    if (vardiya.contains("Gündüz")) return const Color(0xFFFFB74D);
    if (vardiya.contains("Akşam")) return const Color(0xFFFF8A65);
    if (vardiya.contains("Gece")) return const Color(0xFF42A5F5);
    if (vardiya.contains("Nöbet")) return const Color(0xFFAB47BC);
    if (vardiya.contains("Tatil")) return const Color(0xFF66BB6A);
    return const Color(0xFF9E9E9E);
  }
}
