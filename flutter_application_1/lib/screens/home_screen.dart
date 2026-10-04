import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../theme.dart';
import '../services/shift_service.dart';
import '../services/ai_service.dart';
import '../models.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const HomeScreen({super.key, required this.onRefresh});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _fotoAnalizEdiliyor = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR');
  }

  ShiftService get _s => ShiftService();

  Future<void> _googleHesabiniBagla() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      try {
        await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hesabınız başarıyla bağlandı!'), backgroundColor: Colors.green),
          );
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mevcut hesabınıza geçiş yapıldı!'), backgroundColor: Colors.blueAccent),
            );
          }
        } else {
          rethrow;
        }
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bir hata oluştu.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _fotograftanVardiyaCikar() async {
    setState(() => _fotoAnalizEdiliyor = true);
    try {
      List<String>? cikarilanDongu = await AIService.extractShiftFromImage();
      if (!mounted) return;
      if (cikarilanDongu == null) {
        setState(() => _fotoAnalizEdiliyor = false);
        return;
      }
      if (cikarilanDongu.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vardiya döngüsü anlaşılamadı. Daha net bir fotoğraf seçin.')),
        );
        setState(() => _fotoAnalizEdiliyor = false);
        return;
      }

      DateTime? secilenTarih = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2023),
        lastDate: DateTime(2030),
        helpText: 'VARDIYANIN BAŞLADIĞI İLK GÜNÜ SEÇİN',
        cancelText: 'İPTAL',
        confirmText: 'TAKVİME UYGULA',
      );

      if (secilenTarih == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarih seçilmediği için işlem iptal edildi.')),
        );
        setState(() => _fotoAnalizEdiliyor = false);
        return;
      }

      await _s.saveSettings(secilenTarih, VardiyaSistemi.ozelDuzen, cikarilanDongu);
      _s.widgetGuncelle();
      _s.gelecekBildirimleriKur();

      setState(() {});
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Takvim fotoğraftan başarıyla oluşturuldu!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _fotoAnalizEdiliyor = false);
    }
  }

  void _mesaiGirisPaneliAc(DateTime tarih) {
    String tarihKey = "${tarih.year}-${tarih.month}-${tarih.day}";
    double mevcutMesai = _s.mesaiKayitlari[tarihKey] ?? 0.0;
    TextEditingController controller = TextEditingController(text: mevcutMesai > 0 ? mevcutMesai.toString() : "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${tarih.day} ${_s.ayIsmiGetir(tarih.month)} Mesai Girişi",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Kaç saat ekstra çalıştınız?",
                labelStyle: TextStyle(color: AppTheme.textGray),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.textGray)),
                suffixText: "Saat",
                suffixStyle: TextStyle(color: AppTheme.textGray),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                double? yeniMesai = double.tryParse(controller.text.replaceAll(',', '.'));
                await _s.saveMesai(tarihKey, yeniMesai);
                setState(() {});
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("KAYDET", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime tomorrow = now.add(const Duration(days: 1));
    String todayShift = _s.calculator?.getShiftType(now) ?? 'Bilinmiyor';
    String tomorrowShift = _s.calculator?.getShiftType(tomorrow) ?? 'Bilinmiyor';
    final user = FirebaseAuth.instance.currentUser;
    bool isAnonymous = user?.isAnonymous ?? true;

    // Sonraki vardiya bilgisi
    String sonrakiVardiyaBilgi = '';
    for (int i = 1; i <= 7; i++) {
      DateTime gun = now.add(Duration(days: i));
      String v = _s.calculator?.getShiftType(gun) ?? '';
      if (!v.contains('Tatil')) {
        sonrakiVardiyaBilgi = '${_s.gunIsmiGetir(gun.weekday)} ${gun.day} ${_s.ayIsmiGetir(gun.month)}';
        break;
      }
    }

    // Bu hafta kaç vardiya
    int haftaVardiya = 0;
    int haftaSaat = 0;
    DateTime haftaBasi = now.subtract(Duration(days: now.weekday - 1));
    for (int i = 0; i < 7; i++) {
      DateTime g = haftaBasi.add(Duration(days: i));
      String v = _s.calculator?.getShiftType(g) ?? '';
      if (!v.contains('Tatil') && !v.contains('İstirahat')) {
        haftaVardiya++;
        haftaSaat += 8;
      }
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- HEADER ---
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryColor, size: 30),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VardiyaTakip', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  Text('Planla • Takip Et • Rahat Et', style: TextStyle(fontSize: 13, color: AppTheme.textGray)),
                ],
              ),
              const Spacer(),
              // Profil / Google hesap bağlama
              GestureDetector(
                onTap: isAnonymous ? _googleHesabiniBagla : null,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null
                      ? Icon(isAnonymous ? Icons.person_add : Icons.person, color: AppTheme.primaryColor, size: 22)
                      : null,
                ),
              ),
            ],
          ),
          // Misafir ise Google bağlama uyarısı
          if (isAnonymous) ...[
            const SizedBox(height: 15),
            GestureDetector(
              onTap: _googleHesabiniBagla,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_sync, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Verilerini güvenceye al • Google hesabını bağla', style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 14),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 25),

          // --- FOTOĞRAF TARA KARTI ---
          GestureDetector(
            onTap: _fotoAnalizEdiliyor ? null : _fotograftanVardiyaCikar,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor.withOpacity(0.15), AppTheme.primaryColor.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.2), shape: BoxShape.circle),
                    child: _fotoAnalizEdiliyor
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2))
                        : const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vardiya planını fotoğrafla', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        SizedBox(height: 5),
                        Text('Çizelgeni tara, vardiyalarını otomatik olarak takvime ekle.', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // --- BUGÜN ---
          const Text('Bugün', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          Text(DateFormat('dd MMMM yyyy • EEEE', 'tr_TR').format(now), style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
          const SizedBox(height: 10),
          _buildShiftCard(now, todayShift, true),

          const SizedBox(height: 20),

          // --- YARIN ---
          const Text('Yarın', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          Text(DateFormat('dd MMMM yyyy • EEEE', 'tr_TR').format(tomorrow), style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
          const SizedBox(height: 10),
          _buildShiftCard(tomorrow, tomorrowShift, false),

          const SizedBox(height: 25),

          // --- SONRAKI VARDİYA ---
          if (sonrakiVardiyaBilgi.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sonraki Vardiya', style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
                      Text(sonrakiVardiyaBilgi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // --- HIZLI BİLGİLER ---
          const Text('Hızlı Bilgiler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _bilgiKutusu('$haftaVardiya vardiya', 'Bu hafta')),
              const SizedBox(width: 10),
              Expanded(child: _bilgiKutusu('$haftaSaat saat', 'Bu hafta')),
            ],
          ),
          const SizedBox(height: 20),

          // --- BU HAFTA SATIRI ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Bu Hafta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('$haftaVardiya vardiya • $haftaSaat saat', style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          _buildWeeklyRow(now),
        ],
      ),
    );
  }

  Widget _buildShiftCard(DateTime date, String shift, bool showMesaiButton) {
    Color dotColor = _s.noktaRengiGetir(shift);
    IconData icon = _s.ikonGetir(shift);
    String tarihKey = "${date.year}-${date.month}-${date.day}";
    bool mesaiVar = _s.mesaiKayitlari.containsKey(tarihKey);

    return GestureDetector(
      onTap: showMesaiButton ? () => _mesaiGirisPaneliAc(date) : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: dotColor.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: dotColor, size: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shift.split('\n')[0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (shift.contains('\n'))
                    Text(shift.split('\n')[1], style: TextStyle(fontSize: 13, color: AppTheme.textGray)),
                  if (mesaiVar)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, size: 14, color: Colors.greenAccent),
                          const SizedBox(width: 4),
                          Text('+${_s.mesaiKayitlari[tarihKey]} saat mesai', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (showMesaiButton)
              IconButton(
                icon: Icon(mesaiVar ? Icons.edit : Icons.add_circle_outline, color: AppTheme.primaryColor),
                onPressed: () => _mesaiGirisPaneliAc(date),
                tooltip: 'Mesai Ekle',
              ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _bilgiKutusu(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppTheme.textGray, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWeeklyRow(DateTime now) {
    DateTime haftaBasi = now.subtract(Duration(days: now.weekday - 1));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      child: Row(
        children: List.generate(7, (index) {
          DateTime date = haftaBasi.add(Duration(days: index));
          String shift = _s.calculator?.getShiftType(date) ?? '';
          Color color = _s.noktaRengiGetir(shift);
          bool isToday = date.day == now.day && date.month == now.month && date.year == now.year;

          return GestureDetector(
            onTap: () => _mesaiGirisPaneliAc(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
              decoration: BoxDecoration(
                color: isToday ? AppTheme.primaryColor : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: isToday ? null : Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Text(_s.gunIsmiGetir(date.weekday), style: TextStyle(color: isToday ? Colors.black54 : AppTheme.textGray, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text('${date.day}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isToday ? Colors.black : Colors.white)),
                  const SizedBox(height: 5),
                  Icon(Icons.circle, color: isToday ? Colors.black54 : color, size: 8),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
